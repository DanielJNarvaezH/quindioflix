-- =============================================================================
-- NT3-2: Transaccion de renovacion mensual
-- Autor  : Diego Garcia
-- Tarea  : NT3-2 del cronograma QuindioFlix — Sprint 4
--
-- DESCRIPCION:
--   Procesa la renovacion mensual de todos los usuarios activos cuya
--   fecha_vencimiento sea menor o igual a SYSDATE (suscripcion vencida
--   o por vencer hoy).
--
--   Por cada usuario elegible:
--     1. Establece un SAVEPOINT individual
--     2. Calcula el monto con FN_CALCULAR_MONTO (incluye descuento antiguedad)
--     3. Registra el pago en PAGOS con estado EXITOSO
--     4. Actualiza fecha_vencimiento = fecha_vencimiento + 30
--     5. Confirma con RELEASE SAVEPOINT
--     Si falla cualquier paso del usuario -> ROLLBACK TO SAVEPOINT
--     (los usuarios ya procesados no se pierden)
--
--   Al final: COMMIT global de todos los usuarios exitosos.
--
-- ESTADOS DOCUMENTADOS (requeridos por NT3-1):
--   ACTIVA           : inicio del bloque, antes del primer usuario
--   PARCIALMENTE     : despues de cada SAVEPOINT liberado
--   CONFIRMADA       : tras el COMMIT global
--   FALLIDA/ABORTADA : si el bloque completo falla (ROLLBACK total)
--
-- SAVEPOINT por usuario:
--   Permite que si el usuario 15 falla, los usuarios 1-14 ya procesados
--   no se reviertan. Solo se pierde el usuario que fallo.
--   Sin SAVEPOINT, cualquier fallo reverteria toda la renovacion.
--
-- DEPENDENCIA: FN_CALCULAR_MONTO (NT2-6, Cristhian Osorio)
-- =============================================================================

DECLARE
-- Cursor de usuarios elegibles para renovacion
-- Criterio: ACTIVO + fecha_vencimiento <= SYSDATE (vencidos o que vencen hoy)
CURSOR cur_usuarios_renovar IS
SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido   AS nombre_completo,
    u.fecha_vencimiento,
    u.id_plan,
    pl.nombre                        AS nombre_plan
FROM USUARIOS u
         JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE u.estado_cuenta  = 'ACTIVO'
  AND u.fecha_vencimiento <= SYSDATE
ORDER BY u.id_usuario;

-- Variables de trabajo
v_monto             NUMBER(10,2);
    v_sp_nombre         VARCHAR2(30);
    v_renovados         NUMBER := 0;
    v_fallidos          NUMBER := 0;
    v_total_cobrado     NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('   RENOVACION MENSUAL — QUINDIOFLIX');
    DBMS_OUTPUT.PUT_LINE('   Fecha: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ESTADO: ACTIVA — iniciando procesamiento');
    DBMS_OUTPUT.PUT_LINE('');

    -- =========================================================================
    -- Recorrer usuarios elegibles con SAVEPOINT individual por usuario
    -- =========================================================================
FOR v_usr IN cur_usuarios_renovar LOOP

        -- Nombre del savepoint unico por usuario
        v_sp_nombre := 'SP_USR_' || v_usr.id_usuario;

BEGIN
            -- -----------------------------------------------------------------
            -- SAVEPOINT: marca de retroceso individual para este usuario
            -- -----------------------------------------------------------------
SAVEPOINT SP_RENOVACION;

-- -----------------------------------------------------------------
-- PASO 1: Calcular monto con descuento de antiguedad
-- FN_CALCULAR_MONTO aplica 0%, 10% o 15% segun meses registrado
-- -----------------------------------------------------------------
v_monto := FN_CALCULAR_MONTO(v_usr.id_usuario);

            -- -----------------------------------------------------------------
            -- PASO 2: Registrar el pago mensual
            -- -----------------------------------------------------------------
INSERT INTO PAGOS (
    fecha_pago, monto, metodo_pago,
    estado_pago, descuento_aplicado, id_usuario
)
VALUES (
           SYSDATE,
           v_monto,
           'TARJETA_CREDITO',
           'EXITOSO',
           -- Calcular porcentaje de descuento aplicado para el registro
           ROUND((1 - v_monto / (
               SELECT precio_mensual FROM PLANES
               WHERE id_plan = v_usr.id_plan
           )) * 100, 2),
           v_usr.id_usuario
       );

-- -----------------------------------------------------------------
-- PASO 3: Actualizar fecha_vencimiento + 30 dias
-- -----------------------------------------------------------------
UPDATE USUARIOS
SET fecha_vencimiento = fecha_vencimiento + 30
WHERE id_usuario = v_usr.id_usuario;

-- -----------------------------------------------------------------
-- Usuario procesado correctamente
-- -----------------------------------------------------------------
v_renovados     := v_renovados + 1;
            v_total_cobrado := v_total_cobrado + v_monto;

            DBMS_OUTPUT.PUT_LINE(
                'OK  | ID: ' || LPAD(v_usr.id_usuario, 3) ||
                ' | ' || RPAD(v_usr.nombre_completo, 25) ||
                ' | ' || RPAD(v_usr.nombre_plan, 9) ||
                ' | Vencia: ' || TO_CHAR(v_usr.fecha_vencimiento, 'DD/MM/YY') ||
                ' | Cobro: $' || v_monto
            );
            DBMS_OUTPUT.PUT_LINE(
                'ESTADO: PARCIALMENTE CONFIRMADA — ' ||
                v_renovados || ' usuario(s) procesado(s)'
            );

EXCEPTION
            -- -----------------------------------------------------------------
            -- Fallo en este usuario: retroceder SOLO hasta su SAVEPOINT
            -- Los usuarios anteriores ya procesados NO se revierten
            -- -----------------------------------------------------------------
            WHEN OTHERS THEN
                ROLLBACK TO SP_RENOVACION;
                v_fallidos := v_fallidos + 1;

                DBMS_OUTPUT.PUT_LINE(
                    'FAIL| ID: ' || LPAD(v_usr.id_usuario, 3) ||
                    ' | ' || RPAD(v_usr.nombre_completo, 25) ||
                    ' | Error: ' || SQLERRM
                );
                DBMS_OUTPUT.PUT_LINE(
                    'ESTADO: ROLLBACK PARCIAL — usuario ' ||
                    v_usr.id_usuario || ' revertido, anteriores conservados'
                );
END;

END LOOP;

    -- =========================================================================
    -- COMMIT global: confirma todos los usuarios exitosamente renovados
    -- =========================================================================
COMMIT;
DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ESTADO: CONFIRMADA — COMMIT ejecutado');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('  Usuarios renovados : ' || v_renovados);
    DBMS_OUTPUT.PUT_LINE('  Usuarios fallidos  : ' || v_fallidos);
    DBMS_OUTPUT.PUT_LINE('  Total cobrado      : $' || v_total_cobrado);
    DBMS_OUTPUT.PUT_LINE('=======================================================');

EXCEPTION
    -- =========================================================================
    -- Error catastrofico que impide procesar cualquier usuario
    -- Revertir todo lo que no se habia confirmado con SAVEPOINT
    -- =========================================================================
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ESTADO: ABORTADA — error catastrofico: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Se ejecuto ROLLBACK total.');
        RAISE;
END;
/


-- =============================================================================
-- Verificacion post-ejecucion
-- =============================================================================

-- Usuarios cuya fecha_vencimiento se actualizo hoy
SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido           AS usuario,
    u.fecha_vencimiento                      AS nueva_fecha_vencimiento,
    u.estado_cuenta
FROM USUARIOS u
WHERE TRUNC(u.fecha_vencimiento) = TRUNC(SYSDATE) + 30
ORDER BY u.id_usuario;

-- Pagos registrados hoy por la renovacion
SELECT
    p.id_pago,
    u.nombre || ' ' || u.apellido           AS usuario,
    pl.nombre                               AS plan,
    p.monto,
    p.descuento_aplicado                    AS descuento_pct,
    p.estado_pago,
    TO_CHAR(p.fecha_pago, 'DD/MM/YYYY')     AS fecha_pago
FROM PAGOS p
         JOIN USUARIOS u  ON u.id_usuario = p.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
WHERE TRUNC(p.fecha_pago) = TRUNC(SYSDATE)
  AND p.estado_pago = 'EXITOSO'
ORDER BY p.id_pago;