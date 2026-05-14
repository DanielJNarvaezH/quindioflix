-- =============================================================================
-- NT4-3: IDX_CONTENIDO_CAT_ANIO — Indice compuesto en CONTENIDO(id_categoria, anio_lanzamiento)
-- Archivo : NT4_nucleo4_indices_NT4_3_IDX_CONTENIDO_CAT_ANIO.sql
-- Autor   : Daniel Narvaez
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- Ticket  : SCRUM-57
-- =============================================================================
-- Justificacion:
--   Las consultas del catalogo de QuindioFlix filtran primero por categoria
--   y luego refinan por rango de anio de lanzamiento. Este patron aparece
--   en las consultas parametrizadas NT1 y en las consultas de recomendacion:
--
--     NT1-1a: consulta parametrizada que recibe &&categoria_id y &&anio_min,
--             filtra WHERE c.id_categoria = &&categoria_id
--               AND c.anio_lanzamiento >= &&anio_min
--
--     FN_CONTENIDO_RECOMENDADO (NT2-7): ordena por score y filtra por estado
--             ACTIVO sobre toda la tabla CONTENIDO — un indice en id_categoria
--             permite saltar directo a la categoria de interes.
--
--   Sin indice: Oracle hace TABLE ACCESS FULL sobre CONTENIDO (40 titulos hoy,
--   cientos en produccion) para cada consulta del catalogo.
--   Con este indice compuesto: INDEX RANGE SCAN directo al bloque de
--   id_categoria = X, ya ordenado por anio_lanzamiento para el filtro de rango.
--
-- Orden de las columnas (criterio de prefijo):
--   Columna 1 (id_categoria) : ALTA selectividad en el patron de uso.
--     El catalogo siempre filtra primero por categoria (ej: "Series",
--     "Peliculas", "Documentales"). Oracle entra al nodo hoja del B-tree
--     correspondiente a esa categoria y descarta el resto inmediatamente.
--   Columna 2 (anio_lanzamiento): refina dentro de la categoria con
--     rangos BETWEEN o >= / <=. Al estar ordenada despues de id_categoria
--     en el indice, Oracle puede recorrer solo el subrango de anios sin
--     sort adicional.
--
--   Si el orden fuera (anio_lanzamiento, id_categoria), las consultas que
--   filtran solo por categoria no podrian usar el prefijo del indice y
--   Oracle volveria al FULL TABLE SCAN.
--
-- Cardinalidades en la BD actual:
--   id_categoria    : 8 categorias distintas (baja-media) — B-tree preferido
--                     sobre Bitmap porque CONTENIDO recibe INSERTs frecuentes
--                     (nuevos titulos) y Bitmap degrada con escrituras.
--   anio_lanzamiento: rango 1888-2100, valores continuos — alta cardinalidad,
--                     ideal para B-tree y rangos BETWEEN.
--
-- Tablespace: ts_quindioflix_indices — separado de datos para reducir
--   contension de I/O (criterio del proyecto desde MOD-3).
--
-- Idempotencia:
--   DROP defensivo con manejo de ORA-01418 (index does not exist).
--   Re-ejecutar el script es seguro.
--
-- Ejecucion:
--   SQL Developer / SQL*Plus con Run as Script (F5) como QUINDIOFLIX.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PASO 1: DROP defensivo — permite re-ejecutar sin error
-- =============================================================================
BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_CONTENIDO_CAT_ANIO';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF; -- ORA-01418: index does not exist
END;
/

-- =============================================================================
-- PASO 2: Crear el indice compuesto B-tree
-- Columna 1: id_categoria  — prefijo del indice, filtro principal del catalogo
-- Columna 2: anio_lanzamiento — refinamiento por rango dentro de la categoria
-- =============================================================================
CREATE INDEX IDX_CONTENIDO_CAT_ANIO
    ON CONTENIDO (id_categoria, anio_lanzamiento)
    TABLESPACE ts_quindioflix_indices;

BEGIN
    DBMS_OUTPUT.PUT_LINE('IDX_CONTENIDO_CAT_ANIO creado correctamente.');
END;
/

-- =============================================================================
-- PASO 3: Verificar creacion en el catalogo
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-3 VERIFICACION: Indice en el catalogo
PROMPT ============================================================

SELECT index_name,
       index_type,
       uniqueness,
       status,
       tablespace_name
FROM   user_indexes
WHERE  table_name = 'CONTENIDO'
ORDER  BY index_name;

-- =============================================================================
-- PASO 4: EXPLAIN PLAN — comparar sin y con el indice
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT4-3 EXPLAIN PLAN: Consulta del catalogo por categoria y anio
PROMPT ============================================================

-- Consulta representativa del catalogo:
-- "Series estrenadas entre 2020 y 2025"
-- Esta es la consulta que NT1-1a parametriza con &&categoria_id y &&anio_min
EXPLAIN PLAN FOR
SELECT c.id_contenido,
       c.titulo,
       c.anio_lanzamiento,
       c.popularidad,
       cat.nombre AS categoria
FROM   CONTENIDO c
           JOIN   CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE  c.id_categoria     = 1
  AND  c.anio_lanzamiento BETWEEN 2015 AND 2026;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Resultado esperado con el indice:
--   INDEX RANGE SCAN sobre IDX_CONTENIDO_CAT_ANIO
--   Oracle entra directamente a id_categoria=1 y recorre solo los anios
--   en el rango [2015, 2026] sin leer la tabla completa.
--
-- Sin el indice el plan mostraria:
--   TABLE ACCESS FULL sobre CONTENIDO con filtro post-scan

-- =============================================================================
-- PASO 5: Verificar indices de todas las tablas NT4 para el documento
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT NT4-3 INDICES NT4 COMPLETOS: Todos los indices del proyecto
PROMPT ============================================================

SELECT table_name,
       index_name,
       index_type,
       uniqueness,
       status
FROM   user_indexes
WHERE  table_name IN ('REPRODUCCIONES', 'USUARIOS', 'CONTENIDO')
ORDER  BY table_name, index_name;

-- =============================================================================
-- Resultado esperado final:
--   CONTENIDO   IDX_CONTENIDO_CAT_ANIO   NORMAL   NONUNIQUE   VALID
--   REPRODUCCIONES   IDX_REPROD_PERFIL_FECHA   NORMAL   NONUNIQUE   VALID/N_A (LOCAL)
--   USUARIOS    IDX_USUARIOS_EMAIL   NORMAL   UNIQUE   VALID
-- =============================================================================