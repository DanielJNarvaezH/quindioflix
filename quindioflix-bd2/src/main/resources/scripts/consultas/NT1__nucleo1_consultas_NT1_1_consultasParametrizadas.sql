-- =============================================
-- SCRIPT MANUAL - NO EJECUTADO POR FLYWAY
-- Ejecutar en SQL Developer / SQL*Plus
-- Usa variables (&, &&, DEFINE)
-- =============================================

-- =============================================================================
-- NT1: Nucleo 1 — Consultas Avanzadas | QuindioFlix
-- Script  : V5__nucleo1_consultas.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Nota    : Este script NO se ejecuta via Flyway en produccion.
--           Flyway lo registra en flyway_schema_history para control de
--           versiones, pero las consultas se ejecutan manualmente en
--           SQL Developer / SQL*Plus donde las variables de sustitucion
--           (&, &&, DEFINE) funcionan de forma interactiva.
--           Para ejecutar en Flyway sin errores las secciones de consulta
--           estan comentadas con -- EXEC: al inicio.
-- Estructura del script:
--   NT1-1  Consultas parametrizadas (3 consultas)        — Daniel
--   NT1-2  PIVOT usuarios por ciudad y plan              — Diego
--   NT1-3  PIVOT reproducciones por categoria/dispositivo — Cristhian
--   NT1-4  UNPIVOT usuarios pivoteado                    — Daniel
--   NT1-5  UNPIVOT resumen mensual                       — Diego
--   NT1-6  ROLLUP ingresos ciudad/plan                   — Cristhian
--   NT1-7  CUBE reproducciones categoria/dispositivo     — Daniel
--   NT1-8  GROUPING SETS categoria y ciudad              — Diego
--   NT1-9  Vista materializada contenido popular         — Cristhian
--   NT1-10 Vista materializada ingresos mensuales        — Daniel
-- =============================================================================

-- Limpieza de variables de sesión (opcional)
UNDEFINE ciudad
UNDEFINE mes
UNDEFINE anio
UNDEFINE genero

-- =============================================================================
-- NT1-1: CONSULTAS PARAMETRIZADAS (3 consultas)
-- Autor   : Daniel Narvaez
-- Tema    : Variables de sustitucion Oracle: &, && y DEFINE
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus, NO via Flyway directamente.
--   En SQL Developer: Tools > Preferences > Database > SQL*Plus > Enable
--   o usar la ventana SQL Worksheet con "Run as Script" (F5).
--
-- Variables disponibles:
--   &ciudad   — ciudad de residencia del usuario (Armenia / Pereira / Manizales)
--   &mes      — numero de mes (1-12)
--   &anio     — anno de los pagos (2024, 2025, 2026...)
--   &genero   — nombre del genero (Accion / Drama / Suspenso / Comedia / etc.)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- NT1-1a: TOP 10 contenido mas reproducido por ciudad
-- Descripcion:
--   Dado el nombre de una ciudad, muestra los 10 contenidos mas reproducidos
--   por perfiles de usuarios de esa ciudad, con su total de reproducciones,
--   promedio de avance y categoria.
--   Util para personalizar el catalogo destacado por region.
--
-- Variables:
--   &ciudad  — ciudad de residencia del usuario (Armenia / Pereira / Manizales)
--
-- Ejemplo de uso en SQL*Plus / SQL Developer:
--   DEFINE ciudad = 'Armenia'
--   @V5__nucleo1_consultas.sql     (o ejecutar solo esta seccion)
--
-- Tablas involucradas:
--   REPRODUCCIONES r  -> PERFILES pe -> USUARIOS u -> ciudad_residencia
--   REPRODUCCIONES r  -> CONTENIDO c -> CATEGORIAS cat
-- -----------------------------------------------------------------------------

-- DEBUG / APOYO (opcional)
-- SELECT DISTINCT u.ciudad_residencia FROM USUARIOS ORDER BY 1;

-- Para ejecutar interactivamente descomente la siguiente linea:
--DEFINE ciudad = '&ciudad'

SELECT *
FROM (
         SELECT
             c.titulo                                        AS contenido,
             cat.nombre                                      AS categoria,
             COUNT(r.id_reproduccion)                        AS total_reproducciones,
             ROUND(AVG(r.porcentaje_avance), 1)              AS promedio_avance_pct,
             ROUND(AVG(c.popularidad), 1)                    AS popularidad_promedio,
             SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1 ELSE 0 END)
                                                             AS vistas_completas,
             ROW_NUMBER() OVER (
            ORDER BY COUNT(r.id_reproduccion) DESC,
                     AVG(r.porcentaje_avance) DESC
        )                                               AS ranking
         FROM REPRODUCCIONES r
                  JOIN PERFILES       pe  ON pe.id_perfil   = r.id_perfil
                  JOIN USUARIOS       u   ON u.id_usuario   = pe.id_usuario
                  JOIN CONTENIDO      c   ON c.id_contenido = r.id_contenido
                  JOIN CATEGORIAS     cat ON cat.id_categoria = c.id_categoria
         WHERE UPPER(u.ciudad_residencia) = UPPER('&&ciudad')
         GROUP BY
             c.titulo,
             cat.nombre,
             c.popularidad
     )
WHERE ranking <= 10
ORDER BY ranking;


-- -----------------------------------------------------------------------------
-- NT1-1b: Ingresos por plan segun mes y anno
-- Descripcion:
--   Dado un mes y un anno, calcula los ingresos totales de la plataforma
--   desglosados por plan de suscripcion (Basico, Estandar, Premium).
--   Muestra: total bruto, total descuentos otorgados, ingreso neto real
--   y cantidad de pagos exitosos vs fallidos.
--   Util para el reporte financiero mensual de Finanzas.
--
-- Variables:
--   &mes   — numero del mes (1 a 12)
--   &anio  — anno del reporte (2024, 2025, 2026...)
--
-- Ejemplo:
--   DEFINE mes  = 3
--   DEFINE anio = 2026
-- -----------------------------------------------------------------------------


-- DEBUG / APOYO (opcional)
-- SELECT EXTRACT(YEAR FROM fecha_pago), EXTRACT(MONTH FROM fecha_pago), COUNT(*)
-- FROM PAGOS GROUP BY EXTRACT(YEAR FROM fecha_pago), EXTRACT(MONTH FROM fecha_pago);

-- Para ejecutar interactivamente descomente las siguientes lineas:
--DEFINE mes  = '&mes'
--DEFINE anio = '&anio'

SELECT
    pl.nombre                                               AS plan,
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END) AS pagos_exitosos,
    COUNT(CASE WHEN pa.estado_pago = 'FALLIDO' THEN 1 END) AS pagos_fallidos,
    COUNT(CASE WHEN pa.estado_pago = 'PENDIENTE' THEN 1 END) AS pagos_pendientes,
    COUNT(CASE WHEN pa.estado_pago = 'REEMBOLSADO' THEN 1 END) AS reembolsos,
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto + (pa.monto * pa.descuento_aplicado / 100)
             ELSE 0 END)                                    AS ingreso_bruto,
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto * pa.descuento_aplicado / 100
             ELSE 0 END)                                    AS total_descuentos,
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto
             ELSE 0 END)                                    AS ingreso_neto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                    AS ticket_promedio
FROM PAGOS   pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES  pl  ON pl.id_plan   = u.id_plan
WHERE EXTRACT(MONTH FROM pa.fecha_pago) = &&mes
  AND EXTRACT(YEAR  FROM pa.fecha_pago) = &&anio
GROUP BY pl.nombre
ORDER BY
    CASE pl.nombre
    WHEN 'Basico'    THEN 1
    WHEN 'Estandar'  THEN 2
    WHEN 'Premium'   THEN 3
END;


-- -----------------------------------------------------------------------------
-- NT1-1c: Calificacion promedio por categoria para un genero dado (MEJORADO)
-- Descripcion:
--   Version optimizada usando CTE (WITH ratings) para calcular primero
--   métricas por contenido y luego agregarlas por categoria.
--   Mejora la legibilidad, evita problemas con funciones analiticas
--   y hace mas preciso el calculo del mejor contenido valorado.
--
-- Variables:
--   &genero — nombre del genero
-- -----------------------------------------------------------------------------

-- DEBUG / APOYO (opcional)
-- SELECT DISTINCT g.nombre FROM GENEROS ORDER BY g.nombre;

-- Para ejecutar interactivamente descomente la siguiente linea:
--DEFINE genero = '&genero'

WITH ratings AS (
    SELECT
        c.id_contenido,
        c.titulo,
        cat.nombre                          AS categoria,
        AVG(cal.estrellas)                  AS promedio_contenido,
        COUNT(cal.id_calificacion)          AS total_calificaciones,
        SUM(CASE WHEN cal.estrellas = 5 THEN 1 ELSE 0 END) AS estrellas_5,
        SUM(CASE WHEN cal.estrellas = 4 THEN 1 ELSE 0 END) AS estrellas_4,
        SUM(CASE WHEN cal.estrellas = 3 THEN 1 ELSE 0 END) AS estrellas_3,
        SUM(CASE WHEN cal.estrellas = 2 THEN 1 ELSE 0 END) AS estrellas_2,
        SUM(CASE WHEN cal.estrellas = 1 THEN 1 ELSE 0 END) AS estrellas_1
    FROM CALIFICACIONES cal
             JOIN CONTENIDO c        ON c.id_contenido  = cal.id_contenido
             JOIN CATEGORIAS cat     ON cat.id_categoria = c.id_categoria
             JOIN CONTENIDO_GENEROS cg ON cg.id_contenido = c.id_contenido
             JOIN GENEROS g          ON g.id_genero     = cg.id_genero
    WHERE UPPER(g.nombre) = UPPER('&&genero')
    GROUP BY c.id_contenido, c.titulo, cat.nombre
)
SELECT
    categoria,
    SUM(total_calificaciones)               AS total_calificaciones,
    ROUND(AVG(promedio_contenido), 2)       AS promedio_estrellas,
    SUM(estrellas_5)                        AS estrellas_5,
    SUM(estrellas_4)                        AS estrellas_4,
    SUM(estrellas_3)                        AS estrellas_3,
    SUM(estrellas_2)                        AS estrellas_2,
    SUM(estrellas_1)                        AS estrellas_1,
    MAX(titulo) KEEP (
        DENSE_RANK FIRST ORDER BY promedio_contenido DESC
    )                                       AS mejor_valorado
FROM ratings
GROUP BY categoria
HAVING SUM(total_calificaciones) > 0
ORDER BY promedio_estrellas DESC, total_calificaciones DESC;


-- =============================================================================
-- FIN SECCION NT1-1
-- =============================================================================
-- Las secciones NT1-2 a NT1-10 seran agregadas por Diego y Cristhian
-- en commits sucesivos sobre este mismo archivo y lo prueba de manera manual
-- en oracle sql developer.
-- =============================================================================