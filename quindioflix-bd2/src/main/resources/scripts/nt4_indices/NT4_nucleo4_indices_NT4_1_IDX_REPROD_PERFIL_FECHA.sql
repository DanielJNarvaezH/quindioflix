-- =============================================================================
-- NT4-1: Indice compuesto en REPRODUCCIONES(id_perfil, fecha_hora_inicio)
-- Autor  : Diego Garcia
-- Tarea  : NT4-1 del cronograma QuindioFlix — Sprint 4
--
-- JUSTIFICACION:
--   Las consultas de historial de reproduccion filtran siempre por
--   id_perfil (WHERE id_perfil = ?) y ordenan por fecha_hora_inicio
--   (ORDER BY fecha_hora_inicio DESC). Sin indice Oracle hace un
--   FULL TABLE SCAN sobre REPRODUCCIONES recorriendo todos los
--   registros para encontrar los de un perfil especifico.
--   Con este indice compuesto Oracle hace INDEX RANGE SCAN:
--   entra directamente al rango id_perfil=X y recorre solo
--   sus registros ya ordenados por fecha, eliminando el sort.
--
--   Columna 1 (id_perfil): cardinalidad media — 50 perfiles
--     -> reduce drasticamente los registros a examinar
--   Columna 2 (fecha_hora_inicio): permite el ORDER BY sin sort adicional
--     -> el indice ya entrega las filas en orden cronologico
--
--   Tablespace: ts_quindioflix_indices — separado de datos para
--   reducir contension de I/O (criterio del proyecto desde MOD-3).
--
-- NOTA SOBRE TABLA PARTICIONADA:
--   REPRODUCCIONES esta particionada por RANGE sobre fecha_hora_inicio
--   (p_2024, p_2025, p_2026). Oracle crea automaticamente un indice
--   LOCAL por particion, lo que significa que cada particion tiene
--   su propio segmento de indice — aun mas eficiente porque las
--   consultas por rango de fechas solo acceden a la particion relevante.
-- =============================================================================

-- =============================================================================
-- NT4-1.0: DROP defensivo — permite re-ejecutar sin error
-- =============================================================================
BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_REPROD_PERFIL_FECHA';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF; -- ORA-01418: index does not exist
END;
/

-- =============================================================================
-- NT4-1.1: Crear el indice compuesto LOCAL (compatible con tabla particionada)
-- LOCAL: cada particion (p_2024, p_2025, p_2026) tiene su propio segmento
-- ASC en ambas columnas: alinea con ORDER BY id_perfil, fecha_hora_inicio DESC
-- =============================================================================
CREATE INDEX IDX_REPROD_PERFIL_FECHA
    ON REPRODUCCIONES (id_perfil, fecha_hora_inicio)
    LOCAL
    TABLESPACE ts_quindioflix_indices;

-- =============================================================================
-- NT4-1.2: Consulta de referencia — historial de un perfil
-- Esta es la consulta que se beneficia del indice.
-- Ejecutar EXPLAIN PLAN antes y despues de crear el indice para comparar.
-- =============================================================================

-- EXPLAIN PLAN con el indice ya creado
EXPLAIN PLAN FOR
SELECT
    r.id_reproduccion,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.dispositivo,
    r.porcentaje_avance,
    c.titulo,
    cat.nombre AS categoria
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE r.id_perfil = 1
ORDER BY r.fecha_hora_inicio DESC;

-- Ver el plan de ejecucion
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- =============================================================================
-- NT4-1.3: Verificar que el indice fue creado correctamente
-- =============================================================================
SELECT
    i.index_name,
    i.index_type,
    i.partitioned,
    i.status,
    i.tablespace_name,
    ic.column_name,
    ic.column_position,
    ic.descend
FROM user_indexes     i
         JOIN user_ind_columns ic ON ic.index_name = i.index_name
WHERE i.index_name = 'IDX_REPROD_PERFIL_FECHA'
ORDER BY ic.column_position;

-- Verificar segmentos por particion (LOCAL index)
SELECT
    ip.index_name,
    ip.partition_name,
    ip.tablespace_name,
    ip.status
FROM user_ind_partitions ip
WHERE ip.index_name = 'IDX_REPROD_PERFIL_FECHA'
ORDER BY ip.partition_name;