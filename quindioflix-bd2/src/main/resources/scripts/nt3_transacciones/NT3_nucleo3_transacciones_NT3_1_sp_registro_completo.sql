-- =============================================================================
-- NT3-1: Transaccion de registro completo — QuindioFlix
-- Archivo : NT3_nucleo3_transacciones_NT3_1_SP_REGISTRO_COMPLETO.sql
-- Autor   : Daniel Narvaez
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- =============================================================================
-- Logica:
--   Registra un usuario completo (USUARIOS + PERFILES + PAGOS) en una sola
--   transaccion atomica documentando explicitamente cada estado de la
--   transaccion Oracle segun el modelo de estados de NT3.
--
--   Relacion con NT2-3:
--   SP_REGISTRAR_USUARIO (NT2-3, Cristhian Osorio) implementa la logica de
--   negocio (validaciones, inserciones, excepciones). Este SP la envuelve
--   documentando los estados de transaccion requeridos por NT3.
--
-- Estados documentados:
--   ACTIVA              : inicio, antes de cualquier INSERT
--   PARCIALMENTE CONF.  : tras cada INSERT exitoso (usuario, perfil, pago)
--   CONFIRMADA          : tras COMMIT exitoso
--   FALLIDA             : error de negocio (email duplicado, plan inexistente)
--                         -> ROLLBACK total
--   ABORTADA            : error inesperado del sistema -> ROLLBACK total
--
-- Atomicidad:
--   Si falla cualquiera de los 3 pasos (usuario, perfil, pago) se hace
--   ROLLBACK completo. No puede quedar un usuario sin perfil ni sin pago.
--
-- Codigos de error propios:
--   -20051  REGISTRO_FALLIDO   — error de negocio (email dup / plan inex.)
--   -20099  Error inesperado   (catch-all, compartido con SPs NT2/NT3)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_REGISTRO_COMPLETO (
    p_nombre          IN  VARCHAR2,
    p_apellido        IN  VARCHAR2,
    p_email           IN  VARCHAR2,
    p_contrasena_hash IN  VARCHAR2,
    p_ciudad          IN  VARCHAR2 DEFAULT NULL,
    p_id_plan         IN  NUMBER,
    p_metodo_pago     IN  VARCHAR2 DEFAULT 'PSE',
    p_id_referidor    IN  NUMBER   DEFAULT NULL,
    p_id_usuario      OUT NUMBER
)
IS
    REGISTRO_FALLIDO EXCEPTION;
    PRAGMA EXCEPTION_INIT(REGISTRO_FALLIDO, -20051);

    v_plan        PLANES%ROWTYPE;
    v_count_email NUMBER(3) := 0;
    v_id_nuevo    NUMBER(8);

BEGIN

    -- =========================================================================
    -- ESTADO: ACTIVA
    -- La transaccion inicia. Ningun dato ha sido modificado aun.
    -- =========================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('   SP_REGISTRO_COMPLETO — QUINDIOFLIX');
    DBMS_OUTPUT.PUT_LINE('   Fecha: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ESTADO: ACTIVA — transaccion iniciada, validando datos');

    -- =========================================================================
    -- PASO 1: Validaciones previas (sin modificar datos)
    -- Si fallan aqui el ESTADO pasa a FALLIDA sin haber tocado nada.
    -- =========================================================================

    -- 1a. Validar plan
BEGIN
SELECT * INTO v_plan FROM PLANES WHERE id_plan = p_id_plan;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ESTADO: FALLIDA — plan ' || p_id_plan || ' no existe');
ROLLBACK;
RAISE_APPLICATION_ERROR(-20051,
                'SP_REGISTRO_COMPLETO: PLAN_NO_EXISTE — id_plan = ' || p_id_plan);
END;

    -- 1b. Validar email unico
SELECT COUNT(*) INTO v_count_email
FROM   USUARIOS WHERE email = LOWER(TRIM(p_email));

IF v_count_email > 0 THEN
        DBMS_OUTPUT.PUT_LINE('ESTADO: FALLIDA — email "' ||
            LOWER(TRIM(p_email)) || '" ya registrado');
ROLLBACK;
RAISE_APPLICATION_ERROR(-20051,
            'SP_REGISTRO_COMPLETO: EMAIL_DUPLICADO — ' || LOWER(TRIM(p_email)));
END IF;

    DBMS_OUTPUT.PUT_LINE('  Validaciones OK: plan=' ||
        v_plan.nombre || ', email libre');

    -- =========================================================================
    -- PASO 2: INSERT en USUARIOS
    -- ESTADO: PARCIALMENTE CONFIRMADA (1/3)
    -- =========================================================================
INSERT INTO USUARIOS (
    nombre, apellido, email, contrasena_hash,
    fecha_registro, fecha_vencimiento,
    estado_cuenta, es_moderador,
    ciudad_residencia, id_plan, id_referidor
) VALUES (
             TRIM(p_nombre), TRIM(p_apellido),
             LOWER(TRIM(p_email)), p_contrasena_hash,
             SYSDATE, SYSDATE + 30,
             'ACTIVO', 'N',
             TRIM(p_ciudad), p_id_plan, p_id_referidor
         ) RETURNING id_usuario INTO v_id_nuevo;

DBMS_OUTPUT.PUT_LINE('ESTADO: PARCIALMENTE CONFIRMADA (1/3) — ' ||
        'usuario id=' || v_id_nuevo || ' insertado, pendiente perfil y pago');

    -- =========================================================================
    -- PASO 3: INSERT en PERFILES
    -- ESTADO: PARCIALMENTE CONFIRMADA (2/3)
    -- =========================================================================
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Principal', 'ADULTO', v_id_nuevo);

DBMS_OUTPUT.PUT_LINE('ESTADO: PARCIALMENTE CONFIRMADA (2/3) — ' ||
        'perfil "Principal" creado, pendiente pago');

    -- =========================================================================
    -- PASO 4: INSERT en PAGOS
    -- ESTADO: PARCIALMENTE CONFIRMADA (3/3)
    -- =========================================================================
INSERT INTO PAGOS (
    fecha_pago, monto, metodo_pago,
    estado_pago, descuento_aplicado, id_usuario
) VALUES (
             SYSDATE, v_plan.precio_mensual,
             p_metodo_pago, 'EXITOSO', 0, v_id_nuevo
         );

DBMS_OUTPUT.PUT_LINE('ESTADO: PARCIALMENTE CONFIRMADA (3/3) — ' ||
        'pago $' || v_plan.precio_mensual || ' via ' ||
        p_metodo_pago || ' registrado, listo para COMMIT');

    -- =========================================================================
    -- PASO 5: COMMIT — confirma los 3 INSERTs como una unidad atomica
    -- ESTADO: CONFIRMADA
    -- =========================================================================
COMMIT;

p_id_usuario := v_id_nuevo;

    DBMS_OUTPUT.PUT_LINE('ESTADO: CONFIRMADA — COMMIT ejecutado exitosamente');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('  ID usuario  : ' || v_id_nuevo);
    DBMS_OUTPUT.PUT_LINE('  Nombre      : ' || TRIM(p_nombre) || ' ' || TRIM(p_apellido));
    DBMS_OUTPUT.PUT_LINE('  Email       : ' || LOWER(TRIM(p_email)));
    DBMS_OUTPUT.PUT_LINE('  Plan        : ' || v_plan.nombre ||
        ' ($' || v_plan.precio_mensual || '/mes)');
    DBMS_OUTPUT.PUT_LINE('  Vencimiento : ' || TO_CHAR(SYSDATE + 30, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('  Metodo pago : ' || p_metodo_pago);
    DBMS_OUTPUT.PUT_LINE('  Referidor   : ' || NVL(TO_CHAR(p_id_referidor), 'ninguno'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');

EXCEPTION
    -- =========================================================================
    -- ESTADO: FALLIDA — error de negocio ya manejado arriba (re-raise)
    -- =========================================================================
    WHEN REGISTRO_FALLIDO THEN
        ROLLBACK;
        RAISE;

    -- =========================================================================
    -- ESTADO: ABORTADA — error inesperado del sistema
    -- ROLLBACK total: ninguno de los 3 pasos persiste
    -- =========================================================================
WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ESTADO: ABORTADA — error inesperado: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('ROLLBACK total ejecutado.');
        RAISE_APPLICATION_ERROR(-20099,
            'SP_REGISTRO_COMPLETO — Error: ' || SQLERRM);

END SP_REGISTRO_COMPLETO;
/


-- =============================================================================
-- PRUEBAS DE SP_REGISTRO_COMPLETO
-- Todas las pruebas usan usuarios temporales y los limpian al final.
-- La BD queda en el mismo estado que antes de ejecutar el script.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: Registro exitoso — estado CONFIRMADA
-- Crea un usuario temporal, verifica los estados y lo limpia.
-- -----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT NT3-1 PRUEBA 1: Registro exitoso — estado CONFIRMADA
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRO_COMPLETO(
        p_nombre          => 'Registro',
        p_apellido        => 'NT3 Prueba',
        p_email           => 'registro.nt3.p1@quindioflix.com',
        p_contrasena_hash => 'hash_nt3_p1',
        p_ciudad          => 'Armenia',
        p_id_plan         => 1,
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id
    );
    DBMS_OUTPUT.PUT_LINE('P1 OK: id=' || v_id);

    -- Limpiar usuario temporal
DELETE FROM PAGOS    WHERE id_usuario = v_id;
DELETE FROM PERFILES WHERE id_usuario = v_id;
DELETE FROM USUARIOS WHERE id_usuario = v_id;
COMMIT;
DBMS_OUTPUT.PUT_LINE('P1 revertida — BD en estado original.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('P1 ERROR: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: EMAIL_DUPLICADO — estado FALLIDA
-- Intenta registrar con un email ya existente.
-- -----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT NT3-1 PRUEBA 2: EMAIL_DUPLICADO — estado FALLIDA
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRO_COMPLETO(
        p_nombre          => 'Duplicado',
        p_apellido        => 'Test',
        p_email           => 'sofia.perea@quindioflix.com',  -- ya existe
        p_contrasena_hash => 'hash_dup',
        p_ciudad          => 'Pereira',
        p_id_plan         => 1,
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('P2 OK — estado FALLIDA capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: PLAN_NO_EXISTE — estado FALLIDA
-- Intenta registrar con un id_plan inexistente.
-- -----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT NT3-1 PRUEBA 3: PLAN_NO_EXISTE — estado FALLIDA
PROMPT ============================================================
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRO_COMPLETO(
        p_nombre          => 'PlanInexistente',
        p_apellido        => 'Test',
        p_email           => 'planinex.nt3@quindioflix.com',
        p_contrasena_hash => 'hash_plan',
        p_ciudad          => 'Manizales',
        p_id_plan         => 99,  -- no existe
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('P3 OK — estado FALLIDA capturado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 4: Verificar atomicidad — BD integra despues de fallo
-- Confirma que un registro fallido no dejo datos huerfanos.
-- -----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT NT3-1 PRUEBA 4: Atomicidad — sin datos huerfanos tras fallo
PROMPT ============================================================
DECLARE
v_id  NUMBER;
    v_cnt NUMBER;
BEGIN
    -- Intentar registro con plan inexistente
BEGIN
        SP_REGISTRO_COMPLETO('Huerfano','Test','huerfano.nt3@quindioflix.com',
            'hash','Armenia',99,'PSE',NULL,v_id);
EXCEPTION WHEN OTHERS THEN NULL;
END;

    -- Verificar que no quedo el usuario en la BD
SELECT COUNT(*) INTO v_cnt
FROM   USUARIOS WHERE email = 'huerfano.nt3@quindioflix.com';

IF v_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('P4 OK: ROLLBACK atomico verificado, sin datos huerfanos.');
ELSE
        DBMS_OUTPUT.PUT_LINE('P4 FALLO: quedo usuario sin perfil ni pago.');
END IF;
END;
/