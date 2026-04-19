-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : R__nucleo1_consultas.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Nucleo  : NT1 — PIVOT, UNPIVOT, ROLLUP, CUBE, GROUPING SETS,
--           Vistas Materializadas, Consultas Parametrizadas
-- Nota    : Script repetible (prefijo R). Flyway lo ejecuta sin validar
--           checksums de versiones anteriores. Los SELECT de reporte no
--           modifican datos y son inocuos ante re-ejecuciones.
-- =============================================================================
-- =============================================================================
-- NT1-2: PIVOT — Reporte de usuarios activos por ciudad y plan
-- Filas    : ciudades (Armenia, Pereira, Manizales)
-- Columnas : planes (Basico, Estandar, Premium)
-- Valores  : cantidad de usuarios con estado_cuenta = 'ACTIVO'
-- =============================================================================
SELECT *
FROM (
         SELECT u.ciudad_residencia,
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
ORDER BY ciudad_residencia;

-- =============================================================================
-- NT1-5: UNPIVOT — Convertir resumen mensual de ingresos a filas
-- Origen  : tabla pivoteada con columnas Enero..Diciembre por ciudad
-- Destino : ciudad | mes | ingresos  (formato normalizado para tendencias)
-- Datos   : ingresos de pagos EXITOSOS del año 2024
-- =============================================================================
SELECT ciudad_residencia,
       mes,
       ingresos
FROM (
         SELECT u.ciudad_residencia,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 1  THEN p.monto END), 0) AS Enero,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 2  THEN p.monto END), 0) AS Febrero,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 3  THEN p.monto END), 0) AS Marzo,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 4  THEN p.monto END), 0) AS Abril,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 5  THEN p.monto END), 0) AS Mayo,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 6  THEN p.monto END), 0) AS Junio,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 7  THEN p.monto END), 0) AS Julio,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 8  THEN p.monto END), 0) AS Agosto,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 9  THEN p.monto END), 0) AS Septiembre,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 10 THEN p.monto END), 0) AS Octubre,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 11 THEN p.monto END), 0) AS Noviembre,
                NVL(SUM(CASE WHEN EXTRACT(MONTH FROM p.fecha_pago) = 12 THEN p.monto END), 0) AS Diciembre
         FROM PAGOS p
                  JOIN USUARIOS u ON u.id_usuario = p.id_usuario
         WHERE p.estado_pago = 'EXITOSO'
           AND EXTRACT(YEAR FROM p.fecha_pago) = 2024
         GROUP BY u.ciudad_residencia
     )
         UNPIVOT INCLUDE NULLS (
    ingresos FOR mes IN (
        Enero, Febrero, Marzo, Abril, Mayo, Junio,
        Julio, Agosto, Septiembre, Octubre, Noviembre, Diciembre
    )
)
WHERE ingresos > 0
ORDER BY ciudad_residencia,
    CASE mes
    WHEN 'ENERO'      THEN 1
    WHEN 'FEBRERO'    THEN 2
    WHEN 'MARZO'      THEN 3
    WHEN 'ABRIL'      THEN 4
    WHEN 'MAYO'       THEN 5
    WHEN 'JUNIO'      THEN 6
    WHEN 'JULIO'      THEN 7
    WHEN 'AGOSTO'     THEN 8
    WHEN 'SEPTIEMBRE' THEN 9
    WHEN 'OCTUBRE'    THEN 10
    WHEN 'NOVIEMBRE'  THEN 11
    WHEN 'DICIEMBRE'  THEN 12
END;

