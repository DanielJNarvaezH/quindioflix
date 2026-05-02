-- =============================================================================
-- NT2-11: TRG_MAX_PERFILES
-- Autor  : Diego Garcia
-- Tipo   : BEFORE INSERT — nivel de fila (FOR EACH ROW)
-- Tabla  : PERFILES
--
-- Verifica que el usuario no supere el maximo de perfiles permitido
-- segun su plan de suscripcion antes de insertar un nuevo perfil:
--   Basico   : max 2 perfiles
--   Estandar : max 3 perfiles
--   Premium  : max 5 perfiles
--
-- Si el usuario ya tiene tantos perfiles como permite su plan,
-- rechaza el INSERT con RAISE_APPLICATION_ERROR(-20021).
--
-- Por que BEFORE INSERT:
--   Se ejecuta antes de que el nuevo registro entre a la tabla,
--   permitiendo rechazarlo limpiamente sin necesidad de ROLLBACK.
--   Si fuera AFTER INSERT ya existiria el registro y habria que borrarlo.
--
-- Relacion con NT2-9 (TRG_VALID_CUENTA de Daniel):
--   Ambos son triggers BEFORE INSERT en tablas relacionadas con USUARIOS.
--   TRG_VALID_CUENTA verifica estado_cuenta en REPRODUCCIONES.
--   TRG_MAX_PERFILES verifica el limite de plan en PERFILES.
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_MAX_PERFILES
BEFORE INSERT ON PERFILES
FOR EACH ROW
DECLARE
v_max_perfiles      NUMBER(1);
    v_perfiles_actuales NUMBER(3);
    v_nombre_plan       VARCHAR2(30);
BEGIN
    -- Obtener el maximo de perfiles y nombre del plan del usuario
SELECT pl.max_perfiles, pl.nombre
INTO v_max_perfiles, v_nombre_plan
FROM USUARIOS u
         JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE u.id_usuario = :NEW.id_usuario;

-- Contar perfiles actuales del usuario
SELECT COUNT(*)
INTO v_perfiles_actuales
FROM PERFILES
WHERE id_usuario = :NEW.id_usuario;

-- Verificar si ya alcanzo el limite
IF v_perfiles_actuales >= v_max_perfiles THEN
        RAISE_APPLICATION_ERROR(
            -20021,
            'TRG_MAX_PERFILES: El usuario ID ' || :NEW.id_usuario ||
            ' ya tiene ' || v_perfiles_actuales || ' perfil(es) y su plan ' ||
            v_nombre_plan || ' permite un maximo de ' || v_max_perfiles || '.' ||
            ' Cambie a un plan superior para agregar mas perfiles.'
        );
END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20022,
            'TRG_MAX_PERFILES: No se encontro el usuario ID ' ||
            :NEW.id_usuario || ' o no tiene plan asignado.'
        );
END TRG_MAX_PERFILES;
/

-- =============================================================================
-- Casos de prueba
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Verificar limites actuales de los usuarios de prueba
SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido   AS usuario,
    pl.nombre                       AS plan,
    pl.max_perfiles                 AS maximo,
    COUNT(p.id_perfil)              AS perfiles_actuales,
    pl.max_perfiles - COUNT(p.id_perfil) AS disponibles
FROM USUARIOS u
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
         LEFT JOIN PERFILES p  ON p.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nombre, u.apellido, pl.nombre, pl.max_perfiles
ORDER BY u.id_usuario;

-- ----------------------------------------------------------------------------
-- PRUEBA 1: Insertar perfil en usuario que tiene espacio disponible
-- Usuario 1 (Sofia Perea) tiene plan Basico (max 2) y actualmente 2 perfiles
-- Primero verificamos cuantos tiene realmente
-- ----------------------------------------------------------------------------
SELECT id_perfil, nombre, tipo_perfil
FROM PERFILES
WHERE id_usuario = 1;

-- ----------------------------------------------------------------------------
-- PRUEBA 2: Insertar perfil que excede el limite — debe lanzar ORA-20021
-- Usuario 1 tiene plan Basico (max 2) y ya tiene 2 perfiles
-- ----------------------------------------------------------------------------
BEGIN
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Perfil Extra', 'ADULTO', 1);
DBMS_OUTPUT.PUT_LINE('INSERCION EXITOSA — no debia pasar esto');
ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Capturado correctamente: ' || SQLERRM);
ROLLBACK;
END;
/

-- ----------------------------------------------------------------------------
-- PRUEBA 3: Insertar perfil en usuario con plan Premium (max 5)
-- Buscar un usuario Premium que tenga menos de 5 perfiles
-- ----------------------------------------------------------------------------
DECLARE
v_id_usuario NUMBER;
    v_perfiles   NUMBER;
BEGIN
SELECT id_usuario, perfiles_actuales
INTO v_id_usuario, v_perfiles
FROM (
         SELECT
             u.id_usuario,
             COUNT(p.id_perfil)  AS perfiles_actuales,
             pl.max_perfiles
         FROM USUARIOS u
                  JOIN PLANES    pl ON pl.id_plan   = u.id_plan
                  LEFT JOIN PERFILES p  ON p.id_usuario = u.id_usuario
         WHERE pl.nombre = 'Premium'
         GROUP BY u.id_usuario, pl.max_perfiles
         HAVING COUNT(p.id_perfil) < pl.max_perfiles
     )
WHERE ROWNUM = 1;

INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Perfil Test Premium', 'ADULTO', v_id_usuario);

DBMS_OUTPUT.PUT_LINE('Perfil insertado correctamente para usuario Premium ID: '
        || v_id_usuario || ' (tenia ' || v_perfiles || ' perfiles)');
ROLLBACK;
DBMS_OUTPUT.PUT_LINE('Insertado revertido — BD en estado original.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
ROLLBACK;
END;
/

-- ----------------------------------------------------------------------------
-- PRUEBA 4: Usuario inexistente — debe lanzar ORA-20022
-- ----------------------------------------------------------------------------
BEGIN
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Perfil Fantasma', 'ADULTO', 9999);
ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Capturado correctamente: ' || SQLERRM);
ROLLBACK;
END;
/