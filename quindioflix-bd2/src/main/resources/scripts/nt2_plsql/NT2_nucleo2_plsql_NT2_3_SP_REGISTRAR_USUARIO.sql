-- =============================================================================
-- NT2-3: SP_REGISTRAR_USUARIO
-- Script  : NT2_nucleo2_plsql_NT2_3_SP_REGISTRAR_USUARIO.sql
-- Autor   : Cristhian Osorio
-- Tarea   : NT2-3 del cronograma QuindioFlix — Sprint 3
--
-- DESCRIPCION:
--   Procedimiento almacenado que registra un nuevo usuario en la plataforma.
--   Valida que el email no este duplicado y que el plan elegido exista.
--   Si las validaciones pasan, crea la cuenta, un perfil predeterminado
--   y registra el primer pago. Toda la operacion es atomica: si falla
--   cualquier paso se hace ROLLBACK completo.
--
-- PARAMETROS DE ENTRADA:
--   p_nombre           VARCHAR2 — nombre(s) del usuario
--   p_apellido         VARCHAR2 — apellido(s) del usuario
--   p_email            VARCHAR2 — correo electronico (debe ser unico)
--   p_contrasena_hash  VARCHAR2 — hash de la contrasena (nunca texto plano)
--   p_ciudad           VARCHAR2 — ciudad de residencia (puede ser NULL)
--   p_id_plan          NUMBER   — id del plan de suscripcion elegido
--   p_metodo_pago      VARCHAR2 — metodo del primer pago (default: TARJETA)
--   p_id_referidor     NUMBER   — id del usuario referidor (puede ser NULL)
--
-- PARAMETRO DE SALIDA:
--   p_id_usuario       NUMBER   — id del usuario recien creado
--
-- EXCEPCIONES PERSONALIZADAS (NT2-8):
--   EMAIL_DUPLICADO  (-20011) — el email ya esta registrado en USUARIOS
--   PLAN_NO_EXISTE   (-20012) — el id_plan no existe en PLANES
--
-- LOGICA:
--   1. Validar que el plan existe                    -> PLAN_NO_EXISTE
--   2. Validar que el email no esta duplicado        -> EMAIL_DUPLICADO
--   3. INSERT en USUARIOS (estado ACTIVO, 30 dias de vigencia)
--   4. INSERT en PERFILES (perfil 'Principal', tipo ADULTO)
--   5. INSERT en PAGOS (monto del plan, estado EXITOSO)
--   6. COMMIT
--   7. Retornar id_usuario creado y mostrar resumen
--
-- EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   Activar SET SERVEROUTPUT ON antes de ejecutar los bloques de prueba.
-- =============================================================================


-- =============================================================================
-- CREACION DEL PROCEDIMIENTO
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_REGISTRAR_USUARIO (
    p_nombre           IN  VARCHAR2,
    p_apellido         IN  VARCHAR2,
    p_email            IN  VARCHAR2,
    p_contrasena_hash  IN  VARCHAR2,
    p_ciudad           IN  VARCHAR2 DEFAULT NULL,
    p_id_plan          IN  NUMBER,
    p_metodo_pago      IN  VARCHAR2 DEFAULT 'TARJETA',
    p_id_referidor     IN  NUMBER   DEFAULT NULL,
    p_id_usuario       OUT NUMBER
)
IS
    -- -------------------------------------------------------------------------
    -- Declaracion de excepciones personalizadas (NT2-8)
    -- Rango -20011/-20012 para no colisionar con SP_CAMBIAR_PLAN (-20001/-20004)
    -- -------------------------------------------------------------------------
    EMAIL_DUPLICADO  EXCEPTION;
    PLAN_NO_EXISTE   EXCEPTION;

    PRAGMA EXCEPTION_INIT(EMAIL_DUPLICADO, -20011);
    PRAGMA EXCEPTION_INIT(PLAN_NO_EXISTE,  -20012);

    -- -------------------------------------------------------------------------
    -- Variables de trabajo
    -- -------------------------------------------------------------------------
    v_plan         PLANES%ROWTYPE;
    v_count_email  NUMBER(3) := 0;
    v_id_nuevo     NUMBER(8);

BEGIN

    -- =========================================================================
    -- PASO 1: Validar que el plan existe
    -- =========================================================================
BEGIN
SELECT *
INTO   v_plan
FROM   PLANES
WHERE  id_plan = p_id_plan;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20012,
                'PLAN_NO_EXISTE: No se encontro el plan con id = '
                || p_id_plan || '. Planes validos: 1 (Basico), 2 (Estandar), 3 (Premium).'
            );
END;

    -- =========================================================================
    -- PASO 2: Validar que el email no este duplicado
    -- =========================================================================
SELECT COUNT(*)
INTO   v_count_email
FROM   USUARIOS
WHERE  email = LOWER(TRIM(p_email));

IF v_count_email > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'EMAIL_DUPLICADO: El email "' || LOWER(TRIM(p_email))
            || '" ya esta registrado en la plataforma.'
            || ' Use otro correo o recupere su contrasena.'
        );
END IF;

    -- =========================================================================
    -- PASO 3: Crear la cuenta del usuario
    -- fecha_vencimiento = SYSDATE + 30 (primer mes de suscripcion)
    -- estado_cuenta = ACTIVO desde el primer pago aprobado
    -- =========================================================================
INSERT INTO USUARIOS (
    nombre, apellido, email, contrasena_hash,
    fecha_registro, fecha_vencimiento,
    estado_cuenta, es_moderador,
    ciudad_residencia, id_plan, id_referidor
)
VALUES (
           TRIM(p_nombre),
           TRIM(p_apellido),
           LOWER(TRIM(p_email)),
           p_contrasena_hash,
           SYSDATE,
           SYSDATE + 30,
           'ACTIVO',
           'N',
           TRIM(p_ciudad),
           p_id_plan,
           p_id_referidor
       )
    RETURNING id_usuario INTO v_id_nuevo;

-- =========================================================================
-- PASO 4: Crear perfil predeterminado 'Principal'
-- Cada cuenta empieza con un perfil adulto de nombre Principal
-- =========================================================================
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Principal', 'ADULTO', v_id_nuevo);

-- =========================================================================
-- PASO 5: Registrar el primer pago por el monto del plan elegido
-- El pago se registra como APROBADO para activar la cuenta de inmediato
-- =========================================================================
INSERT INTO PAGOS (
    fecha_pago, monto, metodo_pago,
    estado_pago, descuento_aplicado, id_usuario
)
VALUES (
           SYSDATE,
           v_plan.precio_mensual,
           p_metodo_pago,
           'EXITOSO',
           0,
           v_id_nuevo
       );

-- =========================================================================
-- PASO 6: Confirmar la transaccion completa
-- =========================================================================
COMMIT;

-- =========================================================================
-- PASO 7: Retornar el id y mostrar resumen del registro
-- =========================================================================
p_id_usuario := v_id_nuevo;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  SP_REGISTRAR_USUARIO — Registro exitoso');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  ID usuario  : ' || v_id_nuevo);
    DBMS_OUTPUT.PUT_LINE('  Nombre      : ' || TRIM(p_nombre)
                         || ' ' || TRIM(p_apellido));
    DBMS_OUTPUT.PUT_LINE('  Email       : ' || LOWER(TRIM(p_email)));
    DBMS_OUTPUT.PUT_LINE('  Ciudad      : ' || NVL(TRIM(p_ciudad), '(no especificada)'));
    DBMS_OUTPUT.PUT_LINE('  Plan        : ' || v_plan.nombre
                         || ' ($' || v_plan.precio_mensual || '/mes)');
    DBMS_OUTPUT.PUT_LINE('  Vencimiento : ' || TO_CHAR(SYSDATE + 30, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('  Pago        : $' || v_plan.precio_mensual
                         || ' via ' || p_metodo_pago || ' — EXITOSO');
    DBMS_OUTPUT.PUT_LINE('  Perfil      : "Principal" (ADULTO) creado');
    DBMS_OUTPUT.PUT_LINE('  Referidor   : ' || NVL(TO_CHAR(p_id_referidor), 'ninguno'));
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
    -- =========================================================================
    -- Excepciones personalizadas: ROLLBACK y relanzar para que el caller lo vea
    -- =========================================================================
    WHEN EMAIL_DUPLICADO OR PLAN_NO_EXISTE THEN
        ROLLBACK;
        RAISE;

    -- =========================================================================
    -- Cualquier otro error inesperado de Oracle
    -- =========================================================================
WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(
            -20099,
            'SP_REGISTRAR_USUARIO — Error inesperado: ' || SQLERRM
        );
END SP_REGISTRAR_USUARIO;
/


-- =============================================================================
-- BLOQUES DE PRUEBA
-- Ejecutar cada bloque por separado. Activar SERVEROUTPUT primero.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: Registro EXITOSO — nuevo usuario con plan Basico via PSE
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 1: Registro exitoso (plan Basico, metodo PSE)
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Laura',
        p_apellido        => 'Montoya',
        p_email           => 'laura.montoya@test.com',
        p_contrasena_hash => 'hash_test_001',
        p_ciudad          => 'Manizales',
        p_id_plan         => 1,
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id
    );
    DBMS_OUTPUT.PUT_LINE('Usuario creado con id = ' || v_id);
END;
/
-- Revertir para no acumular datos de prueba
DECLARE
v_id NUMBER;
BEGIN
SELECT id_usuario INTO v_id FROM USUARIOS WHERE email = 'laura.montoya@test.com';
DELETE FROM PAGOS   WHERE id_usuario = v_id;
DELETE FROM PERFILES WHERE id_usuario = v_id;
DELETE FROM USUARIOS WHERE id_usuario = v_id;
COMMIT;
DBMS_OUTPUT.PUT_LINE('Prueba 1 revertida — BD en estado original.');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: Registro EXITOSO — usuario con plan Premium y referidor (id=1)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 2: Registro exitoso (plan Premium, con referidor)
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Carlos',
        p_apellido        => 'Rios',
        p_email           => 'carlos.rios@test.com',
        p_contrasena_hash => 'hash_test_002',
        p_ciudad          => 'Armenia',
        p_id_plan         => 3,
        p_metodo_pago     => 'NEQUI',
        p_id_referidor    => 1,
        p_id_usuario      => v_id
    );
    DBMS_OUTPUT.PUT_LINE('Usuario creado con id = ' || v_id);
END;
/
DECLARE
v_id NUMBER;
BEGIN
SELECT id_usuario INTO v_id FROM USUARIOS WHERE email = 'carlos.rios@test.com';
DELETE FROM PAGOS   WHERE id_usuario = v_id;
DELETE FROM PERFILES WHERE id_usuario = v_id;
DELETE FROM USUARIOS WHERE id_usuario = v_id;
COMMIT;
DBMS_OUTPUT.PUT_LINE('Prueba 2 revertida — BD en estado original.');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: Error EMAIL_DUPLICADO (-20011)
-- sofia.perea@quindioflix.com ya existe en los datos de prueba
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 3: Error EMAIL_DUPLICADO
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Sofia',
        p_apellido        => 'Duplicada',
        p_email           => 'sofia.perea@quindioflix.com',
        p_contrasena_hash => 'hash_dup',
        p_ciudad          => 'Armenia',
        p_id_plan         => 1,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado correctamente: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 4: Error PLAN_NO_EXISTE (-20012)
-- Plan 99 no existe en PLANES
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 4: Error PLAN_NO_EXISTE
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Ana',
        p_apellido        => 'Test',
        p_email           => 'ana.test@test.com',
        p_contrasena_hash => 'hash_test_003',
        p_ciudad          => 'Pereira',
        p_id_plan         => 99,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado correctamente: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- VERIFICACION: Confirmar estado de la BD despues de las pruebas
-- Debe mostrar exactamente los mismos registros que antes de ejecutar
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT VERIFICACION: Conteos finales (deben coincidir con el estado inicial)
PROMPT ============================================================

SELECT 'USUARIOS' tabla, COUNT(*) total FROM USUARIOS
UNION ALL
SELECT 'PERFILES', COUNT(*) FROM PERFILES
UNION ALL
SELECT 'PAGOS',    COUNT(*) FROM PAGOS;