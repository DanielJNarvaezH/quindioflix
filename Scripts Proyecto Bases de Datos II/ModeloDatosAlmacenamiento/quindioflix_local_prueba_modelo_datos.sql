-- 1. Ninguna constraint debe estar DISABLED
SELECT table_name, constraint_name, constraint_type, status
FROM user_constraints
WHERE status = 'DISABLED';

-- 2. Conteo general de todas las tablas
SELECT 'PLANES'               tabla, COUNT(*) n FROM PLANES               UNION ALL
SELECT 'CATEGORIAS',                 COUNT(*)   FROM CATEGORIAS            UNION ALL
SELECT 'GENEROS',                    COUNT(*)   FROM GENEROS               UNION ALL
SELECT 'DEPARTAMENTOS',              COUNT(*)   FROM DEPARTAMENTOS         UNION ALL
SELECT 'EMPLEADOS',                  COUNT(*)   FROM EMPLEADOS             UNION ALL
SELECT 'CONTENIDO',                  COUNT(*)   FROM CONTENIDO             UNION ALL
SELECT 'CONTENIDO_GENEROS',          COUNT(*)   FROM CONTENIDO_GENEROS     UNION ALL
SELECT 'CONTENIDO_RELACIONADO',      COUNT(*)   FROM CONTENIDO_RELACIONADO UNION ALL
SELECT 'USUARIOS',                   COUNT(*)   FROM USUARIOS              UNION ALL
SELECT 'PERFILES',                   COUNT(*)   FROM PERFILES              UNION ALL
SELECT 'PAGOS',                      COUNT(*)   FROM PAGOS                 UNION ALL
SELECT 'REPRODUCCIONES',             COUNT(*)   FROM REPRODUCCIONES        UNION ALL
SELECT 'CALIFICACIONES',             COUNT(*)   FROM CALIFICACIONES        UNION ALL
SELECT 'FAVORITOS',                  COUNT(*)   FROM FAVORITOS             UNION ALL
SELECT 'TEMPORADAS',                 COUNT(*)   FROM TEMPORADAS            UNION ALL
SELECT 'EPISODIOS',                  COUNT(*)   FROM EPISODIOS             UNION ALL
SELECT 'REPORTES_INAPROPIADO',       COUNT(*)   FROM REPORTES_INAPROPIADO
ORDER BY 1;

-- 3. Particiones de REPRODUCCIONES (deben ser 3: p_2024, p_2025, p_2026)
SELECT partition_name, tablespace_name
FROM user_tab_partitions
WHERE table_name = 'REPRODUCCIONES'
ORDER BY partition_position;