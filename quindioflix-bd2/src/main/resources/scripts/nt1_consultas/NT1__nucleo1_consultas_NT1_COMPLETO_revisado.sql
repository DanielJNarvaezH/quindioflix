-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1__nucleo1_consultas_NT1_COMPLETO_revisado.sql
-- Runner  : manual en la bd local de oracle de cada uno
-- Autores : Daniel Narvaez, Diego Garcia, Cristhian Osorio
-- Nucleo  : NT1 — Consultas Parametrizadas, PIVOT, UNPIVOT, ROLLUP,
--           CUBE, GROUPING SETS, Vistas Materializadas
--
-- NOTA DE EJECUCION:
--   Este script es un reporte — contiene SELECT y bloques PL/SQL para
--   vistas materializadas. Se ejecuta manualmente en SQL Developer
--   con Run as Script (F5). Flyway lo registra para control de versiones
--   pero los SELECT son inocuos ante re-ejecuciones.
--
--   Las consultas NT1-1a/b/c usan variables de sustitucion (&&).
--   Para ejecutarlas interactivamente, descomentar las lineas DEFINE
--   al inicio de cada seccion o definirlas antes de ejecutar:
--     DEFINE ciudad  = 'Armenia'
--     DEFINE mes     = 3
--     DEFINE anio    = 2024
--     DEFINE genero  = 'Drama'
--
-- Estructura:
--   NT1-1  Consultas parametrizadas (3)     — Daniel Narvaez
--   NT1-2  PIVOT usuarios por ciudad/plan   — Diego Garcia
--   NT1-3  PIVOT reproducciones cat/disp    — Cristhian Osorio
--   NT1-4  UNPIVOT usuarios pivoteados      — Daniel Narvaez
--   NT1-5  UNPIVOT resumen mensual          — Diego Garcia
--   NT1-6  ROLLUP ingresos ciudad/plan      — Cristhian Osorio
--   NT1-7  CUBE reproducciones cat/disp     — Daniel Narvaez
--   NT1-8  GROUPING SETS cat y ciudad       — Diego Garcia
--   NT1-9  MV contenido mas popular         — Cristhian Osorio
--   NT1-10 MV ingresos mensuales            — Daniel Narvaez
-- =============================================================================

-- Limpieza de variables de sesion (opcional, evita residuos de sesiones previas)
UNDEFINE ciudad
UNDEFINE mes
UNDEFINE anio
UNDEFINE genero


-- =============================================================================
-- NT1-1: CONSULTAS PARAMETRIZADAS
-- Autor  : Daniel Narvaez
-- Tema   : Variables de sustitucion Oracle (&, &&, DEFINE)
-- Nota   : Ejecutar en SQL Developer con Run as Script (F5).
--          En SQL*Plus las variables se piden interactivamente.
--          En SQL Developer: descomentar las lineas DEFINE antes de ejecutar.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- NT1-1a: TOP 10 contenido mas reproducido por ciudad
-- Dado el nombre de una ciudad, muestra los 10 contenidos mas reproducidos
-- por perfiles de usuarios de esa ciudad. Incluye total de reproducciones,
-- promedio de avance, popularidad y vistas completas (avance >= 90%).
-- Util para personalizar el catalogo destacado por region.
--
-- Variable: &&ciudad — ciudad de residencia (Armenia / Pereira / Manizales)
-- Ejemplo : DEFINE ciudad = 'Armenia'
-- -----------------------------------------------------------------------------

-- DEFINE ciudad = '&&ciudad'

SELECT *
FROM (
         SELECT
             c.titulo                                            AS contenido,
             cat.nombre                                          AS categoria,
             COUNT(r.id_reproduccion)                            AS total_reproducciones,
             ROUND(AVG(r.porcentaje_avance), 1)                  AS promedio_avance_pct,
             ROUND(AVG(c.popularidad), 1)                        AS popularidad_promedio,
             SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1
                      ELSE 0 END)                                AS vistas_completas,
             ROW_NUMBER() OVER (
            ORDER BY COUNT(r.id_reproduccion) DESC,
                     AVG(r.porcentaje_avance)  DESC
        )                                                   AS ranking
         FROM REPRODUCCIONES r
                  JOIN PERFILES   pe  ON pe.id_perfil    = r.id_perfil
                  JOIN USUARIOS   u   ON u.id_usuario    = pe.id_usuario
                  JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
                  JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
         WHERE UPPER(u.ciudad_residencia) = UPPER('&&ciudad')
         GROUP BY c.titulo, cat.nombre, c.popularidad
     )
WHERE ranking <= 10
ORDER BY ranking;


-- -----------------------------------------------------------------------------
-- NT1-1b: Ingresos por plan segun mes y anno
-- Dado un mes y un anno, calcula los ingresos desglosados por plan:
-- total bruto, descuentos otorgados, ingreso neto, ticket promedio y
-- conteo de pagos por estado. Util para el reporte financiero mensual.
--
-- Variables: &&mes (1-12), &&anio (2024 / 2025 / 2026)
-- Ejemplo  : DEFINE mes = 3    DEFINE anio = 2024
-- -----------------------------------------------------------------------------

-- DEFINE mes  = '&&mes'
-- DEFINE anio = '&&anio'

SELECT
    pl.nombre                                                   AS plan,
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO'    THEN 1 END)  AS pagos_exitosos,
    COUNT(CASE WHEN pa.estado_pago = 'FALLIDO'    THEN 1 END)  AS pagos_fallidos,
    COUNT(CASE WHEN pa.estado_pago = 'PENDIENTE'  THEN 1 END)  AS pagos_pendientes,
    COUNT(CASE WHEN pa.estado_pago = 'REEMBOLSADO'THEN 1 END)  AS reembolsos,
    -- Ingreso bruto: reconstruye el precio antes del descuento
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto + (pa.monto * pa.descuento_aplicado / 100)
             ELSE 0 END)                                        AS ingreso_bruto,
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto * pa.descuento_aplicado / 100
             ELSE 0 END)                                        AS total_descuentos,
    -- Ingreso neto: monto ya descontado (lo que QuindioFlix recibe realmente)
    SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                 THEN pa.monto
             ELSE 0 END)                                        AS ingreso_neto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                        AS ticket_promedio
FROM PAGOS   pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
WHERE EXTRACT(MONTH FROM pa.fecha_pago) = &&mes
  AND EXTRACT(YEAR  FROM pa.fecha_pago) = &&anio
GROUP BY pl.nombre
ORDER BY
    CASE pl.nombre
    WHEN 'Basico'   THEN 1
    WHEN 'Estandar' THEN 2
    WHEN 'Premium'  THEN 3
END;


-- -----------------------------------------------------------------------------
-- NT1-1c: Calificacion promedio por categoria para un genero dado
-- Dado un genero, muestra el promedio de estrellas por categoria,
-- distribucion de puntuaciones (1 a 5) y el contenido mejor valorado
-- de cada categoria. Util para analizar calidad percibida por genero.
-- Usa CTE (WITH) para pre-agregar por contenido antes de agrupar
-- por categoria, evitando conteos inflados por JOINs multiples.
--
-- Variable: &&genero — nombre del genero (Drama / Accion / Suspenso / etc.)
-- Ejemplo : DEFINE genero = 'Drama'
-- -----------------------------------------------------------------------------

-- DEFINE genero = '&&genero'

WITH ratings AS (
    -- Pre-agrega metricas por contenido antes de agrupar por categoria
    SELECT
        c.id_contenido,
        c.titulo,
        cat.nombre                                          AS categoria,
        AVG(cal.estrellas)                                  AS promedio_contenido,
        COUNT(cal.id_calificacion)                          AS total_calificaciones,
        SUM(CASE WHEN cal.estrellas = 5 THEN 1 ELSE 0 END) AS estrellas_5,
        SUM(CASE WHEN cal.estrellas = 4 THEN 1 ELSE 0 END) AS estrellas_4,
        SUM(CASE WHEN cal.estrellas = 3 THEN 1 ELSE 0 END) AS estrellas_3,
        SUM(CASE WHEN cal.estrellas = 2 THEN 1 ELSE 0 END) AS estrellas_2,
        SUM(CASE WHEN cal.estrellas = 1 THEN 1 ELSE 0 END) AS estrellas_1
    FROM CALIFICACIONES   cal
             JOIN CONTENIDO        c   ON c.id_contenido   = cal.id_contenido
             JOIN CATEGORIAS       cat ON cat.id_categoria  = c.id_categoria
             JOIN CONTENIDO_GENEROS cg ON cg.id_contenido  = c.id_contenido
             JOIN GENEROS          g   ON g.id_genero       = cg.id_genero
    WHERE UPPER(g.nombre) = UPPER('&&genero')
    GROUP BY c.id_contenido, c.titulo, cat.nombre
)
SELECT
    categoria,
    SUM(total_calificaciones)                               AS total_calificaciones,
    ROUND(AVG(promedio_contenido), 2)                       AS promedio_estrellas,
    SUM(estrellas_5)                                        AS estrellas_5,
    SUM(estrellas_4)                                        AS estrellas_4,
    SUM(estrellas_3)                                        AS estrellas_3,
    SUM(estrellas_2)                                        AS estrellas_2,
    SUM(estrellas_1)                                        AS estrellas_1,
    -- KEEP: obtiene el titulo del contenido con mayor promedio por categoria
    MAX(titulo) KEEP (
        DENSE_RANK FIRST ORDER BY promedio_contenido DESC
    )                                                       AS mejor_valorado
FROM ratings
GROUP BY categoria
HAVING SUM(total_calificaciones) > 0
ORDER BY promedio_estrellas DESC, total_calificaciones DESC;


-- =============================================================================
-- NT1-2: PIVOT — Reporte de usuarios activos por ciudad y plan
-- Autor  : Diego Garcia
-- Filas  : ciudades de residencia (Armenia, Pereira, Manizales)
-- Columnas: planes de suscripcion (Basico, Estandar, Premium)
-- Valores: cantidad de usuarios con estado_cuenta = 'ACTIVO'
-- Uso    : permite comparar de forma visual la distribucion de usuarios
--          por zona geografica y segmento de plan en una sola tabla.
-- =============================================================================

SELECT *
FROM (
         -- Subconsulta fuente: proyecta ciudad y plan por usuario activo
         SELECT
             u.ciudad_residencia,
             p.nombre AS plan
         FROM USUARIOS u
                  JOIN PLANES p ON p.id_plan = u.id_plan
         WHERE u.estado_cuenta = 'ACTIVO'
     )
         PIVOT (
        -- PIVOT gira los valores de 'plan' a columnas, contando usuarios por celda
                COUNT(*) AS usuarios
    FOR plan IN (
        'Basico'   AS "BASICO",
        'Estandar' AS "ESTANDAR",
        'Premium'  AS "PREMIUM"
    )
        )
ORDER BY ciudad_residencia;


-- =============================================================================
-- NT1-3: PIVOT — Reproducciones por categoria y dispositivo
-- Autor  : Cristhian Osorio
-- Filas  : categorias de contenido (Peliculas, Series, Documentales, etc.)
-- Columnas: dispositivos (CELULAR, TABLET, TV, COMPUTADOR) + total
-- NT1-3a: tabla de contingencia pura (5 filas x 5 columnas)
-- NT1-3b: igual que NT1-3a + fila de totales por dispositivo (6 filas)
-- Uso    : compara patrones de consumo por tipo de contenido y dispositivo.
--          Permite identificar si los usuarios prefieren ver series en TV
--          y podcasts en celular, por ejemplo.
-- =============================================================================

-- NT1-3a: PIVOT puro — tabla de contingencia categoria x dispositivo
-- NVL convierte NULL a 0 cuando no hay reproducciones para una combinacion.
SELECT
    categoria,
    NVL(CELULAR_REPRODUCCIONES,    0) AS celular_reproducciones,
    NVL(TABLET_REPRODUCCIONES,     0) AS tablet_reproducciones,
    NVL(TV_REPRODUCCIONES,         0) AS tv_reproducciones,
    NVL(COMPUTADOR_REPRODUCCIONES, 0) AS computador_reproducciones,
    NVL(CELULAR_REPRODUCCIONES,    0)
        + NVL(TABLET_REPRODUCCIONES,     0)
        + NVL(TV_REPRODUCCIONES,         0)
        + NVL(COMPUTADOR_REPRODUCCIONES, 0) AS total_categoria
FROM (
         -- Subconsulta: solo 3 columnas para que el PIVOT agrupe correctamente
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
ORDER BY
    CASE categoria
        WHEN 'Peliculas'    THEN 1
        WHEN 'Series'       THEN 2
        WHEN 'Documentales' THEN 3
        WHEN 'Musica'       THEN 4
        WHEN 'Podcasts'     THEN 5
        ELSE 99
        END;


-- NT1-3b: PIVOT + fila TOTAL DISPOSITIVO via UNION ALL
-- El bloque B suma directamente desde REPRODUCCIONES (sin PIVOT) para
-- demostrar que ambas fuentes producen el mismo gran total (200).
SELECT
    categoria,
    celular_reproducciones,
    tablet_reproducciones,
    tv_reproducciones,
    computador_reproducciones,
    total_categoria
FROM (
         -- Bloque A: filas de detalle por categoria (mismo PIVOT que NT1-3a)
         SELECT
             categoria,
             NVL(CELULAR_REPRODUCCIONES,    0) AS celular_reproducciones,
             NVL(TABLET_REPRODUCCIONES,     0) AS tablet_reproducciones,
             NVL(TV_REPRODUCCIONES,         0) AS tv_reproducciones,
             NVL(COMPUTADOR_REPRODUCCIONES, 0) AS computador_reproducciones,
             NVL(CELULAR_REPRODUCCIONES,    0)
                 + NVL(TABLET_REPRODUCCIONES,     0)
                 + NVL(TV_REPRODUCCIONES,         0)
                 + NVL(COMPUTADOR_REPRODUCCIONES, 0) AS total_categoria,
             CASE categoria
                 WHEN 'Peliculas'    THEN 1
                 WHEN 'Series'       THEN 2
                 WHEN 'Documentales' THEN 3
                 WHEN 'Musica'       THEN 4
                 WHEN 'Podcasts'     THEN 5
                 ELSE 99
                 END AS orden_fila
         FROM (
                  SELECT cat.nombre AS categoria, r.dispositivo, r.id_reproduccion
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

         -- Bloque B: fila de totales por dispositivo
         -- Verificacion: total_categoria debe coincidir con COUNT(*) FROM REPRODUCCIONES
         SELECT
             '*** TOTAL DISPOSITIVO ***'                                    AS categoria,
             SUM(CASE WHEN r.dispositivo = 'CELULAR'    THEN 1 ELSE 0 END) AS celular_reproducciones,
             SUM(CASE WHEN r.dispositivo = 'TABLET'     THEN 1 ELSE 0 END) AS tablet_reproducciones,
             SUM(CASE WHEN r.dispositivo = 'TV'         THEN 1 ELSE 0 END) AS tv_reproducciones,
             SUM(CASE WHEN r.dispositivo = 'COMPUTADOR' THEN 1 ELSE 0 END) AS computador_reproducciones,
             COUNT(r.id_reproduccion)                                       AS total_categoria,
             100                                                            AS orden_fila
         FROM REPRODUCCIONES r
     )
ORDER BY orden_fila, categoria;


-- =============================================================================
-- NT1-4: UNPIVOT — Usuarios activos por ciudad y plan (formato normalizado)
-- Autor  : Daniel Narvaez
-- Origen : resultado del PIVOT de NT1-2 embebido como subconsulta
-- Destino: ciudad | plan | cantidad_usuarios (una fila por combinacion)
-- Filtro : solo combinaciones con al menos 1 usuario (cantidad > 0)
-- Uso    : el formato normalizado es mas flexible para analisis de tendencias,
--          filtros por plan especifico y como fuente de datos para graficos.
--          Demuestra que PIVOT y UNPIVOT son transformaciones inversas.
-- =============================================================================

SELECT
    ciudad_residencia AS ciudad,
    plan,
    cantidad_usuarios
FROM (
         -- Subconsulta: replica el PIVOT de NT1-2 como fuente del UNPIVOT
         SELECT *
         FROM (
                  SELECT u.ciudad_residencia, p.nombre AS plan
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
-- UNPIVOT referencia los nombres que Oracle genera al pivotar: BASICO_USUARIOS, etc.
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
-- NT1-5: UNPIVOT — Resumen mensual de ingresos a filas normalizadas
-- Autor  : Diego Garcia
-- Origen : tabla pivoteada con columnas Enero..Diciembre agrupada por ciudad
-- Destino: ciudad | mes | ingresos (una fila por mes con actividad)
-- Filtro : pagos EXITOSOS del anno 2024, solo meses con ingresos > 0
-- Uso    : el formato normalizado permite analisis de tendencias temporales,
--          graficos de linea por ciudad y deteccion de meses pico/valle.
--          INCLUDE NULLS evita que UNPIVOT descarte los ceros del NVL,
--          y el WHERE ingresos > 0 final filtra los meses sin actividad.
-- =============================================================================

SELECT
    ciudad_residencia,
    mes,
    ingresos
FROM (
         -- Subconsulta: construye el resumen mensual pivoteado por ciudad
         SELECT
             u.ciudad_residencia,
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
-- INCLUDE NULLS necesario porque NVL genera 0 (no NULL) y UNPIVOT excluye 0 por defecto
         UNPIVOT INCLUDE NULLS (
    ingresos FOR mes IN (
        Enero, Febrero, Marzo, Abril, Mayo, Junio,
        Julio, Agosto, Septiembre, Octubre, Noviembre, Diciembre
    )
)
WHERE ingresos > 0
ORDER BY
    ciudad_residencia,
    CASE mes
    WHEN 'ENERO'      THEN 1  WHEN 'FEBRERO'    THEN 2
    WHEN 'MARZO'      THEN 3  WHEN 'ABRIL'      THEN 4
    WHEN 'MAYO'       THEN 5  WHEN 'JUNIO'      THEN 6
    WHEN 'JULIO'      THEN 7  WHEN 'AGOSTO'     THEN 8
    WHEN 'SEPTIEMBRE' THEN 9  WHEN 'OCTUBRE'    THEN 10
    WHEN 'NOVIEMBRE'  THEN 11 WHEN 'DICIEMBRE'  THEN 12
END;


-- =============================================================================
-- NT1-6: ROLLUP — Ingresos por ciudad y plan con subtotales jerarquicos
-- Autor  : Cristhian Osorio
-- Datos  : pagos EXITOSOS del anno 2024
-- ROLLUP(ciudad, plan) produce 3 niveles jerarquicos:
--   DETALLE        : ingreso por ciudad + plan especifico
--   SUBTOTAL CIUDAD: ingreso total de la ciudad (todos sus planes)
--   GRAN TOTAL     : ingreso total de todos los pagos del periodo
-- Diferencia con CUBE: ROLLUP es jerarquico y unidireccional.
--   No produce el nivel (NULL, plan) — ese nivel solo aparece con CUBE.
-- Metricas alineadas con NT1-1b para verificacion cruzada.
-- =============================================================================

SELECT
    -- Etiqueta legible para filas de subtotal y gran total
    CASE GROUPING(u.ciudad_residencia)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE        u.ciudad_residencia
        END                                                         AS ciudad,
    CASE
        WHEN GROUPING(u.ciudad_residencia) = 1
            AND GROUPING(pl.nombre)           = 1 THEN '** TODOS LOS PLANES **'
        WHEN GROUPING(pl.nombre)           = 1 THEN '** SUBTOTAL CIUDAD **'
        ELSE                                        pl.nombre
        END                                                         AS plan,
    COUNT(pa.id_pago)                                           AS pagos_exitosos,
    NVL(SUM(pa.monto), 0)                                       AS ingreso_neto,
    NVL(SUM(pa.monto + pa.monto * pa.descuento_aplicado / 100), 0) AS ingreso_bruto,
    NVL(SUM(pa.monto * pa.descuento_aplicado / 100), 0)         AS total_descuentos,
    ROUND(
            NVL(SUM(pa.monto), 0) / NULLIF(COUNT(pa.id_pago), 0)
        , 0)                                                        AS ticket_promedio,
    -- Columna auxiliar para filtrado y comprension del nivel de agregacion
    CASE
        WHEN GROUPING(u.ciudad_residencia) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(pl.nombre)           = 1 THEN 'SUBTOTAL CIUDAD'
        ELSE                                        'DETALLE'
        END                                                         AS nivel_agregacion
FROM PAGOS    pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
WHERE pa.estado_pago = 'EXITOSO'
  AND EXTRACT(YEAR FROM pa.fecha_pago) = 2024
GROUP BY ROLLUP(u.ciudad_residencia, pl.nombre)
ORDER BY
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
-- NT1-7: CUBE — Reproducciones por categoria y dispositivo
-- Autor  : Daniel Narvaez
-- CUBE(categoria, dispositivo) produce 2^2 = 4 niveles de agregacion:
--   DETALLE             : categoria + dispositivo (cruce completo)
--   SUBTOTAL CATEGORIA  : total por categoria en todos los dispositivos
--   SUBTOTAL DISPOSITIVO: total por dispositivo en todas las categorias
--   GRAN TOTAL          : todas las reproducciones sin distincion
-- Diferencia con ROLLUP: ROLLUP es jerarquico (solo niveles padre-hijo).
--   CUBE genera TODAS las combinaciones posibles de agrupacion.
-- NT1-7a usa GROUP BY CUBE directamente.
-- NT1-7b demuestra que CUBE es equivalente a GROUPING SETS expandido.
-- =============================================================================

-- NT1-7a: CUBE directo — sintaxis compacta
SELECT
    CASE GROUPING(cat.nombre)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE        cat.nombre
        END                                                         AS categoria,
    CASE GROUPING(r.dispositivo)
        WHEN 1 THEN '** TODOS LOS DISPOSITIVOS **'
        ELSE        r.dispositivo
        END                                                         AS dispositivo,
    COUNT(r.id_reproduccion)                                    AS total_reproducciones,
    ROUND(AVG(r.porcentaje_avance), 1)                          AS promedio_avance_pct,
    SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1 ELSE 0 END)  AS vistas_completas,
    CASE
        WHEN GROUPING(cat.nombre) = 1
            AND GROUPING(r.dispositivo) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(cat.nombre)    = 1 THEN 'SUBTOTAL DISPOSITIVO'
        WHEN GROUPING(r.dispositivo) = 1 THEN 'SUBTOTAL CATEGORIA'
        ELSE                                  'DETALLE'
        END                                                         AS nivel_agregacion
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
GROUP BY CUBE(cat.nombre, r.dispositivo)
ORDER BY
    GROUPING(cat.nombre),
    GROUPING(r.dispositivo),
    cat.nombre    NULLS LAST,
    r.dispositivo NULLS LAST;


-- NT1-7b: GROUPING SETS equivalente a CUBE — mismas 4 combinaciones explicitadas
-- NT1-7a y NT1-7b deben producir EXACTAMENTE el mismo resultado,
-- demostrando que CUBE es azucar sintactica sobre GROUPING SETS.
SELECT
    CASE GROUPING(cat.nombre)
        WHEN 1 THEN '*** TOTAL GENERAL ***'
        ELSE        cat.nombre
        END                                                         AS categoria,
    CASE GROUPING(r.dispositivo)
        WHEN 1 THEN '** TODOS LOS DISPOSITIVOS **'
        ELSE        r.dispositivo
        END                                                         AS dispositivo,
    COUNT(r.id_reproduccion)                                    AS total_reproducciones,
    ROUND(AVG(r.porcentaje_avance), 1)                          AS promedio_avance_pct,
    SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1 ELSE 0 END)  AS vistas_completas,
    CASE
        WHEN GROUPING(cat.nombre) = 1
            AND GROUPING(r.dispositivo) = 1 THEN 'GRAN TOTAL'
        WHEN GROUPING(cat.nombre)    = 1 THEN 'SUBTOTAL DISPOSITIVO'
        WHEN GROUPING(r.dispositivo) = 1 THEN 'SUBTOTAL CATEGORIA'
        ELSE                                  'DETALLE'
        END                                                         AS nivel_agregacion
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
GROUP BY GROUPING SETS (
    (cat.nombre, r.dispositivo),  -- detalle cruzado
    (cat.nombre),                 -- subtotal por categoria
    (r.dispositivo),              -- subtotal por dispositivo
    ()                            -- gran total
    )
ORDER BY
    GROUPING(cat.nombre),
    GROUPING(r.dispositivo),
    cat.nombre    NULLS LAST,
    r.dispositivo NULLS LAST;


-- =============================================================================
-- NT1-8: GROUPING SETS — Totales por categoria y por ciudad
-- Autor  : Diego Garcia
-- GROUPING SETS((categoria), (ciudad)) calcula exactamente dos grupos:
--   - Total de reproducciones por categoria (ciudad aparece NULL)
--   - Total de reproducciones por ciudad (categoria aparece NULL)
-- Diferencia con CUBE: CUBE habria generado adicionalmente el cruce
--   categoria x ciudad y el gran total. GROUPING SETS solo calcula
--   lo que se le indica explicitamente — sin cruces ni gran total.
-- Las columnas es_subtotal_* (0/1) explican que dimension se esta
-- agregando en cada fila, util para entender el comportamiento
-- de GROUPING() en la sustentacion.
-- =============================================================================

SELECT
    c.nombre                                AS categoria,
    u.ciudad_residencia                     AS ciudad,
    COUNT(r.id_reproduccion)               AS total_reproducciones,
    -- GROUPING() = 1 cuando la columna es NULL por efecto del agrupamiento
    -- GROUPING() = 0 cuando es un valor real de la tabla
    GROUPING(c.nombre)                      AS es_subtotal_categoria,
    GROUPING(u.ciudad_residencia)           AS es_subtotal_ciudad
FROM REPRODUCCIONES r
         JOIN PERFILES   pe ON pe.id_perfil    = r.id_perfil
         JOIN USUARIOS   u  ON u.id_usuario    = pe.id_usuario
         JOIN CONTENIDO  co ON co.id_contenido = r.id_contenido
         JOIN CATEGORIAS c  ON c.id_categoria  = co.id_categoria
GROUP BY GROUPING SETS (
    (c.nombre),            -- total por categoria: ciudad queda NULL
    (u.ciudad_residencia)  -- total por ciudad: categoria queda NULL
    )
ORDER BY
    GROUPING(c.nombre),
    GROUPING(u.ciudad_residencia),
    categoria NULLS LAST,
    ciudad    NULLS LAST;


-- =============================================================================
-- NT1-9: Vista materializada — Contenido mas popular
-- Autor  : Cristhian Osorio
-- Pre-agrega metricas de reproduccion y calificacion por contenido,
-- calculando un score_popularidad ponderado:
--   score = (reproducciones * 0.4) + (vistas_completas * 0.4)
--           + (promedio_estrellas * total_calificaciones * 0.2)
-- Usa patron de sub-agregacion separada para evitar inflacion de filas
-- que causaria un doble LEFT JOIN directo sobre REPRODUCCIONES y
-- CALIFICACIONES (R reproducciones x C calificaciones = R*C filas).
-- Opciones: BUILD IMMEDIATE (puebla al crear), REFRESH COMPLETE ON DEMAND.
-- =============================================================================

-- DROP defensivo: permite re-ejecutar el script sin error si ya existe
BEGIN
EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_CONTENIDO_POPULAR';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;
END;
/

CREATE MATERIALIZED VIEW MV_CONTENIDO_POPULAR
    TABLESPACE ts_quindioflix_datos
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
    DISABLE QUERY REWRITE
AS
SELECT
    c.id_contenido,
    c.titulo,
    cat.nombre                                              AS categoria,
    NVL(r_agg.total_reproducciones, 0)                     AS total_reproducciones,
    NVL(r_agg.vistas_completas,     0)                     AS vistas_completas,
    r_agg.promedio_avance_pct,
    cal_agg.promedio_estrellas,
    -- Score ponderado: 40% volumen + 40% completitud + 20% valoracion
    ROUND(
            (NVL(r_agg.total_reproducciones, 0) * 0.4)
                + (NVL(r_agg.vistas_completas,   0) * 0.4)
                + (NVL(cal_agg.promedio_estrellas, 0)
                * NVL(cal_agg.total_calificaciones, 0) * 0.2)
        , 2)                                                    AS score_popularidad
FROM CONTENIDO c
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
    -- Pre-agrega REPRODUCCIONES: 1 fila por contenido antes del JOIN
         LEFT JOIN (
    SELECT
        id_contenido,
        COUNT(id_reproduccion)                                    AS total_reproducciones,
        SUM(CASE WHEN porcentaje_avance >= 90 THEN 1 ELSE 0 END) AS vistas_completas,
        ROUND(AVG(porcentaje_avance), 1)                          AS promedio_avance_pct
    FROM REPRODUCCIONES
    GROUP BY id_contenido
) r_agg   ON r_agg.id_contenido = c.id_contenido
    -- Pre-agrega CALIFICACIONES: 1 fila por contenido antes del JOIN
         LEFT JOIN (
    SELECT
        id_contenido,
        ROUND(AVG(estrellas), 2)    AS promedio_estrellas,
        COUNT(id_calificacion)      AS total_calificaciones
    FROM CALIFICACIONES
    GROUP BY id_contenido
) cal_agg ON cal_agg.id_contenido = c.id_contenido;
/

-- REFRESH demostrativo: muestra el flujo completo ON DEMAND
-- method='C': Complete (trunca y re-inserta), atomic_refresh=FALSE: mas rapido
BEGIN
    DBMS_MVIEW.REFRESH(
        list           => 'MV_CONTENIDO_POPULAR',
        method         => 'C',
        atomic_refresh => FALSE
    );
END;
/

-- TOP 10 contenidos por score de popularidad
SELECT ranking, titulo, categoria,
       total_reproducciones, vistas_completas,
       promedio_avance_pct, promedio_estrellas, score_popularidad
FROM (
         SELECT
             ROW_NUMBER() OVER (
            ORDER BY score_popularidad DESC, total_reproducciones DESC, titulo ASC
        )                       AS ranking,
                 titulo, categoria, total_reproducciones, vistas_completas,
             promedio_avance_pct, promedio_estrellas, score_popularidad
         FROM MV_CONTENIDO_POPULAR
     )
WHERE ranking <= 10
ORDER BY ranking;


-- =============================================================================
-- NT1-10: Vista materializada — Ingresos mensuales por ciudad y plan
-- Autor  : Daniel Narvaez
-- Pre-calcula ingresos mensuales cruzando PAGOS, USUARIOS y PLANES.
-- Permite al reporte financiero de gerencia consultar sin JOINs en
-- tiempo real — Oracle solo lee la MV ya materializada.
-- NT1-10.4 demuestra la mejora de rendimiento comparando el EXPLAIN PLAN
-- de la consulta directa (JOIN triple) vs. la consulta sobre la MV.
-- =============================================================================

-- DROP defensivo
BEGIN
EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_INGRESOS_MENSUALES';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;
END;
/

CREATE MATERIALIZED VIEW MV_INGRESOS_MENSUALES
    TABLESPACE ts_quindioflix_datos
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
    DISABLE QUERY REWRITE
AS
SELECT
    EXTRACT(YEAR  FROM pa.fecha_pago)                           AS anio,
    EXTRACT(MONTH FROM pa.fecha_pago)                           AS mes,
    u.ciudad_residencia                                         AS ciudad,
    pl.nombre                                                   AS plan,
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO'     THEN 1 END) AS pagos_aprobados,
    COUNT(CASE WHEN pa.estado_pago = 'FALLIDO'     THEN 1 END) AS pagos_fallidos,
    COUNT(CASE WHEN pa.estado_pago = 'PENDIENTE'   THEN 1 END) AS pagos_pendientes,
    COUNT(CASE WHEN pa.estado_pago = 'REEMBOLSADO' THEN 1 END) AS reembolsos,
    -- Ingreso bruto: reconstruye el precio antes del descuento
    ROUND(SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                       THEN pa.monto + (pa.monto * pa.descuento_aplicado / 100)
                   ELSE 0 END), 0)                              AS ingreso_bruto,
    ROUND(SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                       THEN pa.monto * pa.descuento_aplicado / 100
                   ELSE 0 END), 0)                              AS total_descuentos,
    -- Ingreso neto: lo que QuindioFlix recibe realmente
    ROUND(SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                       THEN pa.monto ELSE 0 END), 0)                AS ingreso_neto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                        AS ticket_promedio
FROM PAGOS    pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
GROUP BY
    EXTRACT(YEAR  FROM pa.fecha_pago),
    EXTRACT(MONTH FROM pa.fecha_pago),
    u.ciudad_residencia,
    pl.nombre;
/

-- REFRESH demostrativo
BEGIN
    DBMS_MVIEW.REFRESH(
        list           => 'MV_INGRESOS_MENSUALES',
        method         => 'C',
        atomic_refresh => FALSE
    );
END;
/

-- Reporte financiero mensual — consulta de produccion sobre la MV
SELECT
    anio,
    CASE mes
        WHEN 1 THEN 'Enero'     WHEN 2  THEN 'Febrero'
        WHEN 3 THEN 'Marzo'     WHEN 4  THEN 'Abril'
        WHEN 5 THEN 'Mayo'      WHEN 6  THEN 'Junio'
        WHEN 7 THEN 'Julio'     WHEN 8  THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'WHEN 12 THEN 'Diciembre'
        END                                                         AS mes,
    ciudad, plan, pagos_aprobados, pagos_fallidos,
    pagos_pendientes, reembolsos,
    ingreso_bruto, total_descuentos, ingreso_neto, ticket_promedio
FROM MV_INGRESOS_MENSUALES
ORDER BY anio, mes, ciudad,
         CASE plan
             WHEN 'Basico'   THEN 1
             WHEN 'Estandar' THEN 2
             WHEN 'Premium'  THEN 3
             END;


-- NT1-10.4: Demostracion de mejora de rendimiento
-- Ejecutar F10 (Explain Plan) sobre cada bloque y comparar el costo.
-- Sin MV: FULL SCAN de PAGOS + JOIN triple con GROUP BY.
-- Con MV: SELECT simple sobre la tabla ya materializada.

-- NT1-10.4a: Consulta directa sobre tablas base (SIN vista materializada)
SELECT
    EXTRACT(YEAR  FROM pa.fecha_pago) AS anio,
    EXTRACT(MONTH FROM pa.fecha_pago) AS mes,
    u.ciudad_residencia               AS ciudad,
    pl.nombre                         AS plan,
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END) AS pagos_aprobados,
    ROUND(SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                       THEN pa.monto ELSE 0 END), 0)           AS ingreso_neto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                   AS ticket_promedio
FROM PAGOS    pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
GROUP BY
    EXTRACT(YEAR  FROM pa.fecha_pago),
    EXTRACT(MONTH FROM pa.fecha_pago),
    u.ciudad_residencia, pl.nombre
ORDER BY anio, mes, ciudad, pl.nombre;


-- NT1-10.4b: Consulta sobre la vista materializada (CON MV)
-- Oracle solo lee MV_INGRESOS_MENSUALES — sin JOINs ni GROUP BY en tiempo real
SELECT anio, mes, ciudad, plan, pagos_aprobados, ingreso_neto, ticket_promedio
FROM MV_INGRESOS_MENSUALES
ORDER BY anio, mes, ciudad,
         CASE plan
             WHEN 'Basico'   THEN 1
             WHEN 'Estandar' THEN 2
             WHEN 'Premium'  THEN 3
             END;

-- =============================================================================
-- FIN DEL SCRIPT R__nucleo1_consultas.sql
-- Verificaciones rapidas post-ejecucion:
--   SELECT COUNT(*) FROM MV_CONTENIDO_POPULAR;   -- debe ser 40
--   SELECT COUNT(*) FROM MV_INGRESOS_MENSUALES;  -- filas por periodo/ciudad/plan
--   SELECT SUM(total_reproducciones) FROM MV_CONTENIDO_POPULAR; -- debe ser 200
-- =============================================================================