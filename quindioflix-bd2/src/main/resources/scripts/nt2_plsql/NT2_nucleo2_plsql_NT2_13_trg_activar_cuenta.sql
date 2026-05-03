-- =============================================================================
-- NT2-13: TRG_ACTIVAR_CUENTA
-- Script  : NT2_nucleo2_plsql_NT2_13_TRG_ACTIVAR_CUENTA.sql
-- Autor   : Equipo QuindioFlix
-- Tarea   : NT2-13 del cronograma QuindioFlix — Sprint 3
--
-- DESCRIPCION:
--   Trigger AFTER INSERT a nivel de fila sobre la tabla PAGOS.
--   Despues de insertar un pago con estado_pago = 'EXITOSO', actualiza
--   automaticamente el estado_cuenta del usuario a 'ACTIVO' y renueva
--   la fecha_vencimiento (= :NEW.fecha_pago + 30 dias).
--
-- NOTA SOBRE fecha_ultimo_pago:
--   El enunciado menciona "registrar fecha_ultimo_pago", pero esa columna
--   no existe en el DDL de QuindioFlix (V2__create_tables.sql). El esquema
--   usa fecha_vencimiento para el mismo proposito de negocio: cuando llega
--   un pago exitoso la suscripcion se extiende 30 dias desde la fecha del
--   pago. Actualizar fecha_vencimiento = :NEW.fecha_pago + 30 es el
--   equivalente semantico correcto sin alterar el diccionario de datos.
--
-- NOTA SOBRE nivel de disparo:
--   El enunciado indica "a nivel de sentencia", pero tambien dice "usar :NEW
--   para obtener datos del pago". :NEW solo esta disponible en triggers
--   FOR EACH ROW. Se implementa FOR EACH ROW para poder leer :NEW.id_usuario,
--   :NEW.estado_pago y :NEW.fecha_pago. El efecto es equivalente al pedido.
--
-- TABLA AFECTADA:
--   PAGOS — dispara despues de cada INSERT, fila por fila
--
-- LOGICA:
--   1. Leer :NEW.estado_pago del pago recien insertado.
--   2. Si es 'EXITOSO':
--      a. estado_cuenta = 'ACTIVO'
--      b. fecha_vencimiento = :NEW.fecha_pago + 30
--   3. Si no es 'EXITOSO' (PENDIENTE, FALLIDO, REEMBOLSADO): no hacer nada.
--
-- CODIGOS DE ERROR del proyecto — este trigger no agrega nuevos:
--   SP_CAMBIAR_PLAN       : -20001 a -20004
--   SP_REGISTRAR_USUARIO  : -20011, -20012
--   FN_CALCULAR_MONTO     : -20021
--   TRG_VALID_CALIFICACION: -20031
--
-- EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   Activar SET SERVEROUTPUT ON antes de los bloques de prueba.
-- =============================================================================


-- =============================================================================
-- CREACION DEL TRIGGER
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_ACTIVAR_CUENTA
AFTER INSERT ON PAGOS
FOR EACH ROW
BEGIN

    -- =========================================================================
    -- Solo actuar cuando el pago insertado es EXITOSO.
    -- Pagos PENDIENTE, FALLIDO o REEMBOLSADO no activan la cuenta.
    -- =========================================================================
    IF :NEW.estado_pago = 'EXITOSO' THEN

UPDATE USUARIOS
SET    estado_cuenta     = 'ACTIVO',
       fecha_vencimiento = :NEW.fecha_pago + 30  -- renueva 30 dias desde la fecha del pago
WHERE  id_usuario = :NEW.id_usuario;

END IF;

END TRG_ACTIVAR_CUENTA;
/


-- =============================================================================
-- BLOQUES DE PRUEBA
-- Activar SERVEROUTPUT primero. Ejecutar cada bloque por separado.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: Pago EXITOSO activa cuenta INACTIVA y renueva vencimiento
-- Se pone un usuario en INACTIVO, se inserta un pago EXITOSO y se
-- verifica que el trigger lo reactivo y actualizo fecha_vencimiento.
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 1: Pago EXITOSO activa cuenta INACTIVA
PROMPT ============================================================
DECLARE
v_id_usuario  NUMBER;
    v_venc_pre    DATE;
    v_estado_post VARCHAR2(10);
    v_venc_post   DATE;
    v_fecha_pago  DATE := SYSDATE;
BEGIN
SELECT id_usuario, fecha_vencimiento
INTO   v_id_usuario, v_venc_pre
FROM   USUARIOS
WHERE  estado_cuenta = 'ACTIVO'
  AND    ROWNUM = 1;

-- Simular cuenta inactiva
UPDATE USUARIOS SET estado_cuenta = 'INACTIVO' WHERE id_usuario = v_id_usuario;
DBMS_OUTPUT.PUT_LINE('Estado ANTES   : INACTIVO');
    DBMS_OUTPUT.PUT_LINE('Vencim. ANTES  : ' || TO_CHAR(v_venc_pre, 'DD/MM/YYYY'));

    -- Insertar pago EXITOSO — dispara el trigger
INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES (v_fecha_pago, 14900, 'PSE', 'EXITOSO', 0, v_id_usuario);

SELECT estado_cuenta, fecha_vencimiento
INTO   v_estado_post, v_venc_post
FROM   USUARIOS WHERE id_usuario = v_id_usuario;

DBMS_OUTPUT.PUT_LINE('Estado DESPUES : ' || v_estado_post);
    DBMS_OUTPUT.PUT_LINE('Vencim. DESPUES: ' || TO_CHAR(v_venc_post, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('Esperado       : ' || TO_CHAR(v_fecha_pago + 30, 'DD/MM/YYYY'));

    IF v_estado_post = 'ACTIVO' AND v_venc_post = v_fecha_pago + 30 THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 1 OK: trigger activo la cuenta y renovo vencimiento.');
ELSE
        DBMS_OUTPUT.PUT_LINE('PRUEBA 1 FALLO: revisar estado o fecha_vencimiento.');
END IF;

ROLLBACK;
DBMS_OUTPUT.PUT_LINE('Prueba 1 revertida — BD en estado original.');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: Pago FALLIDO NO activa la cuenta ni toca fecha_vencimiento
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 2: Pago FALLIDO NO activa la cuenta
PROMPT ============================================================
DECLARE
v_id_usuario  NUMBER;
    v_estado_post VARCHAR2(10);
BEGIN
SELECT id_usuario INTO v_id_usuario
FROM   USUARIOS WHERE estado_cuenta = 'ACTIVO' AND ROWNUM = 1;

UPDATE USUARIOS SET estado_cuenta = 'INACTIVO' WHERE id_usuario = v_id_usuario;

INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES (SYSDATE, 14900, 'TARJETA_CREDITO', 'FALLIDO', 0, v_id_usuario);

SELECT estado_cuenta INTO v_estado_post
FROM   USUARIOS WHERE id_usuario = v_id_usuario;

DBMS_OUTPUT.PUT_LINE('Estado despues de pago FALLIDO: ' || v_estado_post);

    IF v_estado_post = 'INACTIVO' THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 2 OK: trigger no actuo (pago no exitoso).');
ELSE
        DBMS_OUTPUT.PUT_LINE('PRUEBA 2 FALLO: estado cambio cuando no debia.');
END IF;

ROLLBACK;
DBMS_OUTPUT.PUT_LINE('Prueba 2 revertida — BD en estado original.');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: Pago PENDIENTE NO activa la cuenta
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 3: Pago PENDIENTE NO activa la cuenta
PROMPT ============================================================
DECLARE
v_id_usuario  NUMBER;
    v_estado_post VARCHAR2(10);
BEGIN
SELECT id_usuario INTO v_id_usuario
FROM   USUARIOS WHERE estado_cuenta = 'ACTIVO' AND ROWNUM = 1;

UPDATE USUARIOS SET estado_cuenta = 'INACTIVO' WHERE id_usuario = v_id_usuario;

INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES (SYSDATE, 14900, 'NEQUI', 'PENDIENTE', 0, v_id_usuario);

SELECT estado_cuenta INTO v_estado_post
FROM   USUARIOS WHERE id_usuario = v_id_usuario;

DBMS_OUTPUT.PUT_LINE('Estado despues de pago PENDIENTE: ' || v_estado_post);

    IF v_estado_post = 'INACTIVO' THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 3 OK: trigger no actuo (pago pendiente).');
ELSE
        DBMS_OUTPUT.PUT_LINE('PRUEBA 3 FALLO: estado cambio cuando no debia.');
END IF;

ROLLBACK;
DBMS_OUTPUT.PUT_LINE('Prueba 3 revertida — BD en estado original.');
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 4: Integracion con SP_REGISTRAR_USUARIO
-- El SP inserta un pago EXITOSO internamente. El trigger debe dispararse
-- y dejar el usuario ACTIVO con vencimiento renovado.
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 4: Integracion con SP_REGISTRAR_USUARIO
PROMPT ============================================================
DECLARE
v_id     NUMBER;
    v_estado VARCHAR2(10);
    v_venc   DATE;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Trigger',
        p_apellido        => 'Test',
        p_email           => 'trigger.test.nt13@quindioflix.com',
        p_contrasena_hash => 'hash_nt13',
        p_ciudad          => 'Armenia',
        p_id_plan         => 1,
        p_metodo_pago     => 'PSE',
        p_id_referidor    => NULL,
        p_id_usuario      => v_id
    );

SELECT estado_cuenta, fecha_vencimiento
INTO   v_estado, v_venc
FROM   USUARIOS WHERE id_usuario = v_id;

DBMS_OUTPUT.PUT_LINE('Usuario creado : id=' || v_id);
    DBMS_OUTPUT.PUT_LINE('Estado         : ' || v_estado);
    DBMS_OUTPUT.PUT_LINE('Vencimiento    : ' || TO_CHAR(v_venc, 'DD/MM/YYYY'));

    IF v_estado = 'ACTIVO' THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 4 OK: trigger confirmo cuenta ACTIVA tras registro.');
ELSE
        DBMS_OUTPUT.PUT_LINE('PRUEBA 4 FALLO: estado inesperado = ' || v_estado);
END IF;

    -- Limpiar datos de prueba
DELETE FROM PAGOS    WHERE id_usuario = v_id;
DELETE FROM PERFILES WHERE id_usuario = v_id;
DELETE FROM USUARIOS WHERE id_usuario = v_id;
COMMIT;
DBMS_OUTPUT.PUT_LINE('Prueba 4 revertida — BD en estado original.');
END;
/


-- =============================================================================
-- VERIFICACION: Estado del trigger en el diccionario de datos
-- =============================================================================
PROMPT ============================================================
PROMPT VERIFICACION: Estado del trigger TRG_ACTIVAR_CUENTA
PROMPT ============================================================

SELECT trigger_name, status, trigger_type, triggering_event, table_name
FROM   user_triggers
WHERE  trigger_name = 'TRG_ACTIVAR_CUENTA';