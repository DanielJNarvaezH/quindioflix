-- =============================================================================
-- NT4-5: Análisis EXPLAIN PLAN antes/después — IDX_USUARIOS_EMAIL
-- Archivo : NT4_nucleo4_indices_NT4_5_EXPLAIN_PLAN.sql
-- Autor   : Cristhian Eduardo Osorio Restrepo
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- Ticket  : SCRUM-59
-- Depende : NT4-2 (IDX_USUARIOS_EMAIL debe existir antes de ejecutar este script)
-- =============================================================================
-- Objetivo:
--   Comparar el plan de ejecución de una consulta pesada con JOIN entre
--   REPRODUCCIONES, PERFILES, USUARIOS y CONTENIDO, filtrando por email,
--   antes y después de que IDX_USUARIOS_EMAIL esté activo.
--
-- Consulta analizada (reporte de consumo de un usuario por email):
--   Reporte de todas las reproducciones de un usuario identificado por email,
--   incluyendo el título del contenido reproducido y el porcentaje de avance.
--   Es representativa del login + consulta de historial, el flujo más frecuente.
--
-- Metodología:
--   Para simular "sin índice" sin borrar el objeto, se usa:
--       ALTER INDEX IDX_USUARIOS_EMAIL INVISIBLE
--   Oracle ignora los índices INVISIBLE al construir el plan, lo que fuerza
--   TABLE ACCESS FULL sobre USUARIOS. Al volverlo VISIBLE el índice es elegible
--   nuevamente y el optimizador usa INDEX UNIQUE SCAN.
--
-- Ejecución:
--   1. Ejecutar NT4-2 primero para asegurar que IDX_USUARIOS_EMAIL existe.
--   2. Activar SET SERVEROUTPUT ON SIZE UNLIMITED.
--   3. Ejecutar este script completo con Run as Script (F5).
--   4. Tomar capturas de cada bloque EXPLAIN PLAN mostrado en la salida.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- CONSULTA ANALIZADA
-- Reporte de reproducciones de un usuario filtrado por email.
-- Involucra: REPRODUCCIONES → PERFILES → USUARIOS → CONTENIDO (4 tablas).
-- La condición WHERE u.email = ? es el punto de entrada que el índice optimiza.
-- =============================================================================

-- =============================================================================
-- BLOQUE 1: EXPLAIN PLAN SIN ÍNDICE (índice INVISIBLE)
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-5 PASO 1: EXPLAIN PLAN — IDX_USUARIOS_EMAIL INVISIBLE
PROMPT             (simula estado sin índice)
PROMPT ============================================================

ALTER INDEX IDX_USUARIOS_EMAIL INVISIBLE;

EXPLAIN PLAN FOR
SELECT  u.id_usuario,
        u.nombre || ' ' || u.apellido   AS usuario,
        u.email,
        c.titulo                        AS contenido,
        r.porcentaje_avance,
        r.fecha_hora_inicio
FROM    REPRODUCCIONES  r
JOIN    PERFILES        p ON p.id_perfil    = r.id_perfil
JOIN    USUARIOS        u ON u.id_usuario   = p.id_usuario
JOIN    CONTENIDO       c ON c.id_contenido = r.id_contenido
WHERE   u.email = 'sofia.perea@quindioflix.com'
ORDER BY r.fecha_hora_inicio DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

-- =============================================================================
-- BLOQUE 2: EXPLAIN PLAN CON ÍNDICE (índice VISIBLE)
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-5 PASO 2: EXPLAIN PLAN — IDX_USUARIOS_EMAIL VISIBLE
PROMPT             (estado con índice activo)
PROMPT ============================================================

ALTER INDEX IDX_USUARIOS_EMAIL VISIBLE;

EXPLAIN PLAN FOR
SELECT  u.id_usuario,
        u.nombre || ' ' || u.apellido   AS usuario,
        u.email,
        c.titulo                        AS contenido,
        r.porcentaje_avance,
        r.fecha_hora_inicio
FROM    REPRODUCCIONES  r
JOIN    PERFILES        p ON p.id_perfil    = r.id_perfil
JOIN    USUARIOS        u ON u.id_usuario   = p.id_usuario
JOIN    CONTENIDO       c ON c.id_contenido = r.id_contenido
WHERE   u.email = 'sofia.perea@quindioflix.com'
ORDER BY r.fecha_hora_inicio DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

-- =============================================================================
-- BLOQUE 3: COMPARACIÓN CONSOLIDADA (ambos planes en una vista)
-- Para inspección manual: muestra los últimos dos planes registrados
-- en PLAN_TABLE ordenados por statement_id y position.
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-5 PASO 3: Verificar que el índice quedó VISIBLE
PROMPT ============================================================

SELECT index_name, visibility, status
FROM   user_indexes
WHERE  table_name  = 'USUARIOS'
AND    index_name  = 'IDX_USUARIOS_EMAIL';

-- =============================================================================
-- ANÁLISIS ESPERADO
-- =============================================================================
--
-- SIN ÍNDICE (INVISIBLE) — operación crítica: TABLE ACCESS FULL
-- ---------------------------------------------------------------
-- Plan hash value: XXXXXXXXXX
-- ---------------------------------------------------------------
-- | Id | Operation                    | Name         | Rows | Cost |
-- ---------------------------------------------------------------
-- |  0 | SELECT STATEMENT             |              |    N |  ### |
-- |  1 |  SORT ORDER BY               |              |    N |  ### |
-- |  2 |   HASH JOIN                  |              |    N |  ### |
-- |  3 |    TABLE ACCESS FULL         | CONTENIDO    |   40 |    3 |
-- |  4 |    HASH JOIN                 |              |    N |  ### |
-- |  5 |     HASH JOIN                |              |    N |  ### |
-- |  6 |      TABLE ACCESS FULL       | USUARIOS     |   30 |    3 |  <-- full scan
-- |  7 |      TABLE ACCESS FULL       | PERFILES     |   50 |    3 |
-- |  8 |     PARTITION RANGE ALL      |              |  200 |   10 |
-- |  9 |      TABLE ACCESS FULL       | REPRODUCCIONES|  200 |   10|
-- ---------------------------------------------------------------
-- Observación: Oracle recorre los 30 usuarios para encontrar uno.
-- Cost elevado por el FULL SCAN en la tabla raíz del JOIN.
--
-- CON ÍNDICE (VISIBLE) — operación óptima: INDEX UNIQUE SCAN
-- ---------------------------------------------------------------
-- Plan hash value: YYYYYYYYYY
-- ---------------------------------------------------------------
-- | Id | Operation                          | Name                | Rows | Cost |
-- ---------------------------------------------------------------
-- |  0 | SELECT STATEMENT                   |                     |    N |  ### |
-- |  1 |  SORT ORDER BY                     |                     |    N |  ### |
-- |  2 |   HASH JOIN                        |                     |    N |  ### |
-- |  3 |    TABLE ACCESS FULL               | CONTENIDO           |   40 |    3 |
-- |  4 |    HASH JOIN                       |                     |    N |  ### |
-- |  5 |     NESTED LOOPS                   |                     |    1 |    2 |
-- |  6 |      INDEX UNIQUE SCAN             | IDX_USUARIOS_EMAIL  |    1 |    1 |  <-- índice
-- |  7 |      TABLE ACCESS BY INDEX ROWID   | USUARIOS            |    1 |    1 |
-- |  8 |      TABLE ACCESS FULL             | PERFILES            |    2 |    3 |
-- |  9 |    PARTITION RANGE ALL             |                     |    N |  ### |
-- | 10 |     TABLE ACCESS FULL              | REPRODUCCIONES      |  200 |   10 |
-- ---------------------------------------------------------------
-- Observación: Oracle entra por el índice (1 I/O), recupera la fila
-- del usuario directamente por ROWID, y construye el JOIN desde ese
-- único registro. Costo del acceso a USUARIOS cae de O(n) a O(log n).
-- =============================================================================
