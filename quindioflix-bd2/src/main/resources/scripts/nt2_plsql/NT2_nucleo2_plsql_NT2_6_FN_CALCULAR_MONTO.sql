-- =============================================================================
-- NT2-6: FN_CALCULAR_MONTO
-- Script  : NT2_nucleo2_plsql_NT2_6_FN_CALCULAR_MONTO.sql
-- Autor   : Cristhian Osorio
-- Tarea   : NT2-6 del cronograma QuindioFlix — Sprint 3
--
-- DESCRIPCION:
--   Funcion que recibe el id de un usuario y retorna el monto a cobrar
--   para el proximo mes, aplicando descuentos por antiguedad segun el
--   tiempo que lleva suscrito en la plataforma.
--
-- PARAMETROS:
--   p_id_usuario  NUMBER — id del usuario a evaluar
--
-- RETORNO:
--   NUMBER(10,2) — monto final del proximo mes despues de descuento
--
-- EXCEPCION PERSONALIZADA:
--   USUARIO_NO_EXISTE (-20021) — el id_usuario no existe en USUARIOS
--   Codigo -20021 elegido para no colisionar con SP_CAMBIAR_PLAN
--   (-20001/-20004) ni SP_REGISTRAR_USUARIO (-20011/-20012).
--
-- LOGICA DE DESCUENTOS POR ANTIGUEDAD:
--   Antiguedad = MONTHS_BETWEEN(SYSDATE, fecha_registro)
--
--   | Antiguedad           | Descuento | Ejemplo (Basico $14,900) |
--   |----------------------|-----------|--------------------------|
--   | > 24 meses           |    15 %   | $12,665.00               |
--   | > 12 y <= 24 meses   |    10 %   | $13,410.00               |
--   | <= 12 meses          |     0 %   | $14,900.00               |
--
--   Monto final = ROUND(precio_mensual * (1 - descuento / 100), 2)
--
-- EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   Activar SET SERVEROUTPUT ON antes de los bloques de prueba.
-- =============================================================================


-- =============================================================================
-- CREACION DE LA FUNCION
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_CALCULAR_MONTO (
    p_id_usuario IN NUMBER
)
RETURN NUMBER
IS
    -- -------------------------------------------------------------------------
    -- Excepcion personalizada
    -- -------------------------------------------------------------------------
    USUARIO_NO_EXISTE EXCEPTION;
    PRAGMA EXCEPTION_INIT(USUARIO_NO_EXISTE, -20021);

    -- -------------------------------------------------------------------------
    -- Variables de trabajo
    -- -------------------------------------------------------------------------
    v_usuario    USUARIOS%ROWTYPE;
    v_plan       PLANES%ROWTYPE;
    v_meses      NUMBER(6,2) := 0;
    v_descuento  NUMBER(5,2) := 0;
    v_monto      NUMBER(10,2);

BEGIN

    -- =========================================================================
    -- PASO 1: Obtener datos del usuario — valida existencia
    -- =========================================================================
    BEGIN
        SELECT *
        INTO   v_usuario
        FROM   USUARIOS
        WHERE  id_usuario = p_id_usuario;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'USUARIO_NO_EXISTE: No se encontro el usuario con id = '
                || p_id_usuario || '.'
            );
    END;

    -- =========================================================================
    -- PASO 2: Obtener precio mensual del plan actual del usuario
    -- =========================================================================
    SELECT *
    INTO   v_plan
    FROM   PLANES
    WHERE  id_plan = v_usuario.id_plan;

    -- =========================================================================
    -- PASO 3: Calcular antiguedad en meses
    -- MONTHS_BETWEEN devuelve fraccion — se usa el valor completo para
    -- que el descuento sea exacto al mes cumplido.
    -- =========================================================================
    v_meses := MONTHS_BETWEEN(SYSDATE, v_usuario.fecha_registro);

    -- =========================================================================
    -- PASO 4: Determinar descuento segun antiguedad
    -- =========================================================================
    IF v_meses > 24 THEN
        v_descuento := 15;
    ELSIF v_meses > 12 THEN
        v_descuento := 10;
    ELSE
        v_descuento := 0;
    END IF;

    -- =========================================================================
    -- PASO 5: Calcular monto final con descuento
    -- =========================================================================
    v_monto := ROUND(v_plan.precio_mensual * (1 - v_descuento / 100), 2);

    -- =========================================================================
    -- PASO 6: Mostrar detalle del calculo (util para depuracion y pruebas)
    -- =========================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  FN_CALCULAR_MONTO — Detalle de calculo');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  Usuario     : ' || v_usuario.nombre
                         || ' ' || v_usuario.apellido
                         || ' (id=' || p_id_usuario || ')');
    DBMS_OUTPUT.PUT_LINE('  Plan        : ' || v_plan.nombre
                         || ' ($' || v_plan.precio_mensual || '/mes)');
    DBMS_OUTPUT.PUT_LINE('  Registro    : '
                         || TO_CHAR(v_usuario.fecha_registro, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('  Antiguedad  : '
                         || ROUND(v_meses, 1) || ' meses');
    DBMS_OUTPUT.PUT_LINE('  Descuento   : ' || v_descuento || '%');
    DBMS_OUTPUT.PUT_LINE('  Monto final : $' || v_monto);
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

    RETURN v_monto;

EXCEPTION
    WHEN USUARIO_NO_EXISTE THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20099,
            'FN_CALCULAR_MONTO — Error inesperado: ' || SQLERRM
        );
END FN_CALCULAR_MONTO;
/


-- =============================================================================
-- BLOQUES DE PRUEBA
-- Ejecutar cada bloque por separado con SET SERVEROUTPUT ON primero.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: Descuento 15% — usuario con mas de 24 meses de antiguedad
-- Sofia Perea: fecha_registro = 2024-01-10 (~27 meses desde mayo 2026)
-- Plan Basico: $14,900 - 15% = $12,665.00
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 1: Descuento 15% (mas de 24 meses — Sofia Perea)
PROMPT ============================================================
DECLARE
    v_monto NUMBER;
    v_id    NUMBER;
BEGIN
    SELECT id_usuario INTO v_id FROM USUARIOS
    WHERE  email = 'sofia.perea@quindioflix.com';

    v_monto := FN_CALCULAR_MONTO(v_id);
    DBMS_OUTPUT.PUT_LINE('Resultado: $' || v_monto
                         || ' (esperado: $12,665.00)');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: Descuento 10% — usuario con entre 12 y 24 meses
-- Daniela Parra: fecha_registro = 2024-07-08 (~21 meses desde mayo 2026)
-- Plan Basico: $14,900 - 10% = $13,410.00
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 2: Descuento 10% (entre 12 y 24 meses — Daniela Parra)
PROMPT ============================================================
DECLARE
    v_monto NUMBER;
    v_id    NUMBER;
BEGIN
    SELECT id_usuario INTO v_id FROM USUARIOS
    WHERE  email = 'daniela.parra@quindioflix.com';

    v_monto := FN_CALCULAR_MONTO(v_id);
    DBMS_OUTPUT.PUT_LINE('Resultado: $' || v_monto
                         || ' (esperado: ~$13,410.00)');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: Sin descuento (0%) — usuario nuevo con menos de 12 meses
-- Se inserta un usuario temporal con fecha_registro = SYSDATE para simular
-- el caso de un cliente recien registrado.
-- Plan Estandar: $24,900 - 0% = $24,900.00
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 3: Sin descuento (menos de 12 meses — usuario temporal)
PROMPT ============================================================
DECLARE
    v_monto   NUMBER;
    v_id_temp NUMBER;
BEGIN
    -- Insertar usuario temporal con fecha de hoy
    INSERT INTO USUARIOS (
        nombre, apellido, email, contrasena_hash,
        fecha_registro, fecha_vencimiento,
        estado_cuenta, es_moderador, ciudad, id_plan
    )
    VALUES (
        'Test', 'Nuevo', 'test.nuevo.fn6@quindioflix.com', 'hash_temp',
        SYSDATE, SYSDATE + 30,
        'ACTIVO', 'N', 'Armenia', 2
    )
    RETURNING id_usuario INTO v_id_temp;

    v_monto := FN_CALCULAR_MONTO(v_id_temp);
    DBMS_OUTPUT.PUT_LINE('Resultado: $' || v_monto
                         || ' (esperado: $24,900.00 — sin descuento)');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/
-- Limpiar usuario temporal
DELETE FROM USUARIOS WHERE email = 'test.nuevo.fn6@quindioflix.com';
COMMIT;
PROMPT Usuario temporal eliminado.


-- -----------------------------------------------------------------------------
-- PRUEBA 4: Descuento 15% — usuario Premium con mas de 24 meses
-- Marcela Botero: fecha_registro = 2024-01-20 (~27 meses)
-- Plan Premium: $34,900 - 15% = $29,665.00
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 4: Descuento 15% en plan Premium (Marcela Botero)
PROMPT ============================================================
DECLARE
    v_monto NUMBER;
    v_id    NUMBER;
BEGIN
    SELECT id_usuario INTO v_id FROM USUARIOS
    WHERE  email = 'marcela.botero@quindioflix.com';

    v_monto := FN_CALCULAR_MONTO(v_id);
    DBMS_OUTPUT.PUT_LINE('Resultado: $' || v_monto
                         || ' (esperado: $29,665.00)');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 5: Error USUARIO_NO_EXISTE (-20021)
-- ID 99999 no existe en USUARIOS
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 5: Error USUARIO_NO_EXISTE
PROMPT ============================================================
DECLARE
    v_monto NUMBER;
BEGIN
    v_monto := FN_CALCULAR_MONTO(99999);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado correctamente: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- VERIFICACION: Tabla resumen de todos los usuarios con su monto calculado
-- Util para confirmar que la funcion es consistente para toda la BD
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT VERIFICACION: Monto calculado para todos los usuarios activos
PROMPT ============================================================

SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido                       AS usuario,
    p.nombre                                             AS plan,
    p.precio_mensual                                     AS precio_base,
    ROUND(MONTHS_BETWEEN(SYSDATE, u.fecha_registro), 1) AS meses_antiguedad,
    CASE
        WHEN MONTHS_BETWEEN(SYSDATE, u.fecha_registro) > 24 THEN 15
        WHEN MONTHS_BETWEEN(SYSDATE, u.fecha_registro) > 12 THEN 10
        ELSE 0
    END                                                  AS descuento_pct,
    FN_CALCULAR_MONTO(u.id_usuario)                     AS monto_proximo_mes
FROM  USUARIOS u
JOIN  PLANES   p ON p.id_plan = u.id_plan
WHERE u.estado_cuenta = 'ACTIVO'
ORDER BY p.precio_mensual DESC, meses_antiguedad DESC;
