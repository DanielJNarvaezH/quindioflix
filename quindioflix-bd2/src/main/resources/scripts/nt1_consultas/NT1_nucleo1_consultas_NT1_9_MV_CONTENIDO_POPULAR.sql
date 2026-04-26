-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_9_MV_CONTENIDO_POPULAR.sql
-- Autores : Equipo QuindioFlix
-- Nucleo  : NT1-9 — Vista materializada: Contenido mas popular
--
-- DESCRIPCION:
--   Crea y puebla la vista materializada MV_CONTENIDO_POPULAR que pre-agrega
--   metricas de reproduccion y calificacion por contenido, calculando un
--   score_popularidad ponderado para ranking rapido sin re-ejecutar JOINs.
--
--   Por que una vista materializada aqui:
--     REPRODUCCIONES tiene 200 filas (seed) pero en produccion tendria
--     millones. Calcular el top de contenidos popular requiere un JOIN
--     triple con GROUP BY sobre esa tabla grande. La MV materializa ese
--     resultado y permite consultas instantaneas sobre los 40 contenidos.
--
--   Metricas incluidas (8 columnas):
--     id_contenido          : identificador del contenido
--     titulo                : nombre del contenido
--     categoria             : nombre de la categoria
--     total_reproducciones  : cantidad total de veces reproducido
--     vistas_completas      : reproducciones con porcentaje_avance >= 90%
--     promedio_avance_pct   : avance promedio (NULL si sin reproducciones)
--     promedio_estrellas    : calificacion promedio (NULL si sin calificaciones)
--     score_popularidad     : indice ponderado (ver formula abajo)
--
--   Formula score_popularidad:
--     ROUND(
--       (total_reproducciones * 0.4)
--       + (vistas_completas   * 0.4)
--       + (NVL(promedio_estrellas,0) * total_calificaciones * 0.2)
--     , 2)
--
--     Pesos: 40% volumen + 40% completitud + 20% valoracion cualitativa.
--     total_calificaciones se calcula internamente (no es columna expuesta).
--
--   Estrategia JOIN:
--     Se usan subqueries de pre-agregacion por separado para REPRODUCCIONES
--     y CALIFICACIONES antes de hacer el JOIN al CONTENIDO. Esto evita la
--     inflacion de filas que producen dos LEFT JOINs directos sobre tablas
--     de muchos-a-uno (un cruce REPRODUCCIONES x CALIFICACIONES por contenido
--     duplicaria los conteos sin este patron).
--
--   Opciones de la MV:
--     BUILD IMMEDIATE      : se puebla al ejecutar el CREATE (visible al instante)
--     REFRESH COMPLETE     : trunca y re-ejecuta la query en cada REFRESH
--       ON DEMAND          : solo refresca al invocar DBMS_MVIEW.REFRESH
--     DISABLE QUERY REWRITE: no redirige automaticamente queries equivalentes
--       (requiere privilegio DBA en Oracle XE academico; se desactiva)
--
-- PERMISOS REQUERIDOS (ejecutar como DBA o con un usuario que los tenga):
--   GRANT CREATE MATERIALIZED VIEW TO quindioflix;
--   GRANT EXECUTE ON DBMS_MVIEW TO quindioflix;
--
-- NOTA DE EJECUCION:
--   Ejecutar en SQL Developer o SQL*Plus con Run as Script (F5).
--   El script es idempotente: el bloque DROP-BEGIN maneja la re-ejecucion.
--   No usa variables de sustitucion — script estatico.
-- =============================================================================


-- =============================================================================
-- NT1-9.0: DROP defensivo — idempotente
-- Captura ORA-12003 cuando la MV no existe para permitir re-ejecucion.
-- ORA-12003: "materialized view does not exist" (distinto de ORA-942 tablas).
-- Cualquier otro error (permisos, dependencias) se re-lanza con RAISE.
-- =============================================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_CONTENIDO_POPULAR';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN
            RAISE;
        END IF;
END;
/


-- =============================================================================
-- NT1-9.1: Crear vista materializada MV_CONTENIDO_POPULAR
--
-- Patron de sub-agregacion separada:
--   r_agg  : metricas de reproduccion por contenido (LEFT JOIN)
--   cal_agg: metricas de calificacion por contenido  (LEFT JOIN)
--
-- Este patron evita el problema del doble LEFT JOIN directo:
--   Si un contenido tiene R reproducciones y C calificaciones, el JOIN
--   directo sin pre-agrupar genera R*C filas -> COUNT inflado.
--   Con sub-agregacion: cada subquery produce 1 fila por id_contenido
--   antes del JOIN, eliminando el cruce cartesiano.
-- =============================================================================

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
    NVL(r_agg.total_reproducciones,  0)                    AS total_reproducciones,
    NVL(r_agg.vistas_completas,      0)                    AS vistas_completas,
    r_agg.promedio_avance_pct,
    cal_agg.promedio_estrellas,
    -- score ponderado: 40% volumen + 40% completitud + 20% valoracion
    ROUND(
        (NVL(r_agg.total_reproducciones, 0)  * 0.4)
        + (NVL(r_agg.vistas_completas,   0)  * 0.4)
        + (NVL(cal_agg.promedio_estrellas, 0)
           * NVL(cal_agg.total_calificaciones, 0) * 0.2)
    , 2)                                                    AS score_popularidad
FROM CONTENIDO c
    JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria

    -- Pre-agrega REPRODUCCIONES por contenido (evita inflacion de filas)
    LEFT JOIN (
        SELECT
            id_contenido,
            COUNT(id_reproduccion)                                      AS total_reproducciones,
            SUM(CASE WHEN porcentaje_avance >= 90 THEN 1 ELSE 0 END)   AS vistas_completas,
            ROUND(AVG(porcentaje_avance), 1)                            AS promedio_avance_pct
        FROM REPRODUCCIONES
        GROUP BY id_contenido
    ) r_agg ON r_agg.id_contenido = c.id_contenido

    -- Pre-agrega CALIFICACIONES por contenido
    -- promedio_estrellas = NULL cuando el contenido no tiene calificaciones
    LEFT JOIN (
        SELECT
            id_contenido,
            ROUND(AVG(estrellas), 2)        AS promedio_estrellas,
            COUNT(id_calificacion)          AS total_calificaciones
        FROM CALIFICACIONES
        GROUP BY id_contenido
    ) cal_agg ON cal_agg.id_contenido = c.id_contenido;


-- =============================================================================
-- NT1-9.2: REFRESH manual demostrativo
-- La MV ya esta poblada (BUILD IMMEDIATE), pero ejecutamos un REFRESH
-- explicito para demostrar el flujo completo de actualizacion.
--
-- method='C' : Complete refresh (trunca y re-inserta)
-- atomic_refresh=FALSE : usa TRUNCATE + INSERT (mas rapido que DELETE+INSERT)
--   Consecuencia: la MV queda vacia durante un instante — aceptable para uso
--   analitico. Si se necesita disponibilidad continua usar atomic_refresh=TRUE.
-- =============================================================================

BEGIN
    DBMS_MVIEW.REFRESH(
        list           => 'MV_CONTENIDO_POPULAR',
        method         => 'C',
        atomic_refresh => FALSE
    );
END;
/


-- =============================================================================
-- NT1-9.3: TOP 10 contenidos por score_popularidad — consulta de validacion
-- ROW_NUMBER garantiza un ranking determinista con 3 criterios de desempate.
-- =============================================================================

SELECT
    ranking,
    titulo,
    categoria,
    total_reproducciones,
    vistas_completas,
    promedio_avance_pct,
    promedio_estrellas,
    score_popularidad
FROM (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                score_popularidad     DESC,
                total_reproducciones  DESC,
                titulo                ASC
        )                       AS ranking,
        titulo,
        categoria,
        total_reproducciones,
        vistas_completas,
        promedio_avance_pct,
        promedio_estrellas,
        score_popularidad
    FROM MV_CONTENIDO_POPULAR
)
WHERE ranking <= 10
ORDER BY ranking;


-- =============================================================================
-- RESULTADO ESPERADO (datos seed V3 + V4 — 40 contenidos, 200 reproducciones)
--
-- Estructura de la MV:
--   - 1 fila por contenido (JOIN con CONTENIDO como tabla raiz)
--   - Contenidos sin reproducciones: total_reproducciones=0, vistas_completas=0,
--     promedio_avance_pct=NULL, score afectado solo por calificaciones
--   - Contenidos sin calificaciones: promedio_estrellas=NULL, aporte al
--     score desde calificaciones = 0 (NVL convierte NULL a 0 en la formula)
--
-- Verificacion de score (ejemplo para REQ-NT19-9):
--   Contenido con total_reproducciones=10, vistas_completas=5,
--   promedio_estrellas=4.0, total_calificaciones=3:
--     score = ROUND((10*0.4) + (5*0.4) + (4.0*3*0.2), 2)
--           = ROUND(4.0 + 2.0 + 2.4, 2)
--           = 8.40
--
-- VERIFICACION RAPIDA:
--   SELECT COUNT(*) FROM MV_CONTENIDO_POPULAR;
--   -- debe ser 40 (un registro por cada contenido del catalogo)
--
--   SELECT SUM(total_reproducciones) FROM MV_CONTENIDO_POPULAR;
--   -- debe ser 200 (total de reproducciones del seed)
--
--   SELECT COUNT(*) FROM MV_CONTENIDO_POPULAR WHERE promedio_estrellas IS NULL;
--   -- contenidos sin calificaciones en el seed (score solo con reproducciones)
--
--   Verificacion cruzada con NT1-3 (Cristhian):
--   SUM(total_reproducciones) FROM MV debe coincidir con
--   SUM(TOTAL_CATEGORIA) de la fila '*** TOTAL DISPOSITIVO ***' en NT1-3b.
--
--   Verificacion cruzada con NT1-1a (Daniel):
--   Los titulos en el TOP 10 de esta MV deben aparecer entre los
--   mejores rankeados de NT1-1a (que usa reproducciones + avance).
--   Pueden diferir porque NT1-9 incluye calificaciones en el score.
--
-- NOTA DE RENDIMIENTO (academica):
--   Con 200 reproducciones el REFRESH COMPLETE es trivial (< 1 seg).
--   En produccion con millones de filas, se recomienda migrar a
--   REFRESH FAST usando MATERIALIZED VIEW LOGs sobre REPRODUCCIONES
--   y CALIFICACIONES:
--     CREATE MATERIALIZED VIEW LOG ON REPRODUCCIONES WITH ROWID;
--     CREATE MATERIALIZED VIEW LOG ON CALIFICACIONES  WITH ROWID;
--   y cambiar REFRESH COMPLETE a REFRESH FAST.
-- =============================================================================
