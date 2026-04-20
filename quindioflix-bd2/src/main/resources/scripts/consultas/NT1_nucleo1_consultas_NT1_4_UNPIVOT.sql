-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_4_UNPIVOT.sql
-- Autor   : Daniel Narvaez
-- Nucleo  : NT1-4 — UNPIVOT usuarios pivoteados a filas normalizadas
--
-- DESCRIPCION:
--   Toma el resultado del reporte PIVOT de NT1-2 (usuarios activos por ciudad
--   y plan, con columnas BASICO, ESTANDAR, PREMIUM) y lo convierte de nuevo a
--   formato normalizado de filas: una fila por cada combinacion ciudad/plan.
--
--   Resultado del PIVOT origen (NT1-2):
--     CIUDAD_RESIDENCIA | BASICO_USUARIOS | ESTANDAR_USUARIOS | PREMIUM_USUARIOS
--     Armenia           |       12        |         4         |        0
--     Manizales         |        0        |         0         |        5
--     Pereira           |        0        |         9         |        0
--
--   Resultado de este UNPIVOT (NT1-4):
--     CIUDAD_RESIDENCIA | PLAN     | CANTIDAD_USUARIOS
--     Armenia           | Basico   | 12
--     Armenia           | Estandar |  4
--     Manizales         | Premium  |  5
--     Pereira           | Estandar |  9
--
--   Utilidad:
--     El formato normalizado es mas flexible para analisis de tendencias,
--     filtros por plan especifico y como fuente de datos para graficos.
--     Complementa al PIVOT mostrando que ambas transformaciones son inversas.
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   No usa variables de sustitucion — es una consulta estatica de reporte.
--   Compatible con Flyway (sin variables & ni &&).
-- =============================================================================


-- =============================================================================
-- NT1-4: UNPIVOT — Usuarios activos por ciudad y plan (formato normalizado)
-- Origen  : resultado del PIVOT de NT1-2 embebido como subconsulta
-- Destino : ciudad_residencia | plan | cantidad_usuarios
-- Filtro  : solo combinaciones con al menos 1 usuario activo (cantidad > 0)
-- =============================================================================

SELECT
    ciudad_residencia   AS ciudad,
    plan,
    cantidad_usuarios
FROM (
         -- Subconsulta: replica el PIVOT de NT1-2
         -- Genera las columnas BASICO, ESTANDAR, PREMIUM como origen del UNPIVOT
         SELECT *
         FROM (
                  SELECT
                      u.ciudad_residencia,
                      p.nombre AS plan
                  FROM USUARIOS u
                           JOIN PLANES p ON p.id_plan = u.id_plan
                  WHERE u.estado_cuenta = 'ACTIVO'
              )
                  PIVOT (
                         COUNT(*) AS usuarios
        FOR plan IN (
            'Basico'   AS "BASICO",
            'Estandar' AS "ESTANDAR",
            'Premium'  AS "PREMIUM"
        )
                 )
     )
         -- UNPIVOT referencia los nombres reales que Oracle genera: BASICO_USUARIOS,
-- ESTANDAR_USUARIOS, PREMIUM_USUARIOS (el PIVOT concatena alias + _USUARIOS)
         UNPIVOT (
                  cantidad_usuarios
                      FOR plan IN (
        "BASICO_USUARIOS"   AS 'Basico',
        "ESTANDAR_USUARIOS" AS 'Estandar',
        "PREMIUM_USUARIOS"  AS 'Premium'
    )
        )
WHERE cantidad_usuarios > 0
ORDER BY
    ciudad_residencia,
    CASE plan
        WHEN 'Basico'   THEN 1
        WHEN 'Estandar' THEN 2
        WHEN 'Premium'  THEN 3
        END;


-- =============================================================================
-- RESULTADO ESPERADO con los datos de prueba asimetricos (V4):
--
--   CIUDAD      | PLAN     | CANTIDAD_USUARIOS
--   ------------|----------|------------------
--   Armenia     | Basico   | 13
--   Manizales   | Premium  |  5
--   Pereira     | Estandar |  9
--
-- Solo aparecen las combinaciones con usuarios — las celdas en 0 se eliminan
-- con el WHERE cantidad_usuarios > 0, demostrando el filtrado post-UNPIVOT.
--
-- VERIFICACION RAPIDA en SQL Developer:
--   Ejecutar primero el PIVOT de NT1-2 y comparar que la suma de cada columna
--   coincide con la suma de cantidad_usuarios de este UNPIVOT por plan:
--     SELECT plan, SUM(cantidad_usuarios) FROM (...este query...) GROUP BY plan;
-- =============================================================================