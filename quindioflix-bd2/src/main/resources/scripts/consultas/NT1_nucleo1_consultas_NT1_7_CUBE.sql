-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_7_CUBE.sql
-- Autores : Equipo QuindioFlix
-- Nucleo  : NT1-7 — CUBE reproducciones por categoria y dispositivo
--
-- DESCRIPCION:
--   Genera todas las combinaciones posibles de agrupacion entre categoria
--   de contenido y dispositivo de reproduccion usando GROUP BY CUBE.
--   CUBE produce 2^2 = 4 niveles de agregacion:
--     1. categoria + dispositivo  (detalle cruzado)
--     2. categoria sola           (subtotal por categoria)
--     3. dispositivo solo         (subtotal por dispositivo)
--     4. sin agrupacion           (gran total general)
--
--   Se usa GROUPING() para reemplazar los NULLs que CUBE genera en las
--   filas de subtotal, mostrando etiquetas legibles en lugar de NULL.
--
--   Tablas involucradas:
--     REPRODUCCIONES r -> CONTENIDO c -> CATEGORIAS cat
--     REPRODUCCIONES r -> dispositivo (campo directo)
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   No usa variables de sustitucion — consulta estatica de reporte.
--   Compatible con Flyway (sin variables & ni &&).
-- =============================================================================


-- =============================================================================
-- NT1-7a: CUBE completo — todas las combinaciones categoria x dispositivo
-- Muestra: detalle cruzado + subtotales por categoria + subtotales por
--          dispositivo + gran total general
-- GROUPING() = 1 cuando la columna es NULL por efecto del CUBE (subtotal)
--            = 0 cuando es un valor real de la tabla
-- =============================================================================

SELECT
    CASE GROUPING(cat.nombre)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE cat.nombre
        END                                             AS categoria,
    CASE GROUPING(r.dispositivo)
        WHEN 1 THEN '** TODOS LOS DISPOSITIVOS **'
        ELSE r.dispositivo
        END                                             AS dispositivo,
    COUNT(r.id_reproduccion)                        AS total_reproducciones,
    ROUND(AVG(r.porcentaje_avance), 1)              AS promedio_avance_pct,
    SUM(CASE WHEN r.porcentaje_avance >= 90
                 THEN 1 ELSE 0 END)                     AS vistas_completas,
    -- Indicadores de nivel de agregacion para claridad del reporte
    CASE
        WHEN GROUPING(cat.nombre) = 1
            AND GROUPING(r.dispositivo) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(cat.nombre) = 1    THEN 'SUBTOTAL DISPOSITIVO'
        WHEN GROUPING(r.dispositivo) = 1 THEN 'SUBTOTAL CATEGORIA'
        ELSE 'DETALLE'
        END                                             AS nivel_agregacion
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
GROUP BY CUBE(cat.nombre, r.dispositivo)
ORDER BY
    GROUPING(cat.nombre),
    GROUPING(r.dispositivo),
    cat.nombre  NULLS LAST,
    r.dispositivo NULLS LAST;


-- =============================================================================
-- NT1-7b: GROUPING SETS equivalente — consolida solo los niveles utiles
-- Muestra los mismos 4 niveles del CUBE pero escrito con GROUPING SETS
-- para demostrar que CUBE es azucar sintactica sobre GROUPING SETS.
--
-- CUBE(categoria, dispositivo) es equivalente a:
--   GROUPING SETS(
--     (categoria, dispositivo),  -- detalle cruzado
--     (categoria),               -- subtotal por categoria
--     (dispositivo),             -- subtotal por dispositivo
--     ()                         -- gran total
--   )
-- =============================================================================

SELECT
    CASE GROUPING(cat.nombre)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE cat.nombre
        END                                             AS categoria,
    CASE GROUPING(r.dispositivo)
        WHEN 1 THEN '** TODOS LOS DISPOSITIVOS **'
        ELSE r.dispositivo
        END                                             AS dispositivo,
    COUNT(r.id_reproduccion)                        AS total_reproducciones,
    ROUND(AVG(r.porcentaje_avance), 1)              AS promedio_avance_pct,
    SUM(CASE WHEN r.porcentaje_avance >= 90
                 THEN 1 ELSE 0 END)                     AS vistas_completas,
    CASE
        WHEN GROUPING(cat.nombre) = 1
            AND GROUPING(r.dispositivo) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(cat.nombre) = 1    THEN 'SUBTOTAL DISPOSITIVO'
        WHEN GROUPING(r.dispositivo) = 1 THEN 'SUBTOTAL CATEGORIA'
        ELSE 'DETALLE'
        END                                             AS nivel_agregacion
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
GROUP BY GROUPING SETS (
    (cat.nombre, r.dispositivo),   -- detalle: cada combinacion categoria+dispositivo
    (cat.nombre),                  -- subtotal: total por categoria sin importar dispositivo
    (r.dispositivo),               -- subtotal: total por dispositivo sin importar categoria
    ()                             -- gran total: todas las reproducciones
    )
ORDER BY
    GROUPING(cat.nombre),
    GROUPING(r.dispositivo),
    cat.nombre  NULLS LAST,
    r.dispositivo NULLS LAST;


-- =============================================================================
-- RESULTADO ESPERADO (estructura — valores dependen de los datos V4):
--
-- NT1-7a y NT1-7b deben producir EXACTAMENTE el mismo resultado.
-- Eso demuestra que CUBE es equivalente al GROUPING SETS expandido.
--
-- Niveles que aparecen en el resultado:
--
--   DETALLE (categoria + dispositivo reales):
--     Documentales | CELULAR     |  X reprod.
--     Documentales | COMPUTADOR  |  X reprod.
--     ...
--     Series       | TV          |  X reprod.
--     ...
--
--   SUBTOTAL CATEGORIA (dispositivo = '** TODOS LOS DISPOSITIVOS **'):
--     Documentales | ** TODOS ** |  X reprod.  <- total de Documentales en todos los dispositivos
--     Musica       | ** TODOS ** |  X reprod.
--     Peliculas    | ** TODOS ** |  X reprod.
--     Podcasts     | ** TODOS ** |  X reprod.
--     Series       | ** TODOS ** |  X reprod.
--
--   SUBTOTAL DISPOSITIVO (categoria = '*** TOTAL GENERAL ***'):
--     *** TOTAL *** | CELULAR     |  X reprod.  <- total en CELULAR en todas las categorias
--     *** TOTAL *** | COMPUTADOR  |  X reprod.
--     *** TOTAL *** | TABLET      |  X reprod.
--     *** TOTAL *** | TV          |  X reprod.
--
--   GRAN TOTAL:
--     *** TOTAL *** | ** TODOS ** | 200 reprod. <- total absoluto (debe ser 200)
--
-- VERIFICACION RAPIDA:
--   SELECT COUNT(*) FROM REPRODUCCIONES;
--   -> debe coincidir con el valor de GRAN TOTAL
-- =============================================================================