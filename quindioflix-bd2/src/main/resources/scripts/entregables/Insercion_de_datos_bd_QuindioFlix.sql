-- =============================================================================
-- ENTREGABLE: Nucleo 3 — Transacciones | QuindioFlix
-- Archivo  : ENT_03_NT3_transacciones.sql
-- Carpeta  : scripts/entregables/
-- Autores  : Daniel Narvaez, Diego Garcia, Cristhian Osorio
-- Curso    : Bases de Datos II — Universidad del Quindio 2026-1
-- =============================================================================
-- Contiene los 4 scripts del Nucleo 3 (Transacciones y Concurrencia):
--
--   NT3-1  SP_REGISTRO_COMPLETO   — Daniel Narvaez
--          Transaccion de registro usuario + perfil + pago con documentacion
--          de estados: ACTIVA, PARCIALMENTE CONFIRMADA (1/3, 2/3, 3/3),
--          CONFIRMADA, FALLIDA, ABORTADA.
--
--   NT3-2  SP_RENOVACION_MENSUAL  — Diego Garcia
--          Renovacion masiva mensual con SAVEPOINT por usuario: si falla
--          un usuario, los anteriores ya procesados no se revierten.
--          Estados: ACTIVA, PARCIALMENTE CONFIRMADA (por usuario),
--          CONFIRMADA, ROLLBACK PARCIAL, ABORTADA.
--
--   NT3-3  SP_ELIMINAR_CUENTA     — Cristhian Osorio
--          Eliminacion atomica en cascada: reportes, calificaciones,
--          favoritos, reproducciones, perfiles, pagos, usuario raiz.
--          Si cualquier paso falla: ROLLBACK completo.
--
--   NT3-4  Escenario de Concurrencia SELECT FOR UPDATE  — Daniel Narvaez
--          Demostracion de bloqueo a nivel de fila con dos sesiones
--          simultaneas intentando cambiar el plan del mismo usuario.
--          Incluye instrucciones paso a paso y consulta de diagnostico
--          de locks activos (ejecutar como SYSTEM).
--
-- PREREQUISITO: NT2 completo (todos los objetos PL/SQL deben estar VALID).
-- EJECUCION   : NT3-1, NT3-2, NT3-3 con F5 en SQL Developer como QUINDIOFLIX.
--               NT3-4: ejecutar bloque por bloque en DOS ventanas separadas.
-- =============================================================================


-- =============================================================================
-- NT3_1_sp_registro_completo
-- =============================================================================

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

-- =============================================================================
-- NT3_2_renovacion_mensual
-- =============================================================================

-- =============================================================================
-- NT3-2: Transaccion de renovacion mensual — QuindioFlix
-- Archivo : NT3_nucleo3_transacciones_NT3_2_SP_RENOVACION_MENSUAL.sql
-- Autor   : Diego Garcia
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- =============================================================================
-- Logica:
--   Procesa la renovacion mensual de todos los usuarios activos cuya
--   fecha_vencimiento sea menor o igual a SYSDATE. Por cada usuario:
--     1. Establece un SAVEPOINT individual
--     2. Calcula el monto con FN_CALCULAR_MONTO (descuento por antiguedad)
--     3. Registra el pago en PAGOS con estado EXITOSO
--     4. Actualiza fecha_vencimiento = fecha_vencimiento + 30
--   Si falla cualquier paso del usuario -> ROLLBACK TO SAVEPOINT
--   (los usuarios ya procesados no se pierden).
--   Al final: COMMIT global de todos los usuarios exitosos.
--
-- SAVEPOINT por usuario:
--   Permite que si el usuario N falla, los usuarios 1..N-1 ya procesados
--   no se reviertan. Sin SAVEPOINT cualquier fallo reverteria todo.
--
-- Estados documentados:
--   ACTIVA           : inicio del SP, antes del primer usuario
--   PARCIALMENTE     : despues de cada usuario procesado con exito
--   CONFIRMADA       : tras el COMMIT global
--   FALLIDA/ABORTADA : si el bloque completo falla (ROLLBACK total)
--
-- Dependencia: FN_CALCULAR_MONTO (NT2-6, Cristhian Osorio)
--
-- Codigos de error propios:
--   -20031  SIN_USUARIOS_ELEGIBLES — ningún usuario activo vencido
--   -20099  Error inesperado (catch-all)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_RENOVACION_MENSUAL
IS
    -- Cursor de usuarios elegibles para renovacion
    CURSOR cur_usuarios_renovar IS
SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido   AS nombre_completo,
    u.fecha_vencimiento,
    u.id_plan,
    pl.nombre                        AS nombre_plan
FROM USUARIOS u
         JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE u.estado_cuenta   = 'ACTIVO'
  AND u.fecha_vencimiento <= SYSDATE
ORDER BY u.id_usuario;

-- Variables de trabajo
v_monto             NUMBER(10,2);
    v_renovados         NUMBER := 0;
    v_fallidos          NUMBER := 0;
    v_total_cobrado     NUMBER := 0;
    v_elegibles         NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('   SP_RENOVACION_MENSUAL — QUINDIOFLIX');
    DBMS_OUTPUT.PUT_LINE('   Fecha: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ESTADO: ACTIVA — iniciando procesamiento');
    DBMS_OUTPUT.PUT_LINE('');

    -- Verificar si hay usuarios elegibles
SELECT COUNT(*) INTO v_elegibles
FROM USUARIOS
WHERE estado_cuenta    = 'ACTIVO'
  AND fecha_vencimiento <= SYSDATE;

IF v_elegibles = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ESTADO: CONFIRMADA — sin usuarios elegibles para renovar.');
        RETURN;
END IF;

    DBMS_OUTPUT.PUT_LINE('Usuarios elegibles: ' || v_elegibles);
    DBMS_OUTPUT.PUT_LINE('');

    -- =========================================================================
    -- Recorrer usuarios elegibles con SAVEPOINT individual por usuario
    -- =========================================================================
FOR v_usr IN cur_usuarios_renovar LOOP

BEGIN
            -- -----------------------------------------------------------------
            -- SAVEPOINT: marca de retroceso individual para este usuario
            -- Si este usuario falla, solo se revierte el hasta aqui
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
    -- =========================================================================
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ESTADO: ABORTADA — error catastrofico: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Se ejecuto ROLLBACK total.');
        RAISE_APPLICATION_ERROR(-20099,
            'SP_RENOVACION_MENSUAL — Error inesperado: ' || SQLERRM);
END SP_RENOVACION_MENSUAL;
/

-- =============================================================================
-- PRUEBAS DE SP_RENOVACION_MENSUAL
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ============================================================
PROMPT NT3-2 PRUEBA 1: Ejecucion normal — usuarios vencidos
PROMPT ============================================================
BEGIN
    SP_RENOVACION_MENSUAL;
END;
/

-- Verificar pagos registrados hoy
PROMPT
PROMPT ============================================================
PROMPT NT3-2 PRUEBA 2: Verificacion — pagos registrados hoy
PROMPT ============================================================
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

PROMPT
PROMPT ============================================================
PROMPT NT3-2 PRUEBA 3: Segunda ejecucion — no debe renovar nadie
PROMPT (fecha_vencimiento ya fue actualizada a SYSDATE+30)
PROMPT ============================================================
BEGIN
    SP_RENOVACION_MENSUAL;
END;
/

-- =============================================================================
-- NT3_3_SP_ELIMINAR_CUENTA
-- =============================================================================

-- =============================================================================
-- NT3-3: Transaccion de eliminacion de cuenta — QuindioFlix
-- Archivo : NT3_nucleo3_transacciones_NT3_3_SP_ELIMINAR_CUENTA.sql
-- Autor   : Cristhian Eduardo Osorio Restrepo
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- Ticket  : SCRUM-52
-- =============================================================================
-- Logica:
--   Elimina un usuario y TODOS sus datos derivados en una sola transaccion
--   atomica. El orden respeta las FK del modelo: primero los hijos mas
--   profundos, luego las tablas intermedias, finalmente el usuario raiz.
--   Si cualquier paso falla → ROLLBACK completo.
--
-- Orden de eliminacion (integridad referencial):
--   1. NULL id_moderador  en REPORTES_INAPROPIADO (FK opcional hacia USUARIOS)
--   2. NULL id_referidor  en USUARIOS que este usuario referia (FK reflexiva)
--   3. DELETE CALIFICACIONES      (depende de PERFILES)
--   4. DELETE FAVORITOS           (depende de PERFILES)
--   5. DELETE REPORTES_INAPROPIADO donde el perfil fue reportante
--   6. DELETE REPRODUCCIONES      (tabla particionada — borra por id_perfil)
--   7. DELETE PERFILES            (depende de USUARIOS)
--   8. DELETE PAGOS               (depende de USUARIOS)
--   9. DELETE USUARIOS            (raiz)
--  10. COMMIT
--
-- Codigos de error propios:
--   -20041  USUARIO_NO_EXISTE
--   -20099  Error inesperado (catch-all, compartido con SPs del NT2)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_ELIMINAR_CUENTA (
    p_id_usuario IN NUMBER
) IS

    USUARIO_NO_EXISTE EXCEPTION;
    PRAGMA EXCEPTION_INIT(USUARIO_NO_EXISTE, -20041);

    v_usuario        USUARIOS%ROWTYPE;
    v_filas_perfiles NUMBER(3) := 0;
    v_filas_pagos    NUMBER(5) := 0;
    v_filas_reprod   NUMBER(6) := 0;
    v_filas_calif    NUMBER(5) := 0;
    v_filas_fav      NUMBER(5) := 0;
    v_filas_rep_mod  NUMBER(3) := 0;
    v_filas_rep_perf NUMBER(3) := 0;

BEGIN

    -- =========================================================================
    -- PASO 1: Verificar existencia del usuario
    -- Lanza NO_DATA_FOUND si no existe; lo capturamos abajo como USUARIO_NO_EXISTE
    -- =========================================================================
SELECT * INTO v_usuario
FROM   USUARIOS
WHERE  id_usuario = p_id_usuario;

-- =========================================================================
-- PASO 2: Liberar FK opcionales antes de borrar la raiz
-- =========================================================================

-- 2a. Reportes que este usuario moderaba — desasignar moderador
UPDATE REPORTES_INAPROPIADO
SET    id_moderador = NULL
WHERE  id_moderador = p_id_usuario;
v_filas_rep_mod := SQL%ROWCOUNT;

    -- 2b. Usuarios que este usuario refirió — cortar FK reflexiva
UPDATE USUARIOS
SET    id_referidor = NULL
WHERE  id_referidor = p_id_usuario;

-- =========================================================================
-- PASO 3: Eliminar datos de perfiles (nivel mas profundo del arbol)
-- =========================================================================

-- 3a. Calificaciones emitidas por los perfiles del usuario
DELETE FROM CALIFICACIONES
WHERE  id_perfil IN (
    SELECT id_perfil FROM PERFILES WHERE id_usuario = p_id_usuario
);
v_filas_calif := SQL%ROWCOUNT;

    -- 3b. Favoritos de los perfiles del usuario
DELETE FROM FAVORITOS
WHERE  id_perfil IN (
    SELECT id_perfil FROM PERFILES WHERE id_usuario = p_id_usuario
);
v_filas_fav := SQL%ROWCOUNT;

    -- 3c. Reportes de contenido inapropiado hechos por los perfiles del usuario
DELETE FROM REPORTES_INAPROPIADO
WHERE  id_perfil_reporta IN (
    SELECT id_perfil FROM PERFILES WHERE id_usuario = p_id_usuario
);
v_filas_rep_perf := SQL%ROWCOUNT;

    -- 3d. Reproducciones (tabla particionada RANGE por fecha_hora_inicio)
    --     Oracle aplica partition pruning automaticamente por id_perfil
DELETE FROM REPRODUCCIONES
WHERE  id_perfil IN (
    SELECT id_perfil FROM PERFILES WHERE id_usuario = p_id_usuario
);
v_filas_reprod := SQL%ROWCOUNT;

    -- =========================================================================
    -- PASO 4: Eliminar perfiles (FK directa hacia USUARIOS)
    -- =========================================================================
DELETE FROM PERFILES WHERE id_usuario = p_id_usuario;
v_filas_perfiles := SQL%ROWCOUNT;

    -- =========================================================================
    -- PASO 5: Eliminar pagos (FK directa hacia USUARIOS)
    -- =========================================================================
DELETE FROM PAGOS WHERE id_usuario = p_id_usuario;
v_filas_pagos := SQL%ROWCOUNT;

    -- =========================================================================
    -- PASO 6: Eliminar usuario raiz
    -- =========================================================================
DELETE FROM USUARIOS WHERE id_usuario = p_id_usuario;

-- =========================================================================
-- PASO 7: Confirmar la transaccion completa
-- =========================================================================
COMMIT;

DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  SP_ELIMINAR_CUENTA — Cuenta eliminada');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  ID usuario  : ' || p_id_usuario);
    DBMS_OUTPUT.PUT_LINE('  Nombre      : ' || v_usuario.nombre
                                           || ' ' || v_usuario.apellido);
    DBMS_OUTPUT.PUT_LINE('  Email       : ' || v_usuario.email);
    DBMS_OUTPUT.PUT_LINE('  Perfiles    : ' || v_filas_perfiles  || ' eliminados');
    DBMS_OUTPUT.PUT_LINE('  Pagos       : ' || v_filas_pagos     || ' eliminados');
    DBMS_OUTPUT.PUT_LINE('  Reproducc.  : ' || v_filas_reprod    || ' eliminadas');
    DBMS_OUTPUT.PUT_LINE('  Calific.    : ' || v_filas_calif     || ' eliminadas');
    DBMS_OUTPUT.PUT_LINE('  Favoritos   : ' || v_filas_fav       || ' eliminados');
    DBMS_OUTPUT.PUT_LINE('  Rep.mod.    : ' || v_filas_rep_mod   || ' desasignados');
    DBMS_OUTPUT.PUT_LINE('  Rep.perf.   : ' || v_filas_rep_perf  || ' eliminados');
    DBMS_OUTPUT.PUT_LINE('==============================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20041,
            'SP_ELIMINAR_CUENTA: Usuario ' || p_id_usuario || ' no existe.');
WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099,
            'SP_ELIMINAR_CUENTA — Error: ' || SQLERRM);
END SP_ELIMINAR_CUENTA;
/

-- =============================================================================
-- PRUEBAS DE SP_ELIMINAR_CUENTA
-- Nota: las pruebas usan un usuario temporal creado aqui mismo para no
-- eliminar datos reales de la BD. La BD queda en el mismo estado que antes
-- de ejecutar el script.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ============================================================
PROMPT NT3-3 PRUEBA 1: Eliminacion exitosa — usuario temporal
PROMPT Crea un usuario de prueba completo (con perfil, pago,
PROMPT reproduccion, calificacion y favorito) y lo elimina.
PROMPT La BD queda en estado original al terminar.
PROMPT ============================================================
DECLARE
v_id_temp    NUMBER;
    v_id_perfil  NUMBER;
    v_id_cont    NUMBER;
    v_usu_pre    NUMBER;
    v_usu_post   NUMBER;
BEGIN
    -- Conteo antes de la prueba
SELECT COUNT(*) INTO v_usu_pre FROM USUARIOS;
DBMS_OUTPUT.PUT_LINE('Usuarios antes de la prueba: ' || v_usu_pre);

    -- Obtener un id_contenido existente para las FK de repro/calif/fav
SELECT id_contenido INTO v_id_cont FROM CONTENIDO WHERE ROWNUM = 1;

-- PASO A: Crear usuario temporal via SP_REGISTRAR_USUARIO
-- Esto crea usuario + perfil Principal + pago EXITOSO de forma atomica
SP_REGISTRAR_USUARIO(
        p_nombre          => 'Usuario',
        p_apellido        => 'Temporal NT3',
        p_email           => 'temporal.nt3@quindioflix.com',
        p_contrasena_hash => 'hash_temp_nt3',
        p_ciudad          => 'Armenia',
        p_id_plan         => 1,
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id_temp
    );
    DBMS_OUTPUT.PUT_LINE('Usuario temporal creado: id=' || v_id_temp);

    -- Obtener el perfil creado por el SP
SELECT id_perfil INTO v_id_perfil
FROM   PERFILES WHERE id_usuario = v_id_temp AND ROWNUM = 1;

-- PASO B: Agregar datos derivados para probar la cascada de borrado completa
-- Reproduccion
INSERT INTO REPRODUCCIONES (
    fecha_hora_inicio, fecha_hora_fin, dispositivo,
    porcentaje_avance, id_perfil, id_contenido, id_episodio
) VALUES (
             TIMESTAMP '2026-05-01 20:00:00',
             TIMESTAMP '2026-05-01 21:00:00',
             'TV', 100, v_id_perfil, v_id_cont, NULL
         );
COMMIT;

-- Calificacion (avance = 100% pasa el TRG_VALID_CALIFICACION)
INSERT INTO CALIFICACIONES (estrellas, resena, id_perfil, id_contenido)
VALUES (5, 'Prueba NT3-3', v_id_perfil, v_id_cont);
COMMIT;

-- Favorito
INSERT INTO FAVORITOS (fecha_agregado, id_perfil, id_contenido)
VALUES (SYSDATE, v_id_perfil, v_id_cont);
COMMIT;

DBMS_OUTPUT.PUT_LINE('Datos derivados creados (repro + calif + fav).');

    -- PASO C: Ejecutar SP_ELIMINAR_CUENTA — debe borrar todo en cascada
    SP_ELIMINAR_CUENTA(v_id_temp);

    -- PASO D: Verificar que no quedo nada
SELECT COUNT(*) INTO v_usu_post FROM USUARIOS;
DBMS_OUTPUT.PUT_LINE('Usuarios despues de la prueba: ' || v_usu_post);

    IF v_usu_post = v_usu_pre THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 1 OK: usuario eliminado, BD en estado original.');
ELSE
        DBMS_OUTPUT.PUT_LINE('PRUEBA 1 FALLO: conteo no coincide.');
END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR en prueba 1: ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================
PROMPT NT3-3 PRUEBA 2: Usuario inexistente — debe lanzar -20041
PROMPT ============================================================
BEGIN
    SP_ELIMINAR_CUENTA(99999);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('P2 OK — Excepcion esperada (-20041): ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================
PROMPT NT3-3 PRUEBA 3: Usuario con id_referidor hacia el — cascada FK reflexiva
PROMPT Crea dos usuarios temporales donde uno refirio al otro,
PROMPT elimina el referidor y verifica que el referido queda con
PROMPT id_referidor = NULL (no se elimina el referido).
PROMPT ============================================================
DECLARE
v_id_ref  NUMBER;  -- el que va a ser eliminado (referidor)
    v_id_ref2 NUMBER;  -- el referido (debe quedar intacto)
    v_referidor_post NUMBER;
BEGIN
    -- Crear referidor
    SP_REGISTRAR_USUARIO('Referidor','Temporal','referidor.nt3@quindioflix.com',
        'hash_ref','Pereira',1,'PSE',NULL,v_id_ref);

    -- Crear referido apuntando al referidor
    SP_REGISTRAR_USUARIO('Referido','Temporal','referido.nt3@quindioflix.com',
        'hash_ref2','Pereira',1,'PSE',v_id_ref,v_id_ref2);

    DBMS_OUTPUT.PUT_LINE('Referidor id=' || v_id_ref || ' | Referido id=' || v_id_ref2);

    -- Eliminar el referidor
    SP_ELIMINAR_CUENTA(v_id_ref);

    -- Verificar que el referido sigue existiendo con id_referidor = NULL
SELECT NVL(id_referidor, -1)
INTO   v_referidor_post
FROM   USUARIOS WHERE id_usuario = v_id_ref2;

IF v_referidor_post = -1 THEN
        DBMS_OUTPUT.PUT_LINE('P3 OK: referido existe y su id_referidor quedo NULL.');
ELSE
        DBMS_OUTPUT.PUT_LINE('P3 FALLO: id_referidor = ' || v_referidor_post);
END IF;

    -- Limpiar el referido
    SP_ELIMINAR_CUENTA(v_id_ref2);
    DBMS_OUTPUT.PUT_LINE('Usuarios temporales limpiados. BD en estado original.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR en prueba 3: ' || SQLERRM);
END;
/

-- =============================================================================
-- NT3_nucelo3_transacciones_NT3_4_concurrencia_select_for_update
-- =============================================================================

-- =============================================================================
-- NT3-4: Escenario de concurrencia — SELECT FOR UPDATE
-- Archivo : NT3_nucleo3_transacciones_NT3_4_CONCURRENCIA_SELECT_FOR_UPDATE.sql
-- Autor   : Daniel Narvaez
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- =============================================================================
-- Descripcion:
--   Demuestra como Oracle maneja la concurrencia cuando dos sesiones intentan
--   modificar el mismo registro simultaneamente. Se usa SELECT FOR UPDATE para
--   bloquear la fila antes de modificarla, garantizando que solo una sesion
--   pueda procesar el cambio de plan en un momento dado.
--
-- Escenario:
--   Dos sesiones abiertas en SQL Developer intentan cambiar el plan del
--   mismo usuario (id_usuario = 3, Valeria Lozano). La Sesion 1 bloquea
--   la fila primero. La Sesion 2 intenta bloquear la misma fila y queda
--   ESPERANDO hasta que la Sesion 1 haga COMMIT o ROLLBACK.
--
-- Mecanismo Oracle:
--   SELECT ... FOR UPDATE adquiere un Row-Level Lock (TX lock) sobre las
--   filas seleccionadas. Oracle usa MVCC (Multi-Version Concurrency Control)
--   para que los lectores no bloqueen a los escritores, pero dos escritores
--   sobre la misma fila si se bloquean entre si.
--
-- Por que SELECT FOR UPDATE y no UPDATE directo:
--   El UPDATE directo tambien bloquea, pero SELECT FOR UPDATE permite leer
--   los datos actuales ANTES de modificarlos dentro de la misma transaccion,
--   asegurando que la decision de cambio se basa en datos frescos y no en
--   datos leidos antes de que otra sesion los modificara.
--
-- Resolucion del bloqueo:
--   - Si Sesion 1 hace COMMIT  -> Sesion 2 se desbloquea y ve los datos ya
--     modificados por Sesion 1, puede proceder con su propio cambio.
--   - Si Sesion 1 hace ROLLBACK -> Sesion 2 se desbloquea y ve los datos
--     originales, como si Sesion 1 nunca hubiera actuado.
--   - Con NOWAIT: si la fila esta bloqueada, lanza ORA-00054 inmediatamente
--     en lugar de esperar.
--
-- Estados de transaccion documentados:
--   Sesion 1: ACTIVA -> bloqueo adquirido -> PARCIALMENTE CONFIRMADA -> CONFIRMADA
--   Sesion 2: ACTIVA -> BLOQUEADA (esperando) -> ACTIVA (al liberarse) -> CONFIRMADA
--
-- INSTRUCCIONES DE EJECUCION:
--   1. Abrir DOS ventanas de SQL Developer (o dos pestanas SQL Worksheet)
--      conectadas como QUINDIOFLIX.
--   2. Ejecutar los bloques de SESION 1 y SESION 2 en el orden indicado.
--   3. Tomar capturas de pantalla en cada paso para documentar el escenario.
--   4. NO ejecutar este script completo con F5 — ejecutar bloque por bloque
--      en las dos sesiones por separado.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PASO PREVIO: Verificar estado inicial del usuario de prueba
-- Ejecutar en CUALQUIERA de las dos sesiones antes de comenzar
-- =============================================================================

PROMPT ============================================================
PROMPT ESTADO INICIAL — ejecutar antes de comenzar el escenario
PROMPT ============================================================

SELECT u.id_usuario, u.nombre, u.apellido, u.email,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3;

-- Resultado esperado: Valeria Lozano, plan Basico (id_plan=1)
-- Si el plan es diferente, ajustar los scripts de sesion abajo.


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- SESION 1 — Ejecutar en la primera ventana de SQL Developer
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 1: Bloquear la fila con SELECT FOR UPDATE
-- TOMAR CAPTURA despues de ejecutar este bloque.
-- La sesion 1 tiene el lock. La sesion 2 aun no ha intentado nada.
-- Estado: ACTIVA con bloqueo adquirido
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 ==

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: ACTIVA');
    DBMS_OUTPUT.PUT_LINE('Adquiriendo bloqueo sobre usuario id=3...');
END;
/

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3
FOR UPDATE OF u.id_plan;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Lock adquirido sobre usuario id=3 (Valeria Lozano)');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: PARCIALMENTE CONFIRMADA (fila bloqueada)');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Ahora ejecutar SESION 2 PASO 1 y tomar captura del bloqueo');
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 2: Aplicar el cambio de plan (Basico -> Estandar)
-- Ejecutar DESPUES de que Sesion 2 este esperando (bloqueada).
-- TOMAR CAPTURA de Sesion 2 esperando ANTES de ejecutar esto.
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 (despues de ver que Sesion 2 espera) ==

DECLARE
    v_total_perfiles NUMBER;
    v_max_perfiles   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total_perfiles
    FROM   PERFILES WHERE id_usuario = 3;

    SELECT max_perfiles INTO v_max_perfiles
    FROM   PLANES WHERE id_plan = 2;  -- Estandar

    IF v_total_perfiles <= v_max_perfiles THEN
        UPDATE USUARIOS SET id_plan = 2 WHERE id_usuario = 3;
        DBMS_OUTPUT.PUT_LINE('SESION 1 — Plan actualizado: Basico -> Estandar');
        DBMS_OUTPUT.PUT_LINE('SESION 1 — Perfiles actuales: ' || v_total_perfiles ||
            ' / Max permitido: ' || v_max_perfiles);
    ELSE
        DBMS_OUTPUT.PUT_LINE('SESION 1 — FALLIDO: perfiles exceden limite del nuevo plan');
        ROLLBACK;
    END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 3: COMMIT — libera el bloqueo
-- TOMAR CAPTURA inmediatamente despues: Sesion 2 se desbloquea.
-- Estado Sesion 1: CONFIRMADA
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 ==

COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: CONFIRMADA — COMMIT ejecutado');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Bloqueo liberado. Sesion 2 puede continuar.');
END;
/
*/


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- SESION 2 — Ejecutar en la segunda ventana de SQL Developer
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 1: Intentar bloquear la misma fila
-- Ejecutar DESPUES de que Sesion 1 ya ejecuto su PASO 1.
-- TOMAR CAPTURA: Sesion 2 queda colgada esperando (spinning cursor).
-- Estado: BLOQUEADA — esperando que Sesion 1 libere
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 ==

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: ACTIVA');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Intentando bloquear usuario id=3...');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Si Sesion 1 tiene el lock, esta consulta ESPERARA');
END;
/

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3
FOR UPDATE OF u.id_plan;   -- BLOQUEADO si Sesion 1 tiene el lock

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: ACTIVA — bloqueo adquirido (Sesion 1 hizo COMMIT)');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actual del usuario (ya modificado por Sesion 1):');
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — VARIANTE CON NOWAIT (opcional — para demostrar ORA-00054)
-- En lugar de esperar indefinidamente, lanza error si la fila esta bloqueada.
-- Descomentar esta version y comentar la anterior para demostrar NOWAIT.
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 (variante NOWAIT) ==

DECLARE
    v_id     NUMBER;
    v_nombre VARCHAR2(100);
BEGIN
    SELECT u.id_usuario, u.nombre INTO v_id, v_nombre
    FROM   USUARIOS u
    WHERE  u.id_usuario = 3
    FOR UPDATE OF u.id_plan NOWAIT;

    DBMS_OUTPUT.PUT_LINE('SESION 2 — Lock adquirido con NOWAIT');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -54 THEN
            DBMS_OUTPUT.PUT_LINE('SESION 2 — ORA-00054: fila bloqueada por otra sesion');
            DBMS_OUTPUT.PUT_LINE('SESION 2 — NOWAIT: la sesion no espera, reporta el error');
        ELSE
            DBMS_OUTPUT.PUT_LINE('SESION 2 — Error: ' || SQLERRM);
        END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 2: Aplicar su propio cambio (Estandar -> Premium)
-- Ejecutar solo despues de que Sesion 1 hizo COMMIT y Sesion 2 se desbloqueo.
-- En este punto el usuario ya tiene plan Estandar (cambiado por Sesion 1).
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 (despues de desbloquearse) ==

DECLARE
    v_total_perfiles NUMBER;
    v_max_perfiles   NUMBER;
    v_plan_actual    VARCHAR2(30);
BEGIN
    SELECT pl.nombre INTO v_plan_actual
    FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
    WHERE  u.id_usuario = 3;

    DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actual (post-Sesion1): ' || v_plan_actual);

    SELECT COUNT(*) INTO v_total_perfiles FROM PERFILES WHERE id_usuario = 3;
    SELECT max_perfiles INTO v_max_perfiles FROM PLANES WHERE id_plan = 3;  -- Premium

    IF v_total_perfiles <= v_max_perfiles THEN
        UPDATE USUARIOS SET id_plan = 3 WHERE id_usuario = 3;
        DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actualizado: ' || v_plan_actual || ' -> Premium');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SESION 2 — FALLIDO: perfiles exceden limite Premium');
        ROLLBACK;
    END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 3: COMMIT
-- Estado Sesion 2: CONFIRMADA
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 ==

COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: CONFIRMADA');
END;
/
*/


-- =============================================================================
-- PASO FINAL: Verificar estado final del usuario
-- Ejecutar en cualquier sesion despues de que ambas hicieron COMMIT
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT ESTADO FINAL — verificar despues de ambas sesiones
PROMPT ============================================================

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_final, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3;

-- Resultado esperado: Valeria Lozano, plan Premium (si ambas sesiones tuvieron exito)

-- Restaurar plan original para no afectar otros scripts:
/*
UPDATE USUARIOS SET id_plan = 1 WHERE id_usuario = 3;
COMMIT;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Plan restaurado a Basico (estado original).');
END;
/
*/


-- =============================================================================
-- CONSULTA DE DIAGNOSTICO: Ver bloqueos activos en Oracle
-- Ejecutar como SYSTEM en una tercera ventana mientras el bloqueo esta activo
-- (entre Sesion 1 Paso 1 y Sesion 1 Paso 3) para documentar el lock.
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT DIAGNOSTICO DE BLOQUEOS — ejecutar como SYSTEM mientras
PROMPT Sesion 2 esta esperando (para captura de pantalla)
PROMPT ============================================================

/*
-- == EJECUTAR COMO SYSTEM ==
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.blocking_session,
    l.type         AS lock_type,
    l.lmode        AS lock_mode,    -- 6 = Exclusive (X)
    l.request      AS lock_request, -- 6 = esperando Exclusive
    l.block        AS is_blocking,  -- 1 = esta bloqueando a alguien
    o.object_name,
    o.object_type
FROM   v$session s
JOIN   v$lock    l ON l.sid = s.sid
LEFT   JOIN dba_objects o ON o.object_id = l.id1
WHERE  s.username = 'QUINDIOFLIX'
  AND  l.type IN ('TM', 'TX')
ORDER  BY s.sid;
*/


-- =============================================================================
-- RESUMEN DEL ESCENARIO DE CONCURRENCIA
-- =============================================================================
/*
  TIMELINE DEL ESCENARIO:
  ========================

  T1  Sesion 1: SELECT FOR UPDATE  -> adquiere lock sobre usuario id=3
  T2  Sesion 2: SELECT FOR UPDATE  -> BLOQUEADA, espera a Sesion 1
                (cursor girando en SQL Developer — tomar captura)
  T3  Sesion 1: UPDATE id_plan=2   -> modifica el plan a Estandar
  T4  Sesion 1: COMMIT             -> libera el lock
  T5  Sesion 2: desbloquea         -> ve plan=Estandar (ya modificado)
  T6  Sesion 2: UPDATE id_plan=3   -> modifica el plan a Premium
  T7  Sesion 2: COMMIT             -> confirma

  RESULTADO: serializable y correcto. Ninguna modificacion se pierde.
  El plan pasa de Basico -> Estandar (Sesion 1) -> Premium (Sesion 2).

  SIN SELECT FOR UPDATE (problema lost update sin lock):
  ======================================================
  T1  Sesion 1: lee plan=Basico
  T2  Sesion 2: lee plan=Basico
  T3  Sesion 1: UPDATE plan=Estandar, COMMIT
  T4  Sesion 2: UPDATE plan=Premium  (basado en lectura stale de Basico)
  T4  Sesion 2: COMMIT
  RESULTADO: ambos commits pasan pero Sesion 1 se pierde (lost update).
  Con SELECT FOR UPDATE Oracle previene este escenario.
*/