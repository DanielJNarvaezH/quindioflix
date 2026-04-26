-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_6_ROLLUP.sql
-- Autores : Equipo QuindioFlix
-- Nucleo  : NT1-6 — ROLLUP ingresos por ciudad y plan con subtotales
--
-- DESCRIPCION:
--   Calcula los ingresos de pagos EXITOSOS del ano 2024 agrupados por
--   ciudad de residencia y plan de suscripcion usando GROUP BY ROLLUP.
--
--   ROLLUP(ciudad_residencia, nombre_plan) produce 3 niveles:
--     1. (ciudad, plan)  — DETALLE: ingreso por ciudad + plan especifico
--     2. (ciudad, NULL)  — SUBTOTAL CIUDAD: ingreso total de la ciudad
--     3. (NULL,  NULL)   — GRAN TOTAL: ingreso total de todos los pagos
--
--   NOTA: ROLLUP es jerarquico y unidireccional (ciudad -> plan).
--   No produce el nivel (NULL, plan) — ese caso corresponde a CUBE o
--   a GROUPING SETS. Ver NT1-7 (Daniel) y NT1-8 para esas tecnicas.
--
--   Metricas calculadas (alineadas con NT1-1b de Daniel):
--     pagos_exitosos  : cantidad de transacciones cobradas
--     ingreso_neto    : SUM(monto) — monto ya es post-descuento en el seed
--     ingreso_bruto   : ingreso_neto + descuentos = monto antes del descuento
--     total_descuentos: monto total de descuentos otorgados
--     ticket_promedio : ingreso_neto / pagos_exitosos (redondeado)
--
--   Tablas involucradas:
--     PAGOS pa -> USUARIOS u -> PLANES pl
--     (mismo JOIN path que NT1-1b de Daniel)
--
--   Relacion con otros scripts NT1:
--     NT1-1b (Daniel): mismas metricas financieras por mes/plan.
--     NT1-5  (Diego) : UNPIVOT de ingresos mensuales 2024.
--     Verificacion cruzada: ingreso_neto GRAN TOTAL de NT1-6 debe
--     coincidir con SUM(monto) de todos los pagos EXITOSOS de 2024.
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   No usa variables de sustitucion — consulta estatica de reporte.
--   Compatible con Flyway (sin variables & ni &&).
-- =============================================================================


-- =============================================================================
-- NT1-6: ROLLUP ingresos por ciudad y plan — pagos EXITOSOS del ano 2024
--
-- Resultado: 7 filas
--   - 3 filas DETALLE        (Armenia/Basico, Manizales/Premium, Pereira/Estandar)
--   - 3 filas SUBTOTAL CIUDAD (una por cada ciudad)
--   - 1 fila  GRAN TOTAL
--
-- Etiquetas GROUPING (coherentes con NT1-7 de Daniel):
--   ciudad NULL -> '*** TOTAL GENERAL ***'
--   plan   NULL con ciudad real -> '** SUBTOTAL CIUDAD **'
--   plan   NULL con ciudad NULL -> '** TODOS LOS PLANES **'
-- =============================================================================

SELECT
    -- Ciudad: reemplaza NULL de ROLLUP con etiqueta legible
    CASE GROUPING(u.ciudad_residencia)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE        u.ciudad_residencia
    END                                                              AS ciudad,

    -- Plan: distingue subtotal-ciudad del gran total
    CASE
        WHEN GROUPING(u.ciudad_residencia) = 1
         AND GROUPING(pl.nombre)           = 1 THEN '** TODOS LOS PLANES **'
        WHEN GROUPING(pl.nombre)           = 1 THEN '** SUBTOTAL CIUDAD **'
        ELSE                                        pl.nombre
    END                                                              AS plan,

    -- Metricas financieras (misma formula que NT1-1b de Daniel)
    COUNT(pa.id_pago)                                                AS pagos_exitosos,
    NVL(SUM(pa.monto), 0)                                            AS ingreso_neto,
    -- ingreso_bruto: monto neto + descuento recuperado = precio original
    NVL(SUM(pa.monto + pa.monto * pa.descuento_aplicado / 100), 0)  AS ingreso_bruto,
    NVL(SUM(pa.monto * pa.descuento_aplicado / 100), 0)             AS total_descuentos,
    ROUND(
        NVL(SUM(pa.monto), 0) / NULLIF(COUNT(pa.id_pago), 0)
    , 0)                                                             AS ticket_promedio,

    -- Nivel de agregacion para filtrado downstream
    CASE
        WHEN GROUPING(u.ciudad_residencia) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(pl.nombre)           = 1 THEN 'SUBTOTAL CIUDAD'
        ELSE                                        'DETALLE'
    END                                                              AS nivel_agregacion

FROM PAGOS    pa
    JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
    JOIN PLANES   pl ON pl.id_plan   = u.id_plan

-- Filtro critico: usar 'EXITOSO' (post V4.1, no 'APROBADO')
WHERE pa.estado_pago = 'EXITOSO'
  AND EXTRACT(YEAR FROM pa.fecha_pago) = 2024

GROUP BY ROLLUP(u.ciudad_residencia, pl.nombre)

ORDER BY
    -- Primero DETALLE (0,0), luego SUBTOTAL CIUDAD (0,1), luego GRAN TOTAL (1,1)
    GROUPING(u.ciudad_residencia),
    GROUPING(pl.nombre),
    u.ciudad_residencia NULLS LAST,
    CASE pl.nombre
        WHEN 'Basico'   THEN 1
        WHEN 'Estandar' THEN 2
        WHEN 'Premium'  THEN 3
        ELSE 99
    END NULLS LAST;


-- =============================================================================
-- RESULTADO ESPERADO (datos seed V4 — 80 pagos 2024, ciudad alineada con plan)
--
-- Distribucion del seed:
--   Armenia   -> 14 usuarios, plan Basico   ($14.900/mes)
--   Pereira   -> 10 usuarios, plan Estandar ($24.900/mes)
--   Manizales ->  6 usuarios, plan Premium  ($34.900/mes)
--
-- Estructura de las 7 filas (orden garantizado por ORDER BY):
--
--   CIUDAD               | PLAN                  | PAGOS | INGRESO_NETO | NIVEL
--   ---------------------|----------------------|-------|-------------|--------
--   Armenia              | Basico                |    XX |          XX | DETALLE
--   Manizales            | Premium               |    XX |          XX | DETALLE
--   Pereira              | Estandar              |    XX |          XX | DETALLE
--   Armenia              | ** SUBTOTAL CIUDAD ** |    XX |          XX | SUBTOTAL CIUDAD
--   Manizales            | ** SUBTOTAL CIUDAD ** |    XX |          XX | SUBTOTAL CIUDAD
--   Pereira              | ** SUBTOTAL CIUDAD ** |    XX |          XX | SUBTOTAL CIUDAD
--   *** TOTAL GENERAL ***| ** TODOS LOS PLANES **|    XX |          XX | GRAN TOTAL
--
-- NOTA: Como cada ciudad tiene exactamente un plan en el seed, las filas
-- DETALLE y SUBTOTAL CIUDAD de cada ciudad tienen los mismos valores.
-- Esto es correcto — es la consecuencia natural de la distribucion del seed,
-- no un error en la consulta.
--
-- ROLLUP NO produce el nivel (NULL, plan) — ese nivel solo aparece con CUBE
-- o GROUPING SETS. Es el comportamiento esperado de ROLLUP jerarquico.
--
-- VERIFICACION RAPIDA:
--   SELECT SUM(monto) FROM PAGOS WHERE estado_pago='EXITOSO'
--     AND EXTRACT(YEAR FROM fecha_pago) = 2024;
--   -- debe coincidir con ingreso_neto en la fila 'GRAN TOTAL'
--
--   Verificacion cruzada con NT1-1b (Daniel):
--   La suma de ingreso_neto por plan a lo largo de los 12 meses de NT1-1b
--   (DEFINE mes=1..12, anio=2024) debe coincidir con la fila GRAN TOTAL
--   de este script.
-- =============================================================================
