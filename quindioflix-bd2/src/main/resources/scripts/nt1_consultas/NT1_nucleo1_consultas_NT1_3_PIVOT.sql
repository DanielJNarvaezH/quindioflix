-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_3_PIVOT.sql
-- Autores : Equipo QuindioFlix
-- Nucleo  : NT1-3 — PIVOT reproducciones por categoria y dispositivo
--
-- DESCRIPCION:
--   Genera dos reportes cruzados de reproducciones usando PIVOT:
--
--   NT1-3a — Tabla de contingencia pura (5 filas x 5 columnas)
--     Filas    : categorias de contenido (Peliculas, Series,
--                Documentales, Musica, Podcasts)
--     Columnas : dispositivos + total (CELULAR, TABLET, TV,
--                COMPUTADOR, TOTAL_CATEGORIA)
--     Valores  : cantidad de reproducciones por combinacion
--
--   NT1-3b — Igual que NT1-3a + fila de totales por dispositivo (6 filas)
--     Agrega la fila '*** TOTAL DISPOSITIVO ***' al final con
--     la suma de reproducciones por dispositivo y el gran total.
--
--   Tablas involucradas:
--     REPRODUCCIONES r -> CONTENIDO c -> CATEGORIAS cat
--     (mismo JOIN path que NT1-7 de Daniel)
--
--   Relacion con otros scripts NT1:
--     NT1-7 (Daniel) : CUBE sobre las mismas dimensiones — produce
--                      subtotales jerarquicos automaticos.
--     NT1-3 (este)   : PIVOT — visualiza los mismos datos como
--                      matriz 2D sin subtotales intermedios.
--     Verificacion cruzada: SUM(TOTAL_CATEGORIA) en NT1-3 debe
--     coincidir con el GRAN TOTAL de NT1-7 (ambos = 200 en el seed).
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   No usa variables de sustitucion — consulta estatica de reporte.
--   Compatible con Flyway (sin variables & ni &&).
-- =============================================================================


-- =============================================================================
-- NT1-3a: PIVOT puro — tabla de contingencia categoria x dispositivo
-- Resultado : 5 filas (una por categoria), 5 columnas (4 dispositivos + total)
-- Celdas 0  : NVL convierte NULL a 0 cuando no hay reproducciones
--             para esa combinacion categoria x dispositivo
-- =============================================================================

SELECT
    categoria,
    NVL(CELULAR_REPRODUCCIONES,    0) AS celular_reproducciones,
    NVL(TABLET_REPRODUCCIONES,     0) AS tablet_reproducciones,
    NVL(TV_REPRODUCCIONES,         0) AS tv_reproducciones,
    NVL(COMPUTADOR_REPRODUCCIONES, 0) AS computador_reproducciones,
    NVL(CELULAR_REPRODUCCIONES,    0)
      + NVL(TABLET_REPRODUCCIONES,     0)
      + NVL(TV_REPRODUCCIONES,         0)
      + NVL(COMPUTADOR_REPRODUCCIONES, 0)  AS total_categoria
FROM (
    -- Subconsulta: proyecta exactamente 3 columnas para el PIVOT.
    -- Columnas extra en este nivel rompen el agrupamiento interno.
    SELECT
        cat.nombre        AS categoria,
        r.dispositivo,
        r.id_reproduccion
    FROM REPRODUCCIONES r
        JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
        JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
)
PIVOT (
    -- COUNT(id_reproduccion) AS reproducciones genera columnas:
    --   CELULAR_REPRODUCCIONES, TABLET_REPRODUCCIONES,
    --   TV_REPRODUCCIONES, COMPUTADOR_REPRODUCCIONES
    COUNT(id_reproduccion) AS reproducciones
    FOR dispositivo IN (
        'CELULAR'    AS "CELULAR",
        'TABLET'     AS "TABLET",
        'TV'         AS "TV",
        'COMPUTADOR' AS "COMPUTADOR"
    )
)
ORDER BY
    CASE categoria
        WHEN 'Peliculas'    THEN 1
        WHEN 'Series'       THEN 2
        WHEN 'Documentales' THEN 3
        WHEN 'Musica'       THEN 4
        WHEN 'Podcasts'     THEN 5
        ELSE 99
    END;


-- =============================================================================
-- NT1-3b: PIVOT + fila TOTAL DISPOSITIVO via UNION ALL
-- Resultado  : 6 filas (5 categorias + 1 fila de totales por dispositivo)
-- Fila total : '*** TOTAL DISPOSITIVO ***' al final, sumando cada columna
--
-- Diseno: el bloque B suma directamente desde REPRODUCCIONES (sin pasar
-- por el PIVOT) para mayor claridad y para demostrar que ambas fuentes
-- producen el mismo resultado — el gran total debe ser 200.
-- =============================================================================

SELECT
    categoria,
    celular_reproducciones,
    tablet_reproducciones,
    tv_reproducciones,
    computador_reproducciones,
    total_categoria
FROM (

    -- Bloque A: filas de detalle (mismo PIVOT que NT1-3a)
    SELECT
        categoria,
        NVL(CELULAR_REPRODUCCIONES,    0) AS celular_reproducciones,
        NVL(TABLET_REPRODUCCIONES,     0) AS tablet_reproducciones,
        NVL(TV_REPRODUCCIONES,         0) AS tv_reproducciones,
        NVL(COMPUTADOR_REPRODUCCIONES, 0) AS computador_reproducciones,
        NVL(CELULAR_REPRODUCCIONES,    0)
          + NVL(TABLET_REPRODUCCIONES,     0)
          + NVL(TV_REPRODUCCIONES,         0)
          + NVL(COMPUTADOR_REPRODUCCIONES, 0)  AS total_categoria,
        CASE categoria
            WHEN 'Peliculas'    THEN 1
            WHEN 'Series'       THEN 2
            WHEN 'Documentales' THEN 3
            WHEN 'Musica'       THEN 4
            WHEN 'Podcasts'     THEN 5
            ELSE 99
        END AS orden_fila
    FROM (
        SELECT
            cat.nombre        AS categoria,
            r.dispositivo,
            r.id_reproduccion
        FROM REPRODUCCIONES r
            JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
            JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
    )
    PIVOT (
        COUNT(id_reproduccion) AS reproducciones
        FOR dispositivo IN (
            'CELULAR'    AS "CELULAR",
            'TABLET'     AS "TABLET",
            'TV'         AS "TV",
            'COMPUTADOR' AS "COMPUTADOR"
        )
    )

    UNION ALL

    -- Bloque B: fila '*** TOTAL DISPOSITIVO ***'
    -- Suma directamente desde REPRODUCCIONES para mayor legibilidad.
    -- Verificacion: total_categoria aqui debe ser igual a COUNT(*) FROM REPRODUCCIONES.
    SELECT
        '*** TOTAL DISPOSITIVO ***'                                       AS categoria,
        SUM(CASE WHEN r.dispositivo = 'CELULAR'    THEN 1 ELSE 0 END)    AS celular_reproducciones,
        SUM(CASE WHEN r.dispositivo = 'TABLET'     THEN 1 ELSE 0 END)    AS tablet_reproducciones,
        SUM(CASE WHEN r.dispositivo = 'TV'         THEN 1 ELSE 0 END)    AS tv_reproducciones,
        SUM(CASE WHEN r.dispositivo = 'COMPUTADOR' THEN 1 ELSE 0 END)    AS computador_reproducciones,
        COUNT(r.id_reproduccion)                                          AS total_categoria,
        100                                                               AS orden_fila
    FROM REPRODUCCIONES r

)
ORDER BY orden_fila, categoria;


-- =============================================================================
-- RESULTADO ESPERADO (con los datos seed V3 + V4 — 200 reproducciones)
--
-- NT1-3a (5 filas):
--
--   CATEGORIA    | CELULAR | TABLET | TV | COMPUTADOR | TOTAL_CATEGORIA
--   -------------|---------|--------|----|------------|----------------
--   Documentales |      XX |     XX | XX |         XX |              XX
--   Musica       |      XX |     XX | XX |         XX |              XX
--   Peliculas    |      XX |     XX | XX |         XX |              XX
--   Podcasts     |      XX |     XX | XX |         XX |              XX
--   Series       |      XX |     XX | XX |         XX |              XX
--   SUMA TOTAL   |      -- |     -- | -- |         -- |             200
--
--   Distribucion aproximada de dispositivos en el seed (200 reprod.):
--     CELULAR    : ~80 (40%)
--     TV         : ~60 (30%)
--     COMPUTADOR : ~40 (20%)
--     TABLET     : ~20 (10%)
--
--   Celdas con 0: posible para categorias con pocos contenidos
--   (Podcasts x TABLET podria ser 0 con la distribucion del seed).
--
-- NT1-3b (6 filas):
--   Igual que NT1-3a + fila final:
--   '*** TOTAL DISPOSITIVO ***' | ~80 | ~20 | ~60 | ~40 | 200
--
-- VERIFICACION RAPIDA:
--   SELECT COUNT(*) FROM REPRODUCCIONES;
--   -- debe coincidir con TOTAL_CATEGORIA en la fila '*** TOTAL DISPOSITIVO ***'
--   -- y con la suma de TOTAL_CATEGORIA sobre las 5 filas de NT1-3a.
--
--   Verificacion cruzada con NT1-7 (Daniel):
--   SELECT COUNT(*) FROM REPRODUCCIONES;
--   -- debe coincidir con el valor de total_reproducciones en la fila
--   -- nivel_agregacion = 'GRAN TOTAL' del script NT1-7.
-- =============================================================================
