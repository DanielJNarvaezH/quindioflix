-- =============================================================================
-- NT4-4: Indice adicional a eleccion — Justificado
-- Autor  : Diego Garcia
-- Tarea  : NT4-4 del cronograma QuindioFlix — Sprint 4
--
-- INDICE ELEGIDO:
--   IDX_PAGOS_USUARIO_FECHA_ESTADO
--   ON PAGOS (id_usuario, fecha_pago, estado_pago)
--
-- JUSTIFICACION:
--   Este indice compuesto beneficia las tres consultas mas frecuentes
--   del sistema sobre PAGOS:
--
--   1. NT2-1 (Cursor suscripciones vencidas):
--      WHERE id_usuario = X AND estado_pago = 'EXITOSO'
--      ORDER BY fecha_pago DESC
--      -> El indice cubre el filtro por usuario y estado, y entrega
--         las fechas ya ordenadas sin sort adicional.
--
--   2. SP_REPORTE_CONSUMO (NT2-5):
--      JOIN PAGOS ON id_usuario filtrando por rango de fechas
--      -> El indice permite INDEX RANGE SCAN sobre id_usuario + fecha_pago
--         en lugar de FULL SCAN de los 80+ registros de PAGOS.
--
--   3. SP_RENOVACION_MENSUAL (NT3-2):
--      WHERE id_usuario = X (dentro de FN_CALCULAR_MONTO)
--      -> Acceso directo al ultimo pago del usuario sin recorrer toda la tabla.
--
--   Orden de columnas justificado:
--     Columna 1 (id_usuario)  : cardinalidad alta — 30 usuarios distintos
--       -> filtra drasticamente desde el primer nivel del B-tree
--     Columna 2 (fecha_pago)  : permite ORDER BY y filtros por rango
--       -> el indice ya entrega filas en orden cronologico por usuario
--     Columna 3 (estado_pago) : cardinalidad baja (4 valores posibles)
--       -> al estar al final permite index skip scan cuando se filtra
--          solo por estado sin especificar usuario
--
--   Sin este indice: FULL SCAN de PAGOS en cada llamada a SP_REPORTE_CONSUMO
--   y en cada iteracion del cursor de NT2-1 (una por usuario activo).
--   Con el indice: INDEX RANGE SCAN directo al rango del usuario.
-- =============================================================================

-- =============================================================================
-- NT4-4.0: DROP defensivo
-- =============================================================================
BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_PAGOS_USUARIO_FECHA_ESTADO';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF;
END;
/

-- =============================================================================
-- NT4-4.1: Crear el indice compuesto
-- =============================================================================
CREATE INDEX IDX_PAGOS_USUARIO_FECHA_ESTADO
    ON PAGOS (id_usuario, fecha_pago, estado_pago)
    TABLESPACE ts_quindioflix_indices;

-- =============================================================================
-- NT4-4.2: EXPLAIN PLAN — consulta de SP_REPORTE_CONSUMO (beneficiaria directa)
-- =============================================================================
EXPLAIN PLAN FOR
SELECT
    COUNT(p.id_pago)                            AS total_pagos,
    SUM(CASE WHEN p.estado_pago = 'EXITOSO'
                 THEN p.monto ELSE 0 END)           AS total_pagado,
    MAX(p.fecha_pago)                           AS ultimo_pago
FROM PAGOS p
WHERE p.id_usuario = 1
  AND p.fecha_pago BETWEEN DATE '2024-01-01' AND DATE '2024-12-31'
ORDER BY p.fecha_pago DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- =============================================================================
-- NT4-4.3: EXPLAIN PLAN — consulta del cursor de suscripciones vencidas (NT2-1)
-- =============================================================================
EXPLAIN PLAN FOR
SELECT
    p.fecha_pago,
    p.monto,
    p.estado_pago
FROM PAGOS p
WHERE p.id_usuario = 1
  AND p.estado_pago = 'EXITOSO'
ORDER BY p.fecha_pago DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- =============================================================================
-- NT4-4.4: Verificar que el indice fue creado correctamente
-- =============================================================================
SELECT
    i.index_name,
    i.index_type,
    i.status,
    i.tablespace_name,
    ic.column_name,
    ic.column_position,
    ic.descend
FROM user_indexes     i
         JOIN user_ind_columns ic ON ic.index_name = i.index_name
WHERE i.index_name = 'IDX_PAGOS_USUARIO_FECHA_ESTADO'
ORDER BY ic.column_position;