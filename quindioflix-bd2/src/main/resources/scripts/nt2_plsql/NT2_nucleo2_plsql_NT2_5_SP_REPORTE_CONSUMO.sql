-- =============================================================================
-- NT2-5: SP_REPORTE_CONSUMO
-- Autor  : Diego Garcia
-- Recibe : p_id_usuario    NUMBER  — ID del usuario a reportar
--          p_fecha_inicio  DATE    — inicio del rango de fechas
--          p_fecha_fin     DATE    — fin del rango de fechas
-- Genera : reporte detallado de reproducciones por perfil y categoria,
--          con totales de tiempo consumido (en minutos).
--
-- Correcciones v2:
--   - Calculo de minutos usa EXTRACT sobre INTERVAL DAY TO SECOND
--     en lugar de resta directa (ORA-00932)
--   - Cursor de categorias cambiado a FETCH explicito para poder
--     referenciar variables dentro del loop (PLS-00364)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_REPORTE_CONSUMO (
    p_id_usuario   IN NUMBER,
    p_fecha_inicio IN DATE,
    p_fecha_fin    IN DATE
) AS

    -- Variables de cabecera
    v_nombre_usuario    VARCHAR2(160);
    v_email_usuario     VARCHAR2(120);
    v_plan_usuario      VARCHAR2(30);
    v_total_perfiles    NUMBER := 0;

    -- Variables de acumulado general
    v_total_reprod_usuario    NUMBER := 0;
    v_total_minutos_usuario   NUMBER := 0;

    -- Variables de acumulado por perfil
    v_total_reprod_perfil     NUMBER := 0;
    v_total_minutos_perfil    NUMBER := 0;

    -- Variables de detalle por categoria (para FETCH explicito)
    v_categoria               VARCHAR2(50);
    v_cantidad_reprod         NUMBER := 0;
    v_reprod_completas        NUMBER := 0;
    v_minutos_categoria       NUMBER := 0;
    v_promedio_avance         NUMBER := 0;

    -- Cursor de perfiles del usuario
CURSOR cur_perfiles IS
SELECT id_perfil, nombre, tipo_perfil
FROM PERFILES
WHERE id_usuario = p_id_usuario
ORDER BY id_perfil;

-- Cursor de categorias por perfil en el rango de fechas
-- Minutos: EXTRACT convierte INTERVAL DAY TO SECOND a NUMBER
CURSOR cur_categorias (p_id_perfil NUMBER) IS
SELECT
    cat.nombre                                              AS categoria,
    COUNT(r.id_reproduccion)                                AS cantidad_reprod,
    SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1
             ELSE 0 END)                                    AS reprod_completas,
    ROUND(SUM(
                  EXTRACT(DAY    FROM (NVL(r.fecha_hora_fin, SYSTIMESTAMP) - r.fecha_hora_inicio)) * 1440 +
                  EXTRACT(HOUR   FROM (NVL(r.fecha_hora_fin, SYSTIMESTAMP) - r.fecha_hora_inicio)) * 60   +
                  EXTRACT(MINUTE FROM (NVL(r.fecha_hora_fin, SYSTIMESTAMP) - r.fecha_hora_inicio))        +
                  EXTRACT(SECOND FROM (NVL(r.fecha_hora_fin, SYSTIMESTAMP) - r.fecha_hora_inicio)) / 60
          ), 1)                                                   AS minutos_consumidos,
    ROUND(AVG(r.porcentaje_avance), 1)                      AS promedio_avance
FROM REPRODUCCIONES r
         JOIN CONTENIDO  c   ON c.id_contenido  = r.id_contenido
         JOIN CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE r.id_perfil = p_id_perfil
  AND CAST(r.fecha_hora_inicio AS DATE) >= p_fecha_inicio
  AND CAST(r.fecha_hora_inicio AS DATE) <= p_fecha_fin
GROUP BY cat.nombre
ORDER BY minutos_consumidos DESC;

BEGIN
    -- -------------------------------------------------------------------------
    -- Validacion 1: rango de fechas valido
    -- -------------------------------------------------------------------------
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Rango de fechas invalido: fecha_inicio (' ||
            TO_CHAR(p_fecha_inicio, 'DD/MM/YYYY') ||
            ') no puede ser mayor que fecha_fin (' ||
            TO_CHAR(p_fecha_fin, 'DD/MM/YYYY') || ').');
END IF;

    -- -------------------------------------------------------------------------
    -- Validacion 2: usuario existe
    -- -------------------------------------------------------------------------
BEGIN
SELECT u.nombre || ' ' || u.apellido,
       u.email,
       pl.nombre
INTO v_nombre_usuario, v_email_usuario, v_plan_usuario
FROM USUARIOS u
         JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE u.id_usuario = p_id_usuario;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Usuario con ID ' || p_id_usuario || ' no existe en el sistema.');
END;

    -- -------------------------------------------------------------------------
    -- Validacion 3: usuario tiene perfiles
    -- -------------------------------------------------------------------------
SELECT COUNT(*) INTO v_total_perfiles
FROM PERFILES WHERE id_usuario = p_id_usuario;

IF v_total_perfiles = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'El usuario ' || v_nombre_usuario ||
            ' (ID: ' || p_id_usuario || ') no tiene perfiles registrados.');
END IF;

    -- -------------------------------------------------------------------------
    -- Encabezado del reporte
    -- -------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('         REPORTE DE CONSUMO - QUINDIOFLIX              ');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('Usuario : ' || v_nombre_usuario);
    DBMS_OUTPUT.PUT_LINE('Email   : ' || v_email_usuario);
    DBMS_OUTPUT.PUT_LINE('Plan    : ' || v_plan_usuario);
    DBMS_OUTPUT.PUT_LINE('Periodo : ' ||
        TO_CHAR(p_fecha_inicio,'DD/MM/YYYY') || ' al ' ||
        TO_CHAR(p_fecha_fin,   'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');

    -- -------------------------------------------------------------------------
    -- Recorrer perfiles del usuario
    -- -------------------------------------------------------------------------
FOR v_perfil IN cur_perfiles LOOP

        v_total_reprod_perfil  := 0;
        v_total_minutos_perfil := 0;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('  Perfil: ' || v_perfil.nombre ||
                             ' [' || v_perfil.tipo_perfil || ']' ||
                             ' (ID: ' || v_perfil.id_perfil || ')');
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD('-', 65, '-'));
        DBMS_OUTPUT.PUT_LINE('  ' ||
            RPAD('CATEGORIA',      20) ||
            RPAD('REPRODUCCIONES', 16) ||
            RPAD('COMPLETAS',      11) ||
            RPAD('MINUTOS',        10) ||
            'AVANCE%');
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD('-', 65, '-'));

        -- Abrir cursor de categorias para este perfil
OPEN cur_categorias(v_perfil.id_perfil);
LOOP
FETCH cur_categorias INTO
                v_categoria,
                v_cantidad_reprod,
                v_reprod_completas,
                v_minutos_categoria,
                v_promedio_avance;
            EXIT WHEN cur_categorias%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE('  ' ||
                RPAD(v_categoria,          20) ||
                RPAD(v_cantidad_reprod,    16) ||
                RPAD(v_reprod_completas,   11) ||
                RPAD(NVL(TO_CHAR(v_minutos_categoria), '0'), 10) ||
                NVL(TO_CHAR(v_promedio_avance), '0') || '%');

            -- Acumular totales del perfil
            v_total_reprod_perfil  := v_total_reprod_perfil  + v_cantidad_reprod;
            v_total_minutos_perfil := v_total_minutos_perfil + NVL(v_minutos_categoria, 0);

END LOOP;
CLOSE cur_categorias;

-- Subtotal del perfil
DBMS_OUTPUT.PUT_LINE('  ' || RPAD('-', 65, '-'));
        DBMS_OUTPUT.PUT_LINE('  ' ||
            RPAD('SUBTOTAL PERFIL', 20) ||
            RPAD(v_total_reprod_perfil, 16) ||
            RPAD('', 11) ||
            ROUND(v_total_minutos_perfil, 1) || ' min totales');

        -- Acumular totales del usuario
        v_total_reprod_usuario  := v_total_reprod_usuario  + v_total_reprod_perfil;
        v_total_minutos_usuario := v_total_minutos_usuario + v_total_minutos_perfil;

END LOOP;

    -- -------------------------------------------------------------------------
    -- Gran total del usuario
    -- -------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('TOTAL USUARIO: ' ||
        v_total_reprod_usuario || ' reproducciones | ' ||
        ROUND(v_total_minutos_usuario, 1) || ' minutos consumidos');
    DBMS_OUTPUT.PUT_LINE('=======================================================');

EXCEPTION
    WHEN OTHERS THEN
        -- Cerrar cursor de categorias si quedo abierto por un error
        IF cur_categorias%ISOPEN THEN
            CLOSE cur_categorias;
END IF;
        DBMS_OUTPUT.PUT_LINE('ERROR inesperado: ' || SQLERRM);
        RAISE;
END SP_REPORTE_CONSUMO;
/

-- =============================================================================
-- Casos de prueba
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Prueba 1: usuario valido con reproducciones en 2024
BEGIN
    SP_REPORTE_CONSUMO(1, DATE '2024-01-01', DATE '2024-12-31');
END;
/

-- Prueba 2: usuario valido sin reproducciones en el periodo
BEGIN
    SP_REPORTE_CONSUMO(1, DATE '2023-01-01', DATE '2023-12-31');
END;
/

-- Prueba 3: fecha invalida (inicio > fin) — debe lanzar ORA-20002
BEGIN
    SP_REPORTE_CONSUMO(1, DATE '2024-12-31', DATE '2024-01-01');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Capturado correctamente: ' || SQLERRM);
END;
/

-- Prueba 4: usuario inexistente — debe lanzar ORA-20001
BEGIN
    SP_REPORTE_CONSUMO(9999, DATE '2024-01-01', DATE '2024-12-31');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Capturado correctamente: ' || SQLERRM);
END;
/