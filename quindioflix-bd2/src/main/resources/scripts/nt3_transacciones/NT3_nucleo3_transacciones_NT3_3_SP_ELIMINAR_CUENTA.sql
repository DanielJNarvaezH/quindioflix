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