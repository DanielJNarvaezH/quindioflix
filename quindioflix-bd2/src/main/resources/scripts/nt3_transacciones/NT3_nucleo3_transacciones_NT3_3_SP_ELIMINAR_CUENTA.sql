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
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT3-3 PRUEBA 1: Eliminacion exitosa — usuario existente
PROMPT ============================================================
-- sebastian.roa esta vencido desde 2025 (moroso) y no tiene referencias
-- criticas para los scripts de otros integrantes del equipo.
DECLARE
    v_id NUMBER;
BEGIN
    SELECT id_usuario INTO v_id
    FROM   USUARIOS
    WHERE  email = 'sebastian.roa@quindioflix.com';

    DBMS_OUTPUT.PUT_LINE('Eliminando usuario id=' || v_id);
    SP_ELIMINAR_CUENTA(v_id);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: usuario de prueba ya no existe en la BD.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR inesperado: ' || SQLERRM);
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
        DBMS_OUTPUT.PUT_LINE('Excepcion esperada (-20041): ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================
PROMPT NT3-3 PRUEBA 3: Verificar que el usuario fue eliminado
PROMPT ============================================================
DECLARE
    v_usu NUMBER;
    v_per NUMBER;
    v_pag NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_usu FROM USUARIOS
    WHERE  email = 'sebastian.roa@quindioflix.com';

    SELECT COUNT(*) INTO v_per FROM PERFILES p
    JOIN   USUARIOS u ON u.id_usuario = p.id_usuario
    WHERE  u.email = 'sebastian.roa@quindioflix.com';

    SELECT COUNT(*) INTO v_pag FROM PAGOS pg
    JOIN   USUARIOS u ON u.id_usuario = pg.id_usuario
    WHERE  u.email = 'sebastian.roa@quindioflix.com';

    DBMS_OUTPUT.PUT_LINE('USUARIOS restantes : ' || v_usu || ' (esperado: 0)');
    DBMS_OUTPUT.PUT_LINE('PERFILES restantes : ' || v_per || ' (esperado: 0)');
    DBMS_OUTPUT.PUT_LINE('PAGOS   restantes  : ' || v_pag || ' (esperado: 0)');
END;
/
