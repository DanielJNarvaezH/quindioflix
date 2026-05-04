-- =============================================================================
-- NT4-2: IDX_USUARIOS_EMAIL — Índice explícito en USUARIOS(email)
-- Archivo : NT4_nucleo4_indices_NT4_2_IDX_USUARIOS_EMAIL.sql
-- Autor   : Cristhian Eduardo Osorio Restrepo
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- Ticket  : SCRUM-56
-- =============================================================================
-- Contexto técnico:
--   V2__create_tables.sql define en USUARIOS la constraint:
--       CONSTRAINT uq_usuarios_email UNIQUE (email)
--           USING INDEX TABLESPACE ts_quindioflix_indices
--   Oracle genera automáticamente un índice implícito llamado UQ_USUARIOS_EMAIL.
--   Ese índice funciona, pero su nombre no sigue la convención IDX_* del
--   proyecto, lo que dificulta identificarlo en EXPLAIN PLAN y en el catálogo.
--
-- Objetivo:
--   Reemplazar el índice implícito por IDX_USUARIOS_EMAIL, un índice único
--   B-tree explícito con nombre semántico, y religar la constraint UNIQUE a él.
--   El índice se almacena en el tablespace dedicado ts_quindioflix_indices.
--
-- Justificación de negocio:
--   email es la columna de búsqueda más frecuente del sistema:
--     1. SP_REGISTRAR_USUARIO valida duplicados con WHERE email = LOWER(TRIM(?))
--     2. El proceso de login busca la cuenta por email en cada autenticación.
--   Sin un índice en esa columna Oracle hace TABLE ACCESS FULL sobre USUARIOS,
--   recorriendo todos los registros para encontrar uno solo. Con el índice la
--   operación se convierte en INDEX UNIQUE SCAN: acceso O(log n) sobre la clave.
--
-- Idempotencia:
--   Si IDX_USUARIOS_EMAIL ya existe el bloque DECLARE lo detecta y no hace nada.
--   Si solo existe el índice implícito UQ_USUARIOS_EMAIL, lo reemplaza.
--
-- Ejecución:
--   SQL Developer / SQL*Plus con Run as Script (F5).
-- =============================================================================

-- =============================================================================
-- PASO 1: Reemplazar índice implícito por índice explícito con nombre semántico
-- =============================================================================
DECLARE
    v_idx_exists NUMBER := 0;
    v_cst_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_idx_exists
    FROM   user_indexes
    WHERE  index_name = 'IDX_USUARIOS_EMAIL';

    IF v_idx_exists = 0 THEN

        -- Verificar si la constraint sigue ligada al índice implícito
        SELECT COUNT(*) INTO v_cst_exists
        FROM   user_constraints
        WHERE  constraint_name = 'UQ_USUARIOS_EMAIL'
        AND    table_name      = 'USUARIOS';

        IF v_cst_exists > 0 THEN
            -- Desligar y eliminar la constraint (elimina también el índice implícito)
            EXECUTE IMMEDIATE 'ALTER TABLE USUARIOS DROP CONSTRAINT UQ_USUARIOS_EMAIL';
        END IF;

        -- Crear el índice único explícito con nombre semántico
        EXECUTE IMMEDIATE
            'CREATE UNIQUE INDEX IDX_USUARIOS_EMAIL
                 ON USUARIOS (email)
                 TABLESPACE ts_quindioflix_indices';

        -- Religar la constraint UNIQUE al nuevo índice
        EXECUTE IMMEDIATE
            'ALTER TABLE USUARIOS ADD CONSTRAINT UQ_USUARIOS_EMAIL
                 UNIQUE (email)
                 USING INDEX IDX_USUARIOS_EMAIL';

        DBMS_OUTPUT.PUT_LINE('IDX_USUARIOS_EMAIL creado y constraint religada.');

    ELSE
        DBMS_OUTPUT.PUT_LINE('IDX_USUARIOS_EMAIL ya existe — sin cambios.');
    END IF;
END;
/

-- =============================================================================
-- PASO 2: Verificar creación en el catálogo
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-2 VERIFICACION: Índice y constraint en el catálogo
PROMPT ============================================================

SELECT index_name,
       index_type,
       uniqueness,
       status,
       tablespace_name
FROM   user_indexes
WHERE  table_name  = 'USUARIOS'
ORDER BY index_name;

SELECT constraint_name,
       constraint_type,
       index_name,
       status
FROM   user_constraints
WHERE  table_name       = 'USUARIOS'
AND    constraint_name  = 'UQ_USUARIOS_EMAIL';

-- =============================================================================
-- Resultado esperado:
--   INDEX_NAME              INDEX_TYPE  UNIQUENESS  STATUS  TABLESPACE
--   IDX_USUARIOS_EMAIL      NORMAL      UNIQUE       VALID   TS_QUINDIOFLIX_INDICES
--   (más los índices de otras constraints PK/FK)
--
--   CONSTRAINT_NAME       C  INDEX_NAME           STATUS
--   UQ_USUARIOS_EMAIL     U  IDX_USUARIOS_EMAIL   ENABLED
-- =============================================================================
