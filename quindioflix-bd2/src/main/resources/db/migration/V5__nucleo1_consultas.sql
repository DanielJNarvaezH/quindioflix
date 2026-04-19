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