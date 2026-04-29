-- =============================================================================
-- NT2-1: Cursor — Usuarios con suscripcion vencida
-- Autor  : Equipo QuindioFlix
-- Recorre usuarios cuyo ultimo pago APROBADO supera los 30 dias de antiguedad,
-- o que nunca han pagado y su fecha_vencimiento ya paso.
--
-- Reporte generado por fila:
--   nombre completo | email | plan | dias de mora | monto adeudado
--
-- Tecnicas requeridas:
--   %ROWTYPE  : el registro del cursor se declara con cur_mora%ROWTYPE
--   FETCH     : ciclo OPEN / FETCH / CLOSE explicito (sin cursor FOR)
--   Cursor    : cur_mora definido en la seccion DECLARE
--
-- Logica de mora:
--   dias_mora      = TRUNC(SYSDATE) - fecha del ultimo pago APROBADO
--                    (si nunca pago, se toma fecha_vencimiento como referencia)
--   monto_adeudado = precio_mensual del plan * meses_mora redondeados hacia arriba
--                    (CEIL(dias_mora / 30))
--
-- Criterio de inclusion:
--   El usuario debe tener estado_cuenta IN ('ACTIVO','INACTIVO') y
--   su ultimo pago APROBADO debe tener mas de 30 dias, o no tener
--   ningun pago APROBADO y fecha_vencimiento < SYSDATE.
-- =============================================================================

DECLARE

-- -------------------------------------------------------------------------
-- Cursor principal
-- Une USUARIOS con PLANES para tener precio_mensual disponible.
-- Calcula fecha_ultimo_pago con MAX sobre PAGOS (solo estado APROBADO).
-- Filtra directamente: mora > 30 dias o nunca ha pagado y ya vencio.
-- Ordena de mayor a menor mora para que el reporte muestre los casos
-- mas criticos primero.
-- -------------------------------------------------------------------------
CURSOR cur_mora IS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellido,
    u.email,
    u.fecha_vencimiento,
    u.estado_cuenta,
    u.id_plan,
    pl.nombre        AS nombre_plan,
    pl.precio_mensual,
    MAX(pa.fecha_pago) AS fecha_ultimo_pago
FROM USUARIOS u
         JOIN PLANES pl
              ON pl.id_plan = u.id_plan
         LEFT JOIN PAGOS pa
                   ON pa.id_usuario   = u.id_usuario
                       AND pa.estado_pago  = 'APROBADO'
WHERE u.estado_cuenta IN ('ACTIVO', 'INACTIVO')
GROUP BY
    u.id_usuario,
    u.nombre,
    u.apellido,
    u.email,
    u.fecha_vencimiento,
    u.estado_cuenta,
    u.id_plan,
    pl.nombre,
    pl.precio_mensual
HAVING
    -- Caso 1: tiene pagos aprobados pero el ultimo fue hace mas de 30 dias
    (MAX(pa.fecha_pago) IS NOT NULL
        AND TRUNC(SYSDATE) - MAX(pa.fecha_pago) > 30)
    OR
    -- Caso 2: nunca ha tenido un pago aprobado y la suscripcion ya vencio
    (MAX(pa.fecha_pago) IS NULL
        AND u.fecha_vencimiento < TRUNC(SYSDATE))
ORDER BY
    (TRUNC(SYSDATE) - NVL(MAX(pa.fecha_pago), u.fecha_vencimiento)) DESC;

-- -------------------------------------------------------------------------
-- Registro tipado con %ROWTYPE del cursor
-- Captura la fila completa devuelta por cur_mora en cada FETCH
-- -------------------------------------------------------------------------
v_fila          cur_mora%ROWTYPE;

    -- Variables de calculo derivadas (no vienen directamente del cursor)
    v_dias_mora      NUMBER(6);
    v_meses_mora     NUMBER(4);
    v_monto_adeudado NUMBER(12, 2);

    -- Contadores para el resumen final del reporte
    v_total_usuarios  NUMBER(6)     := 0;
    v_monto_total     NUMBER(14, 2) := 0;

    -- Separador visual reutilizable
    c_linea CONSTANT VARCHAR2(100) :=
        '------------------------------------------------------------'
        || '--------------------';

BEGIN

    -- Encabezado del reporte
    DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE('  QUINDIOFLIX — REPORTE DE SUSCRIPCIONES VENCIDAS');
    DBMS_OUTPUT.PUT_LINE('  Fecha de corte : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('  Criterio       : ultimo pago APROBADO hace mas de 30 dias');
    DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NOMBRE',             30) || ' ' ||
        RPAD('EMAIL',              35) || ' ' ||
        RPAD('PLAN',               10) || ' ' ||
        LPAD('DIAS MORA', 10)         || ' ' ||
        LPAD('MONTO ADEUDADO', 16)
    );
    DBMS_OUTPUT.PUT_LINE(c_linea);

    -- -------------------------------------------------------------------------
    -- Apertura explicita del cursor
    -- -------------------------------------------------------------------------
OPEN cur_mora;

LOOP
-- FETCH: trae la siguiente fila al registro %ROWTYPE
FETCH cur_mora INTO v_fila;
        EXIT WHEN cur_mora%NOTFOUND;

        -- ---------------------------------------------------------------------
        -- Calcular dias de mora
        --   Si tiene ultimo pago: dias desde ese pago hasta hoy
        --   Si nunca pago       : dias desde fecha_vencimiento hasta hoy
        -- ---------------------------------------------------------------------
        v_dias_mora := TRUNC(SYSDATE)
                       - NVL(v_fila.fecha_ultimo_pago, v_fila.fecha_vencimiento);

        -- Meses completos de mora (redondeados hacia arriba: cada mes iniciado se cobra)
        v_meses_mora := CEIL(v_dias_mora / 30);

        -- Monto adeudado = precio del plan x meses de mora
        v_monto_adeudado := v_fila.precio_mensual * v_meses_mora;

        -- Acumuladores del resumen
        v_total_usuarios := v_total_usuarios + 1;
        v_monto_total    := v_monto_total + v_monto_adeudado;

        -- Imprimir fila del reporte
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_fila.nombre || ' ' || v_fila.apellido, 30) || ' ' ||
            RPAD(v_fila.email,                             35) || ' ' ||
            RPAD(v_fila.nombre_plan,                       10) || ' ' ||
            LPAD(v_dias_mora,                              10) || ' ' ||
            LPAD(TO_CHAR(v_monto_adeudado, 'FM$999,999,990.00'), 16)
        );

END LOOP;

    -- -------------------------------------------------------------------------
    -- Cierre explicito del cursor
    -- -------------------------------------------------------------------------
CLOSE cur_mora;

-- Pie del reporte con totales
DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE(
        'Total usuarios en mora : ' || v_total_usuarios
    );
    DBMS_OUTPUT.PUT_LINE(
        'Cartera total adeudada : ' ||
        TO_CHAR(v_monto_total, 'FM$999,999,990.00')
    );
    DBMS_OUTPUT.PUT_LINE(c_linea);

EXCEPTION
    WHEN OTHERS THEN
        -- Garantizar cierre del cursor ante cualquier error inesperado
        IF cur_mora%ISOPEN THEN
            CLOSE cur_mora;
END IF;
        DBMS_OUTPUT.PUT_LINE('ERROR inesperado: ' || SQLERRM);
        RAISE;
END;
/

-- =============================================================================
-- Verificacion rapida post-ejecucion:
-- Muestra los mismos usuarios con su ultimo pago para contrastar con el reporte.
-- =============================================================================
SELECT
    u.nombre || ' ' || u.apellido          AS usuario,
    u.email,
    pl.nombre                              AS plan,
    -- Si no hay pago, indica que nunca ha pagado
    NVL(TO_CHAR(MAX(pa.fecha_pago), 'DD/MM/YYYY'), 'SIN PAGOS') AS ultimo_pago,
    -- Calcula la mora usando el último pago o la fecha de vencimiento si no hay pagos
    TRUNC(SYSDATE) - NVL(MAX(pa.fecha_pago), u.fecha_vencimiento) AS dias_mora,
    u.estado_cuenta
FROM USUARIOS u
         JOIN PLANES pl ON pl.id_plan = u.id_plan
         LEFT JOIN PAGOS pa
                   ON pa.id_usuario  = u.id_usuario
                       AND pa.estado_pago = 'APROBADO'
WHERE u.estado_cuenta IN ('ACTIVO', 'INACTIVO')
GROUP BY
    u.nombre, u.apellido, u.email, pl.nombre,
    u.fecha_vencimiento, u.estado_cuenta
HAVING
    (MAX(pa.fecha_pago) IS NOT NULL AND TRUNC(SYSDATE) - MAX(pa.fecha_pago) > 30)
    OR
    (MAX(pa.fecha_pago) IS NULL AND u.fecha_vencimiento < TRUNC(SYSDATE))
ORDER BY dias_mora DESC;