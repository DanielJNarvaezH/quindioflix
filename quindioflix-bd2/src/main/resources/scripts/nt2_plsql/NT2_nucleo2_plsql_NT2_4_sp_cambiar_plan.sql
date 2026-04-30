-- =============================================================================
-- NT2-4: SP_CAMBIAR_PLAN
-- Script  : NT2_nucleo2_plsql_NT2_4_SP_CAMBIAR_PLAN.sql
-- Autor   : Daniel Narvaez
-- Tarea   : NT2-4 del cronograma QuindioFlix — Sprint 3
--
-- DESCRIPCION:
--   Procedimiento almacenado que cambia el plan de suscripcion de un usuario.
--   Antes de aplicar el cambio valida que el usuario no tenga mas perfiles
--   activos de los que permite el nuevo plan. Si la validacion falla lanza
--   una excepcion personalizada PERFILES_EXCEDIDOS con codigo -20001.
--
-- PARAMETROS:
--   p_id_usuario  NUMBER  — id del usuario cuyo plan se va a cambiar
--   p_id_plan_nuevo NUMBER — id del nuevo plan al que se quiere migrar
--
-- EXCEPCIONES PERSONALIZADAS (NT2-9):
--   PERFILES_EXCEDIDOS  (-20001) — el usuario tiene mas perfiles que los
--                                   permitidos por el nuevo plan
--   USUARIO_NO_EXISTE   (-20002) — el id_usuario no existe en USUARIOS
--   PLAN_NO_EXISTE      (-20003) — el id_plan_nuevo no existe en PLANES
--   MISMO_PLAN          (-20004) — el usuario ya tiene ese plan activo
--
-- LOGICA:
--   1. Validar que el usuario existe                  -> USUARIO_NO_EXISTE
--   2. Validar que el nuevo plan existe               -> PLAN_NO_EXISTE
--   3. Validar que no sea el mismo plan actual        -> MISMO_PLAN
--   4. Contar perfiles activos del usuario
--   5. Comparar con max_perfiles del nuevo plan       -> PERFILES_EXCEDIDOS
--   6. Actualizar id_plan en USUARIOS
--   7. COMMIT
--   8. Imprimir confirmacion con detalle del cambio
--
-- EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   Para probar con diferentes casos usar los bloques de prueba al final.
-- =============================================================================


-- =============================================================================
-- CREACION DEL PROCEDIMIENTO
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_CAMBIAR_PLAN (
    p_id_usuario    IN NUMBER,
    p_id_plan_nuevo IN NUMBER
)
IS
    -- -------------------------------------------------------------------------
    -- Declaracion de excepciones personalizadas
    -- Los codigos -20001 a -20999 estan reservados por Oracle para uso
    -- de la aplicacion y no colisionan con errores del sistema.
    -- -------------------------------------------------------------------------
    PERFILES_EXCEDIDOS  EXCEPTION;
    USUARIO_NO_EXISTE   EXCEPTION;
    PLAN_NO_EXISTE      EXCEPTION;
    MISMO_PLAN          EXCEPTION;

    PRAGMA EXCEPTION_INIT(PERFILES_EXCEDIDOS, -20001);
    PRAGMA EXCEPTION_INIT(USUARIO_NO_EXISTE,  -20002);
    PRAGMA EXCEPTION_INIT(PLAN_NO_EXISTE,     -20003);
    PRAGMA EXCEPTION_INIT(MISMO_PLAN,         -20004);

    -- -------------------------------------------------------------------------
    -- Variables de trabajo
    -- -------------------------------------------------------------------------
    v_usuario         USUARIOS%ROWTYPE;         -- fila completa del usuario
    v_plan_actual     PLANES%ROWTYPE;           -- fila del plan actual
    v_plan_nuevo      PLANES%ROWTYPE;           -- fila del nuevo plan
    v_total_perfiles  NUMBER(3) := 0;           -- perfiles activos del usuario

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
                -20002,
                'USUARIO_NO_EXISTE: No se encontro el usuario con id = '
                || p_id_usuario || '.'
            );
END;

    -- =========================================================================
    -- PASO 2: Obtener datos del nuevo plan — valida existencia
    -- =========================================================================
BEGIN
SELECT *
INTO   v_plan_nuevo
FROM   PLANES
WHERE  id_plan = p_id_plan_nuevo;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'PLAN_NO_EXISTE: No se encontro el plan con id = '
                || p_id_plan_nuevo || '.'
            );
END;

    -- =========================================================================
    -- PASO 3: Obtener datos del plan actual (para el mensaje de confirmacion)
    -- =========================================================================
SELECT *
INTO   v_plan_actual
FROM   PLANES
WHERE  id_plan = v_usuario.id_plan;

-- =========================================================================
-- PASO 4: Validar que no sea el mismo plan
-- =========================================================================
IF v_usuario.id_plan = p_id_plan_nuevo THEN
        RAISE_APPLICATION_ERROR(
            -20004,
            'MISMO_PLAN: El usuario ' || p_id_usuario
            || ' ya tiene el plan "' || v_plan_nuevo.nombre
            || '" activo. No se realizo ningun cambio.'
        );
END IF;

    -- =========================================================================
    -- PASO 5: Contar perfiles activos del usuario
    -- =========================================================================
SELECT COUNT(*)
INTO   v_total_perfiles
FROM   PERFILES
WHERE  id_usuario = p_id_usuario;

-- =========================================================================
-- PASO 6: Validar que el nuevo plan soporte los perfiles existentes
-- Esta es la validacion critica — excepcion PERFILES_EXCEDIDOS (-20001)
-- Ejemplo: usuario tiene 3 perfiles y quiere pasar a Basico (max 2)
-- =========================================================================
IF v_total_perfiles > v_plan_nuevo.max_perfiles THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'PERFILES_EXCEDIDOS: El usuario ' || p_id_usuario
            || ' tiene ' || v_total_perfiles || ' perfil(es) activo(s), '
            || 'pero el plan "' || v_plan_nuevo.nombre
            || '" permite un maximo de ' || v_plan_nuevo.max_perfiles || '.'
            || ' Elimine ' || (v_total_perfiles - v_plan_nuevo.max_perfiles)
            || ' perfil(es) antes de cambiar al nuevo plan.'
        );
END IF;

    -- =========================================================================
    -- PASO 7: Aplicar el cambio de plan
    -- =========================================================================
UPDATE USUARIOS
SET    id_plan = p_id_plan_nuevo
WHERE  id_usuario = p_id_usuario;

-- =========================================================================
-- PASO 8: Confirmar la transaccion
-- =========================================================================
COMMIT;

-- =========================================================================
-- PASO 9: Imprimir resumen del cambio realizado
-- =========================================================================
DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  SP_CAMBIAR_PLAN — Cambio exitoso');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  Usuario     : ' || v_usuario.nombre
                         || ' ' || v_usuario.apellido
                         || ' (id=' || p_id_usuario || ')');
    DBMS_OUTPUT.PUT_LINE('  Email       : ' || v_usuario.email);
    DBMS_OUTPUT.PUT_LINE('  Plan anterior: ' || v_plan_actual.nombre
                         || ' ($' || v_plan_actual.precio_mensual
                         || '/mes, max ' || v_plan_actual.max_perfiles
                         || ' perfiles)');
    DBMS_OUTPUT.PUT_LINE('  Plan nuevo  : ' || v_plan_nuevo.nombre
                         || ' ($' || v_plan_nuevo.precio_mensual
                         || '/mes, max ' || v_plan_nuevo.max_perfiles
                         || ' perfiles)');
    DBMS_OUTPUT.PUT_LINE('  Perfiles    : ' || v_total_perfiles
                         || ' (dentro del limite del nuevo plan)');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
    -- =========================================================================
    -- Excepciones personalizadas — relanzar con mensaje ya formateado
    -- RAISE_APPLICATION_ERROR ya imprime el mensaje; aqui solo hacemos
    -- ROLLBACK por seguridad y relanzamos para que el caller lo vea.
    -- =========================================================================
    WHEN PERFILES_EXCEDIDOS OR USUARIO_NO_EXISTE
      OR PLAN_NO_EXISTE     OR MISMO_PLAN THEN
        ROLLBACK;
        RAISE;

    -- =========================================================================
    -- Cualquier otro error inesperado de Oracle
    -- =========================================================================
WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(
            -20099,
            'SP_CAMBIAR_PLAN — Error inesperado: '
            || SQLERRM
        );
END SP_CAMBIAR_PLAN;
/


-- =============================================================================
-- BLOQUES DE PRUEBA
-- Ejecutar cada bloque por separado con SET SERVEROUTPUT ON primero.
-- =============================================================================

-- Activar salida de DBMS_OUTPUT
SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: Cambio EXITOSO — upgrade Basico -> Estandar
-- Usuario 3 (Valeria Lozano): Basico, 1 perfil -> Estandar (max 3) OK
-- Se revierte al final para no afectar el estado de la BD
-- -----------------------------------------------------------------------------
PROMPT PRUEBA 1: Cambio exitoso (upgrade Basico -> Estandar)
BEGIN
    SP_CAMBIAR_PLAN(p_id_usuario => 3, p_id_plan_nuevo => 2);
END;
/
-- Revertir para dejar BD igual que antes
UPDATE USUARIOS SET id_plan = 1 WHERE id_usuario = 3;
COMMIT;


-- -----------------------------------------------------------------------------
-- PRUEBA 2: Error PERFILES_EXCEDIDOS (-20001)
-- Usuario 15 (Karen Restrepo): Estandar, 3 perfiles -> Basico (max 2) FALLA
-- No modifica nada — solo demuestra la excepcion
-- -----------------------------------------------------------------------------
PROMPT PRUEBA 2: Error PERFILES_EXCEDIDOS
BEGIN
    SP_CAMBIAR_PLAN(p_id_usuario => 15, p_id_plan_nuevo => 1);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: Error USUARIO_NO_EXISTE (-20002)
-- ID 99999 no existe — no modifica nada
-- -----------------------------------------------------------------------------
PROMPT PRUEBA 3: Error USUARIO_NO_EXISTE
BEGIN
    SP_CAMBIAR_PLAN(p_id_usuario => 99999, p_id_plan_nuevo => 2);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 4: Error PLAN_NO_EXISTE (-20003)
-- Plan 99 no existe — no modifica nada
-- -----------------------------------------------------------------------------
PROMPT PRUEBA 4: Error PLAN_NO_EXISTE
BEGIN
    SP_CAMBIAR_PLAN(p_id_usuario => 3, p_id_plan_nuevo => 99);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 5: Error MISMO_PLAN (-20004)
-- Usuario 3 (Valeria): ya tiene plan Basico (id=1) -> intenta Basico de nuevo
-- No modifica nada
-- -----------------------------------------------------------------------------
PROMPT PRUEBA 5: Error MISMO_PLAN
BEGIN
    SP_CAMBIAR_PLAN(p_id_usuario => 3, p_id_plan_nuevo => 1);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- VERIFICACION: Confirmar cambio aplicado en BD
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT VERIFICACION: Estado actual de usuarios y sus planes
PROMPT ============================================================

SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido   AS usuario,
    p.nombre                         AS plan_actual,
    p.max_perfiles                   AS max_perfiles_plan,
    (SELECT COUNT(*) FROM PERFILES pf WHERE pf.id_usuario = u.id_usuario)
        AS perfiles_activos,
    u.estado_cuenta
FROM USUARIOS u
         JOIN PLANES   p ON p.id_plan = u.id_plan
ORDER BY u.id_usuario;