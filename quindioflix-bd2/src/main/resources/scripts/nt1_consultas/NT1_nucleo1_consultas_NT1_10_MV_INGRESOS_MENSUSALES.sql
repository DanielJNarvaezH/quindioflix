-- =============================================================================
-- NT1: Consultas Avanzadas — QuindioFlix
-- Script  : NT1_nucleo1_consultas_NT1_10_MV_INGRESOS_MENSUALES.sql
-- Autor   : Daniel Narvaez
-- Nucleo  : NT1-10 — Vista materializada: Ingresos mensuales por ciudad y plan
--
-- DESCRIPCION:
--   Crea y puebla la vista materializada MV_INGRESOS_MENSUALES que precalcula
--   los ingresos mensuales de QuindioFlix agrupados por ciudad y plan de
--   suscripcion, cruzando PAGOS, USUARIOS y PLANES.
--
--   Por que una vista materializada aqui:
--     El reporte financiero mensual que requiere la gerencia (seccion 1.6
--     del PDF del proyecto) necesita cruzar PAGOS con USUARIOS (para obtener
--     la ciudad) y con PLANES (para obtener el nombre del plan). En produccion
--     PAGOS puede tener millones de registros. La MV materializa ese resultado
--     y permite consultas instantaneas sobre los totales ya calculados.
--
--   Metricas incluidas:
--     anio                 : anno del periodo (extraido de fecha_pago)
--     mes                  : mes del periodo (1-12)
--     ciudad               : ciudad de residencia del usuario
--     plan                 : nombre del plan (Basico, Estandar, Premium)
--     pagos_aprobados      : cantidad de pagos con estado APROBADO
--     pagos_fallidos       : cantidad de pagos con estado RECHAZADO
--     pagos_pendientes     : cantidad de pagos con estado PENDIENTE
--     reembolsos           : cantidad de pagos con estado REEMBOLSADO
--     ingreso_bruto        : monto antes de descuentos (monto + descuento)
--     total_descuentos     : suma de descuentos otorgados (en pesos)
--     ingreso_neto         : suma de montos aprobados (despues de descuentos)
--     ticket_promedio      : ingreso_neto / pagos_aprobados
--
--   Relacion con NT1-1b (consulta parametrizada de ingresos):
--     NT1-1b genera el mismo reporte pero ejecutando el JOIN en tiempo real
--     cada vez que se llama. Esta MV precalcula ese resultado y permite
--     demostracion de mejora de rendimiento (seccion NT1-10.4 abajo).
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
--   Carpeta: scripts/consultas/ (NO en db/migration/ — es reporte manual)
-- =============================================================================


-- =============================================================================
-- NT1-10.0: DROP defensivo — idempotente
-- Captura ORA-12003 cuando la MV no existe para permitir re-ejecucion.
-- ORA-12003: "materialized view does not exist"
-- Cualquier otro error (permisos, dependencias) se re-lanza con RAISE.
-- =============================================================================

BEGIN
EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_INGRESOS_MENSUALES';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN
            RAISE;
END IF;
END;
/


-- =============================================================================
-- NT1-10.1: Crear vista materializada MV_INGRESOS_MENSUALES
--
-- JOIN triple: PAGOS -> USUARIOS -> PLANES
--   PAGOS      : fuente de montos, fechas, estados y descuentos
--   USUARIOS   : aporta ciudad (dimension geografica del reporte)
--   PLANES     : aporta nombre del plan (dimension de suscripcion)
--
-- Solo se consideran pagos con estado APROBADO para el ingreso_neto.
-- Los otros estados (RECHAZADO, PENDIENTE, REEMBOLSADO) se cuentan
-- por separado para el reporte de gestion financiera.
--
-- ingreso_bruto:
--   Reconstruye el monto antes de descuento sumando el descuento de vuelta.
--   descuento_aplicado es un porcentaje (0-100), entonces:
--     monto_bruto = monto / (1 - descuento_aplicado/100)
--   Simplificacion usada: monto + (monto * descuento_aplicado / 100)
--   (aproximacion valida para descuentos pequenos como 10% y 15%)
-- =============================================================================

CREATE MATERIALIZED VIEW MV_INGRESOS_MENSUALES
    TABLESPACE ts_quindioflix_datos
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
    DISABLE QUERY REWRITE
AS
SELECT
    EXTRACT(YEAR  FROM pa.fecha_pago)                       AS anio,
    EXTRACT(MONTH FROM pa.fecha_pago)                       AS mes,
    u.ciudad_residencia                                     AS ciudad,
    pl.nombre                                               AS plan,
    -- Conteo por estado de pago
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO'    THEN 1 END) AS pagos_aprobados,
    COUNT(CASE WHEN pa.estado_pago = 'FALLIDO'   THEN 1 END) AS pagos_fallidos,
    COUNT(CASE WHEN pa.estado_pago = 'PENDIENTE'   THEN 1 END) AS pagos_pendientes,
    COUNT(CASE WHEN pa.estado_pago = 'REEMBOLSADO' THEN 1 END) AS reembolsos,
    -- Metricas financieras (solo pagos APROBADO)
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                         THEN pa.monto + (pa.monto * pa.descuento_aplicado / 100)
                     ELSE 0 END)
        , 0)                                                    AS ingreso_bruto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                         THEN pa.monto * pa.descuento_aplicado / 100
                     ELSE 0 END)
        , 0)                                                    AS total_descuentos,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                         THEN pa.monto
                     ELSE 0 END)
        , 0)                                                    AS ingreso_neto,
    -- Ticket promedio: ingreso_neto / pagos_aprobados (NULLIF evita division por cero)
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                    AS ticket_promedio
FROM PAGOS    pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
GROUP BY
    EXTRACT(YEAR  FROM pa.fecha_pago),
    EXTRACT(MONTH FROM pa.fecha_pago),
    u.ciudad_residencia,
    pl.nombre;


-- =============================================================================
-- NT1-10.2: REFRESH manual demostrativo
-- La MV ya esta poblada (BUILD IMMEDIATE), pero ejecutamos un REFRESH
-- explicito para demostrar el flujo completo de actualizacion ON DEMAND.
--
-- method='C'           : Complete refresh (trunca y re-inserta)
-- atomic_refresh=FALSE : usa TRUNCATE + INSERT (mas rapido que DELETE+INSERT)
--   Consecuencia: la MV queda vacia durante un instante — aceptable para
--   uso analitico nocturno. Para disponibilidad continua usar TRUE.
-- =============================================================================

BEGIN
    DBMS_MVIEW.REFRESH(
        list           => 'MV_INGRESOS_MENSUALES',
        method         => 'C',
        atomic_refresh => FALSE
    );
END;
/


-- =============================================================================
-- NT1-10.3: Reporte financiero mensual — consulta sobre la MV
-- Esta es la consulta que la gerencia usa en produccion.
-- Al ejecutarse sobre la MV ya no hace JOINs — solo un SELECT simple.
-- =============================================================================

SELECT
    anio,
    -- Nombre del mes en espanol para legibilidad del reporte
    CASE mes
        WHEN 1  THEN 'Enero'     WHEN 2  THEN 'Febrero'
        WHEN 3  THEN 'Marzo'     WHEN 4  THEN 'Abril'
        WHEN 5  THEN 'Mayo'      WHEN 6  THEN 'Junio'
        WHEN 7  THEN 'Julio'     WHEN 8  THEN 'Agosto'
        WHEN 9  THEN 'Septiembre'WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END                                                     AS mes,
    ciudad,
    plan,
    pagos_aprobados,
    pagos_fallidos,
    pagos_pendientes,
    reembolsos,
    ingreso_bruto,
    total_descuentos,
    ingreso_neto,
    ticket_promedio
FROM MV_INGRESOS_MENSUALES
ORDER BY
    anio,
    mes,
    ciudad,
    CASE plan
        WHEN 'Basico'   THEN 1
        WHEN 'Estandar' THEN 2
        WHEN 'Premium'  THEN 3
        END;


-- =============================================================================
-- NT1-10.4: Demostracion de mejora de rendimiento
-- Ejecutar primero NT1-10.4a (sin MV) y luego NT1-10.4b (con MV).
-- Comparar el plan de ejecucion: JOIN triple vs. SELECT simple sobre MV.
-- En SQL Developer ver: F10 (Explain Plan) antes de ejecutar cada consulta.
-- =============================================================================

-- NT1-10.4a: Consulta DIRECTA sobre tablas base (sin vista materializada)
-- Equivalente a lo que hacia NT1-1b en tiempo real con JOIN triple.
-- En produccion con millones de pagos: FULL SCAN de PAGOS + JOIN costoso.
-- -------------------------------------------------------------------------
SELECT
    EXTRACT(YEAR  FROM pa.fecha_pago)                       AS anio,
    EXTRACT(MONTH FROM pa.fecha_pago)                       AS mes,
    u.ciudad_residencia                                     AS ciudad,
    pl.nombre                                               AS plan,
    COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END) AS pagos_aprobados,
    ROUND(SUM(CASE WHEN pa.estado_pago = 'EXITOSO'
                       THEN pa.monto ELSE 0 END), 0)            AS ingreso_neto,
    ROUND(
            SUM(CASE WHEN pa.estado_pago = 'EXITOSO' THEN pa.monto ELSE 0 END)
                / NULLIF(COUNT(CASE WHEN pa.estado_pago = 'EXITOSO' THEN 1 END), 0)
        , 0)                                                    AS ticket_promedio
FROM PAGOS    pa
         JOIN USUARIOS u  ON u.id_usuario = pa.id_usuario
         JOIN PLANES   pl ON pl.id_plan   = u.id_plan
GROUP BY
    EXTRACT(YEAR  FROM pa.fecha_pago),
    EXTRACT(MONTH FROM pa.fecha_pago),
    u.ciudad_residencia,
    pl.nombre
ORDER BY anio, mes, ciudad, pl.nombre;


-- NT1-10.4b: Consulta sobre la VISTA MATERIALIZADA (con MV)
-- La MV ya tiene el resultado precalculado — Oracle solo lee la MV,
-- sin JOINs ni GROUP BY en tiempo de consulta.
-- En produccion: INDEX SCAN sobre MV en lugar de FULL SCAN de PAGOS.
-- -------------------------------------------------------------------------
SELECT
    anio,
    mes,
    ciudad,
    plan,
    pagos_aprobados,
    ingreso_neto,
    ticket_promedio
FROM MV_INGRESOS_MENSUALES
ORDER BY anio, mes, ciudad,
         CASE plan
             WHEN 'Basico'   THEN 1
             WHEN 'Estandar' THEN 2
             WHEN 'Premium'  THEN 3
             END;


-- =============================================================================
-- RESULTADO ESPERADO (datos seed V3 + V4 — 80 pagos, 30 usuarios):
--
-- La MV tendra una fila por cada combinacion unica de:
--   (anio, mes, ciudad, plan) que exista en los datos de prueba.
--
-- Con los datos asimetricos del V4:
--   Armenia   -> Plan Basico   -> pagos enero a diciembre 2024
--   Pereira   -> Plan Estandar -> pagos enero a diciembre 2024
--   Manizales -> Plan Premium  -> pagos enero a diciembre 2024
--
-- Verificaciones rapidas en SQL Developer:
--
--   1) Cantidad de filas en la MV:
--      SELECT COUNT(*) FROM MV_INGRESOS_MENSUALES;
--
--   2) Ingreso neto total debe coincidir con suma directa de PAGOS APROBADOS:
--      SELECT SUM(ingreso_neto) FROM MV_INGRESOS_MENSUALES;
--      vs.
--      SELECT ROUND(SUM(monto), 0) FROM PAGOS WHERE estado_pago = 'EXITOSO';
--      -- Ambos deben dar el mismo resultado
--
--   3) Comparar resultado con NT1-1b:
--      NT1-1b filtrado por mes=3 y anio=2024 debe coincidir con:
--      SELECT * FROM MV_INGRESOS_MENSUALES WHERE anio=2024 AND mes=3;
--
-- NOTA DE RENDIMIENTO (academica):
--   Con 80 pagos el REFRESH COMPLETE es trivial (< 1 seg).
--   En produccion con millones de pagos, se recomienda:
--     1. REFRESH FAST con MATERIALIZED VIEW LOG sobre PAGOS y USUARIOS
--     2. Programar el refresh nocturno con DBMS_SCHEDULER
--     3. Crear indice sobre MV: CREATE INDEX idx_mv_ing_ciudad_plan
--        ON MV_INGRESOS_MENSUALES(ciudad, plan) TABLESPACE ts_quindioflix_indices;
-- =============================================================================