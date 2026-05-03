-- =============================================================================
-- NT2-10: TRG_VALID_CUENTA
-- Autor  : Daniel Narvaez
-- Tipo   : BEFORE INSERT — nivel de fila (FOR EACH ROW)
-- Tabla  : REPRODUCCIONES
--
-- Verifica que el usuario propietario del perfil que intenta reproducir
-- contenido tenga estado_cuenta = 'ACTIVO'. Si el estado es 'INACTIVO'
-- o 'SUSPENDIDO' rechaza el INSERT con RAISE_APPLICATION_ERROR(-20010).
--
-- Por que BEFORE INSERT:
--   Se ejecuta antes de que el nuevo registro entre a la tabla,
--   permitiendo rechazarlo limpiamente sin necesidad de ROLLBACK.
--   Si fuera AFTER INSERT el registro ya existiria y habria que borrarlo.
--
-- Navegacion de tablas:
--   REPRODUCCIONES.id_perfil -> PERFILES.id_usuario -> USUARIOS.estado_cuenta
--   El trigger recibe :NEW.id_perfil y debe buscar el usuario propietario
--   del perfil para verificar su estado de cuenta.
--
-- Relacion con NT2-11 (TRG_MAX_PERFILES de Diego):
--   Ambos son triggers BEFORE INSERT sobre tablas relacionadas con USUARIOS.
--   TRG_VALID_CUENTA verifica estado_cuenta en REPRODUCCIONES.
--   TRG_MAX_PERFILES verifica el limite de perfiles en PERFILES.
--
-- Codigos de error personalizados:
--   -20010 : cuenta INACTIVA — el usuario no pago su suscripcion
--   -20011 : cuenta SUSPENDIDA — la cuenta fue suspendida por la plataforma
--   -20012 : perfil no encontrado (NO_DATA_FOUND inesperado)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_VALID_CUENTA
BEFORE INSERT ON REPRODUCCIONES
FOR EACH ROW
DECLARE
v_estado_cuenta  USUARIOS.estado_cuenta%TYPE;
    v_nombre_usuario VARCHAR2(160);
    v_id_usuario     USUARIOS.id_usuario%TYPE;
BEGIN
    -- -------------------------------------------------------------------------
    -- Navegar PERFILES -> USUARIOS para obtener estado_cuenta
    -- :NEW.id_perfil es el perfil que intenta iniciar la reproduccion
    -- -------------------------------------------------------------------------
SELECT u.id_usuario,
       u.nombre || ' ' || u.apellido,
       u.estado_cuenta
INTO   v_id_usuario,
    v_nombre_usuario,
    v_estado_cuenta
FROM   PERFILES pe
           JOIN   USUARIOS u ON u.id_usuario = pe.id_usuario
WHERE  pe.id_perfil = :NEW.id_perfil;

-- -------------------------------------------------------------------------
-- Verificar estado de cuenta
-- Solo 'ACTIVO' permite reproducir contenido
-- -------------------------------------------------------------------------
IF v_estado_cuenta = 'INACTIVO' THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'TRG_VALID_CUENTA: No se puede iniciar la reproduccion. ' ||
            'La cuenta del usuario "' || v_nombre_usuario ||
            '" (id=' || v_id_usuario || ') esta INACTIVA. ' ||
            'Realice el pago de su suscripcion para reactivar el acceso.'
        );

    ELSIF v_estado_cuenta = 'SUSPENDIDO' THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'TRG_VALID_CUENTA: No se puede iniciar la reproduccion. ' ||
            'La cuenta del usuario "' || v_nombre_usuario ||
            '" (id=' || v_id_usuario || ') esta SUSPENDIDA. ' ||
            'Contacte a soporte de QuindioFlix para resolver la suspension.'
        );
END IF;

    -- Si estado_cuenta = 'ACTIVO' el trigger no hace nada y permite el INSERT

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'TRG_VALID_CUENTA: No se encontro el perfil con id=' ||
            :NEW.id_perfil || ' o el perfil no tiene usuario asignado.'
        );
END TRG_VALID_CUENTA;
/


-- =============================================================================
-- Verificar que el trigger compilo correctamente
-- =============================================================================
SELECT object_name, object_type, status, last_ddl_time
FROM   user_objects
WHERE  object_name = 'TRG_VALID_CUENTA';


-- =============================================================================
-- CASOS DE PRUEBA
-- Ejecutar con SET SERVEROUTPUT ON en SQL Developer
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- -----------------------------------------------------------------------------
-- Datos de referencia para las pruebas
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT DATOS DE REFERENCIA: perfiles por estado de cuenta
PROMPT ============================================================

SELECT
    pe.id_perfil,
    pe.nombre                       AS nombre_perfil,
    u.id_usuario,
    u.nombre || ' ' || u.apellido   AS usuario,
    u.estado_cuenta,
    pl.nombre                       AS plan
FROM PERFILES pe
         JOIN USUARIOS u  ON u.id_usuario = pe.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
ORDER BY u.estado_cuenta, pe.id_perfil;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: INSERT exitoso — perfil de usuario ACTIVO
-- Usuario 3 (Valeria Lozano, ACTIVO)
-- La reproduccion debe insertarse sin error — se revierte al final
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 1: INSERT exitoso (usuario ACTIVO)
PROMPT ============================================================

BEGIN
INSERT INTO REPRODUCCIONES (
    fecha_hora_inicio, fecha_hora_fin, dispositivo,
    porcentaje_avance, id_perfil, id_contenido, id_episodio
)
SELECT
    TIMESTAMP '2026-05-01 20:00:00',
    TIMESTAMP '2026-05-01 21:30:00',
    'TV',
    100,
    pe.id_perfil,
    1,
    NULL
FROM PERFILES pe
         JOIN USUARIOS u ON u.id_usuario = pe.id_usuario
WHERE u.id_usuario = 3
  AND ROWNUM = 1;

DBMS_OUTPUT.PUT_LINE('PRUEBA 1 OK: Reproduccion insertada para usuario ACTIVO.');
ROLLBACK;
DBMS_OUTPUT.PUT_LINE('PRUEBA 1: Revertida con ROLLBACK.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('PRUEBA 1 ERROR inesperado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: INSERT bloqueado — perfil de usuario INACTIVO
-- Usuario 14 (Cristian Salazar, INACTIVO)
-- Debe lanzar TRG_VALID_CUENTA error -20010
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 2: INSERT bloqueado (usuario INACTIVO — error -20010)
PROMPT ============================================================

BEGIN
INSERT INTO REPRODUCCIONES (
    fecha_hora_inicio, fecha_hora_fin, dispositivo,
    porcentaje_avance, id_perfil, id_contenido, id_episodio
)
SELECT
    TIMESTAMP '2026-05-01 20:00:00',
    NULL,
    'CELULAR',
    0,
    pe.id_perfil,
    1,
    NULL
FROM PERFILES pe
         JOIN USUARIOS u ON u.id_usuario = pe.id_usuario
WHERE u.id_usuario = 14
  AND ROWNUM = 1;

DBMS_OUTPUT.PUT_LINE('PRUEBA 2 ERROR: El INSERT debio ser bloqueado.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 2 OK — Error capturado correctamente:');
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: INSERT bloqueado — perfil de usuario SUSPENDIDO
-- Usuario 30 (Samuel Ocampo, SUSPENDIDO)
-- Debe lanzar TRG_VALID_CUENTA error -20011
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 3: INSERT bloqueado (usuario SUSPENDIDO — error -20011)
PROMPT ============================================================

BEGIN
INSERT INTO REPRODUCCIONES (
    fecha_hora_inicio, fecha_hora_fin, dispositivo,
    porcentaje_avance, id_perfil, id_contenido, id_episodio
)
SELECT
    TIMESTAMP '2026-05-01 20:00:00',
    NULL,
    'TABLET',
    0,
    pe.id_perfil,
    1,
    NULL
FROM PERFILES pe
         JOIN USUARIOS u ON u.id_usuario = pe.id_usuario
WHERE u.id_usuario = 30
  AND ROWNUM = 1;

DBMS_OUTPUT.PUT_LINE('PRUEBA 3 ERROR: El INSERT debio ser bloqueado.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 3 OK — Error capturado correctamente:');
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- VERIFICACION FINAL: total reproducciones debe seguir siendo 320
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT VERIFICACION FINAL: total reproducciones (debe ser 320)
PROMPT ============================================================

SELECT COUNT(*) AS total_reproducciones FROM REPRODUCCIONES;


-- =============================================================================
-- MAPA DE CODIGOS DE ERROR DE ESTE TRIGGER:
--
--   -20010  cuenta INACTIVA   : el usuario no ha pagado su suscripcion
--   -20011  cuenta SUSPENDIDA : la cuenta fue suspendida por la plataforma
--   -20012  perfil no hallado : NO_DATA_FOUND inesperado en la navegacion
--
-- Nota: estos codigos estan coordinados con los del SP_CAMBIAR_PLAN (NT2-4)
--   y los demas triggers del NT2 para evitar colisiones en el rango -20000.
--   Ver mapa completo de codigos en el documento de sustentacion (NT5-6).
-- =============================================================================