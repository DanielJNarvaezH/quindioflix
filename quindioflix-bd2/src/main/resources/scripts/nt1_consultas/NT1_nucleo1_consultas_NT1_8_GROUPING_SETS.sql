-- =============================================================================
-- NT1-8: GROUPING SETS — Totales de reproducciones por categoria y por ciudad
-- Calcula totales por cada dimension de forma independiente:
--   - Total de reproducciones por categoria (sin detalle de ciudad)
--   - Total de reproducciones por ciudad (sin detalle de categoria)
-- Diferencia con CUBE: CUBE genera TODAS las combinaciones posibles
-- (categoria x ciudad, solo categoria, solo ciudad, gran total).
-- GROUPING SETS solo genera los grupos que se le indican explicitamente,
-- sin cruzar dimensiones ni calcular el gran total automaticamente.
-- =============================================================================
SELECT
    c.nombre                                    AS categoria,
    u.ciudad_residencia                         AS ciudad,
    COUNT(r.id_reproduccion)                    AS total_reproducciones,
    GROUPING(c.nombre)                          AS es_subtotal_categoria,
    GROUPING(u.ciudad_residencia)               AS es_subtotal_ciudad
FROM REPRODUCCIONES r
         JOIN PERFILES       pe ON pe.id_perfil    = r.id_perfil
         JOIN USUARIOS       u  ON u.id_usuario    = pe.id_usuario
         JOIN CONTENIDO      co ON co.id_contenido = r.id_contenido
         JOIN CATEGORIAS     c  ON c.id_categoria  = co.id_categoria
GROUP BY GROUPING SETS (
    (c.nombre),           -- total por categoria (ciudad = NULL)
    (u.ciudad_residencia) -- total por ciudad    (categoria = NULL)
    )
ORDER BY
    GROUPING(c.nombre),
    GROUPING(u.ciudad_residencia),
    categoria NULLS LAST,
    ciudad    NULLS LAST;