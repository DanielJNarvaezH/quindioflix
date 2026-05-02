-- =============================================================================
-- NT2-12: TRG_VALID_CALIFICACION
-- Script  : NT2_nucleo2_plsql_NT2_12_TRG_VALID_CALIFICACION.sql
-- Autor   : Cristhian Osorio
-- Tarea   : NT2-12 del cronograma QuindioFlix — Sprint 3
--
-- DESCRIPCION:
--   Trigger BEFORE INSERT a nivel de fila sobre la tabla CALIFICACIONES.
--   Verifica que el perfil haya reproducido al menos el 50% del contenido
--   que intenta calificar. Si no cumple, rechaza la insercion con un
--   mensaje descriptivo usando RAISE_APPLICATION_ERROR.
--
-- TABLA AFECTADA:
--   CALIFICACIONES — dispara antes de cada INSERT
--
-- LOGICA:
--   1. Buscar el maximo porcentaje_avance registrado en REPRODUCCIONES
--      para el par (:NEW.id_perfil, :NEW.id_contenido).
--   2. Si no existe ninguna reproduccion (MAX = NULL) → rechazar.
--   3. Si el maximo porcentaje_avance < 50 → rechazar.
--   4. Si el maximo >= 50 → permitir el INSERT.
--
-- EXCEPCION:
--   Codigo -20031 elegido para no colisionar con otros objetos PL/SQL:
--     SP_CAMBIAR_PLAN      : -20001 a -20004
--     SP_REGISTRAR_USUARIO : -20011, -20012
--     FN_CALCULAR_MONTO    : -20021
--
-- EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   Activar SET SERVEROUTPUT ON antes de los bloques de prueba.
-- =============================================================================


-- =============================================================================
-- CREACION DEL TRIGGER
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_VALID_CALIFICACION
BEFORE INSERT ON CALIFICACIONES
FOR EACH ROW
DECLARE
    v_max_avance NUMBER(5,2);
BEGIN

    -- =========================================================================
    -- Buscar el mayor porcentaje_avance del perfil sobre ese contenido.
    -- MAX devuelve NULL si no existe ninguna fila que coincida.
    -- =========================================================================
    SELECT MAX(porcentaje_avance)
    INTO   v_max_avance
    FROM   REPRODUCCIONES
    WHERE  id_perfil    = :NEW.id_perfil
    AND    id_contenido = :NEW.id_contenido;

    -- =========================================================================
    -- Validar: se requiere al menos 50% de avance en alguna reproduccion
    -- =========================================================================
    IF v_max_avance IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20031,
            'TRG_VALID_CALIFICACION: El perfil ' || :NEW.id_perfil
            || ' nunca ha reproducido el contenido ' || :NEW.id_contenido
            || '. Debe ver al menos el 50% antes de calificar.'
        );
    END IF;

    IF v_max_avance < 50 THEN
        RAISE_APPLICATION_ERROR(
            -20031,
            'TRG_VALID_CALIFICACION: El perfil ' || :NEW.id_perfil
            || ' solo ha visto el ' || v_max_avance || '% del contenido '
            || :NEW.id_contenido || '. Se requiere minimo 50% para calificar.'
        );
    END IF;

    -- Si llega aqui, la validacion paso — el INSERT procede normalmente.

END TRG_VALID_CALIFICACION;
/


-- =============================================================================
-- BLOQUES DE PRUEBA
-- Activar SERVEROUTPUT primero. Ejecutar cada bloque por separado.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- -----------------------------------------------------------------------------
-- PRUEBA 1: INSERT EXITOSO — perfil con reproduccion >= 50%
-- Busca dinamicamente un par (perfil, contenido) donde MAX avance >= 50%
-- y que NO tenga calificacion previa (por el UNIQUE constraint).
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 1: Insert exitoso (avance >= 50%)
PROMPT ============================================================
DECLARE
    v_id_perfil    NUMBER;
    v_id_contenido NUMBER;
    v_avance       NUMBER;
BEGIN
    -- Buscar par valido: avance maximo >= 50 y sin calificacion previa
    SELECT id_perfil, id_contenido, max_avance
    INTO   v_id_perfil, v_id_contenido, v_avance
    FROM (
        SELECT
            r.id_perfil,
            r.id_contenido,
            MAX(r.porcentaje_avance) AS max_avance
        FROM  REPRODUCCIONES r
        WHERE NOT EXISTS (
            SELECT 1 FROM CALIFICACIONES c
            WHERE  c.id_perfil    = r.id_perfil
            AND    c.id_contenido = r.id_contenido
        )
        GROUP BY r.id_perfil, r.id_contenido
        HAVING MAX(r.porcentaje_avance) >= 50
        ORDER BY MAX(r.porcentaje_avance) DESC
    )
    WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Par elegido: perfil=' || v_id_perfil
                         || ', contenido=' || v_id_contenido
                         || ', avance=' || v_avance || '%');

    -- Intentar la calificacion — el trigger debe permitirla
    INSERT INTO CALIFICACIONES (estrellas, resena, id_perfil, id_contenido)
    VALUES (5, 'Excelente — prueba NT2-12', v_id_perfil, v_id_contenido);

    DBMS_OUTPUT.PUT_LINE('INSERT aceptado correctamente por el trigger.');

    -- Revertir para no acumular datos de prueba
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Prueba 1 revertida — BD en estado original.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: No se encontro un par valido con avance >= 50% sin calificacion previa.');
        DBMS_OUTPUT.PUT_LINE('Revisa los datos de REPRODUCCIONES.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inesperado: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 2: INSERT RECHAZADO — perfil que nunca reprodujo el contenido
-- Busca un par (perfil, contenido) sin ninguna fila en REPRODUCCIONES.
-- El trigger debe lanzar -20031 con mensaje "nunca ha reproducido".
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 2: Insert rechazado (sin ninguna reproduccion)
PROMPT ============================================================
DECLARE
    v_id_perfil    NUMBER;
    v_id_contenido NUMBER;
BEGIN
    -- Buscar perfil y contenido que no tengan ninguna reproduccion juntos
    SELECT p.id_perfil, c.id_contenido
    INTO   v_id_perfil, v_id_contenido
    FROM   PERFILES    p
    CROSS  JOIN CONTENIDO c
    WHERE  NOT EXISTS (
        SELECT 1 FROM REPRODUCCIONES r
        WHERE  r.id_perfil    = p.id_perfil
        AND    r.id_contenido = c.id_contenido
    )
    AND    NOT EXISTS (
        SELECT 1 FROM CALIFICACIONES ca
        WHERE  ca.id_perfil    = p.id_perfil
        AND    ca.id_contenido = c.id_contenido
    )
    AND    ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Par elegido: perfil=' || v_id_perfil
                         || ', contenido=' || v_id_contenido
                         || ' (sin reproducciones)');

    INSERT INTO CALIFICACIONES (estrellas, id_perfil, id_contenido)
    VALUES (4, v_id_perfil, v_id_contenido);

    DBMS_OUTPUT.PUT_LINE('ERROR: El trigger debio rechazar este INSERT.');
    ROLLBACK;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR capturado correctamente: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- PRUEBA 3: INSERT RECHAZADO — perfil que solo vio menos del 50%
-- Busca par con MAX avance < 50 y sin calificacion previa.
-- El trigger debe lanzar -20031 con el porcentaje real.
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT PRUEBA 3: Insert rechazado (avance insuficiente, menor al 50%)
PROMPT ============================================================
DECLARE
    v_id_perfil    NUMBER;
    v_id_contenido NUMBER;
    v_avance       NUMBER;
BEGIN
    SELECT id_perfil, id_contenido, max_avance
    INTO   v_id_perfil, v_id_contenido, v_avance
    FROM (
        SELECT
            r.id_perfil,
            r.id_contenido,
            MAX(r.porcentaje_avance) AS max_avance
        FROM  REPRODUCCIONES r
        WHERE NOT EXISTS (
            SELECT 1 FROM CALIFICACIONES c
            WHERE  c.id_perfil    = r.id_perfil
            AND    c.id_contenido = r.id_contenido
        )
        GROUP BY r.id_perfil, r.id_contenido
        HAVING MAX(r.porcentaje_avance) < 50
        ORDER BY MAX(r.porcentaje_avance) DESC
    )
    WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Par elegido: perfil=' || v_id_perfil
                         || ', contenido=' || v_id_contenido
                         || ', avance=' || v_avance || '% (insuficiente)');

    INSERT INTO CALIFICACIONES (estrellas, id_perfil, id_contenido)
    VALUES (3, v_id_perfil, v_id_contenido);

    DBMS_OUTPUT.PUT_LINE('ERROR: El trigger debio rechazar este INSERT.');
    ROLLBACK;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: Todos los pares con reproduccion tienen avance >= 50%.');
        DBMS_OUTPUT.PUT_LINE('El trigger solo puede demostrarse con el caso NULL (prueba 2).');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR capturado correctamente: ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- VERIFICACION: Estado del trigger y calificaciones existentes
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT VERIFICACION: Estado del trigger en el diccionario de datos
PROMPT ============================================================

SELECT trigger_name, status, trigger_type, triggering_event
FROM   user_triggers
WHERE  trigger_name = 'TRG_VALID_CALIFICACION';

PROMPT ============================================================
PROMPT VERIFICACION: Calificaciones registradas con avance del perfil
PROMPT ============================================================

SELECT
    ca.id_calificacion,
    ca.id_perfil,
    ca.id_contenido,
    ca.estrellas,
    MAX(r.porcentaje_avance) AS avance_maximo_pct
FROM  CALIFICACIONES ca
JOIN  REPRODUCCIONES r
   ON r.id_perfil    = ca.id_perfil
  AND r.id_contenido = ca.id_contenido
GROUP BY
    ca.id_calificacion,
    ca.id_perfil,
    ca.id_contenido,
    ca.estrellas
ORDER BY ca.id_calificacion;
