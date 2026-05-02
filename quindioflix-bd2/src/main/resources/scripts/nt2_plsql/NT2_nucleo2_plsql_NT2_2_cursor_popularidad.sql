-- =============================================================================
-- NT2-2: Cursor — Popularidad de contenido
-- Autor  : Diego Garcia
-- Recorre cada contenido del catalogo, calcula sus reproducciones completas
-- (porcentaje_avance >= 90%) y actualiza el campo popularidad en CONTENIDO.
--
-- Formula de popularidad:
--   popularidad = (vistas_completas / total_reproducciones) * 100 * factor_calificacion
--   factor_calificacion = NVL(promedio_estrellas / 5, 1)
--     -> Si el contenido tiene calificaciones: pondera por su nota promedio
--     -> Si no tiene calificaciones: factor = 1 (no penaliza ni bonifica)
--
-- Cursor FOR UPDATE: bloquea cada fila de CONTENIDO antes de actualizarla,
-- garantizando que ninguna otra sesion pueda modificar popularidad mientras
-- este bloque se ejecuta (control de concurrencia a nivel de fila).
--
-- WHERE CURRENT OF: usa el cursor activo para el UPDATE en lugar de buscar
-- por id_contenido — mas eficiente porque evita un segundo acceso al indice.
-- =============================================================================

DECLARE
-- Tipo registro para capturar datos del cursor
TYPE t_contenido_rec IS RECORD (
        id_contenido          CONTENIDO.id_contenido%TYPE,
        titulo                CONTENIDO.titulo%TYPE,
        popularidad_actual    CONTENIDO.popularidad%TYPE
    );

    -- Variables de trabajo
    v_total_reproducciones  NUMBER := 0;
    v_vistas_completas      NUMBER := 0;
    v_promedio_estrellas    NUMBER := 0;
    v_nueva_popularidad     NUMBER := 0;
    v_factor_calificacion   NUMBER := 1;
    v_contenidos_actualizados NUMBER := 0;

    -- Cursor principal: recorre CONTENIDO bloqueando cada fila para UPDATE
    -- FOR UPDATE OF popularidad: bloquea solo la columna que vamos a modificar
CURSOR cur_contenido IS
SELECT id_contenido, titulo, popularidad
FROM CONTENIDO
ORDER BY id_contenido
    FOR UPDATE OF popularidad NOWAIT;

v_rec t_contenido_rec;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ACTUALIZACION DE POPULARIDAD DE CONTENIDO ===');
    DBMS_OUTPUT.PUT_LINE('Inicio: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');

    -- Abrir y recorrer el cursor fila por fila
OPEN cur_contenido;
LOOP
FETCH cur_contenido INTO v_rec.id_contenido,
                                 v_rec.titulo,
                                 v_rec.popularidad_actual;
        EXIT WHEN cur_contenido%NOTFOUND;

        -- 1. Calcular total de reproducciones y vistas completas para este contenido
SELECT COUNT(*),
       SUM(CASE WHEN porcentaje_avance >= 90 THEN 1 ELSE 0 END)
INTO v_total_reproducciones,
    v_vistas_completas
FROM REPRODUCCIONES
WHERE id_contenido = v_rec.id_contenido;

-- 2. Calcular promedio de estrellas (NULL si no tiene calificaciones)
SELECT NVL(AVG(estrellas), 0)
INTO v_promedio_estrellas
FROM CALIFICACIONES
WHERE id_contenido = v_rec.id_contenido;

-- 3. Calcular factor de calificacion (0 si no tiene calificaciones -> factor 1)
IF v_promedio_estrellas = 0 THEN
            v_factor_calificacion := 1;  -- sin calificaciones: no penaliza ni bonifica
ELSE
            v_factor_calificacion := v_promedio_estrellas / 5;
END IF;

        -- 4. Calcular nueva popularidad
        IF v_total_reproducciones = 0 THEN
            -- Sin reproducciones: popularidad 0
            v_nueva_popularidad := 0;
ELSE
            v_nueva_popularidad := ROUND(
                (v_vistas_completas / v_total_reproducciones) * 100
                * v_factor_calificacion
            , 2);
END IF;

        -- 5. Actualizar usando WHERE CURRENT OF (apunta a la fila bloqueada por el cursor)
UPDATE CONTENIDO
SET popularidad = v_nueva_popularidad
WHERE CURRENT OF cur_contenido;

-- 6. Log por consola para verificacion
DBMS_OUTPUT.PUT_LINE(
            'ID: ' || LPAD(v_rec.id_contenido, 3) ||
            ' | Reprod: ' || LPAD(v_total_reproducciones, 3) ||
            ' | Completas: ' || LPAD(v_vistas_completas, 3) ||
            ' | Estrellas: ' || NVL(TO_CHAR(v_promedio_estrellas, 'FM9.99'), 'N/A') ||
            ' | Pop anterior: ' || LPAD(v_rec.popularidad_actual, 6) ||
            ' | Pop nueva: ' || LPAD(v_nueva_popularidad, 6) ||
            ' | ' || SUBSTR(v_rec.titulo, 1, 30)
        );

        v_contenidos_actualizados := v_contenidos_actualizados + 1;

END LOOP;
CLOSE cur_contenido;

COMMIT;

DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Contenidos actualizados: ' || v_contenidos_actualizados);
    DBMS_OUTPUT.PUT_LINE('Fin: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('=== FIN ACTUALIZACION ===');

EXCEPTION
    WHEN OTHERS THEN
        -- Si algo falla, revertir todos los UPDATEs del bloque
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Se revirtieron todos los cambios (ROLLBACK).');
        RAISE;
END;
/

-- Verificacion post-ejecucion: top 10 contenidos por popularidad actualizada
SELECT id_contenido, titulo, popularidad
FROM CONTENIDO
ORDER BY popularidad DESC
    FETCH FIRST 10 ROWS ONLY;