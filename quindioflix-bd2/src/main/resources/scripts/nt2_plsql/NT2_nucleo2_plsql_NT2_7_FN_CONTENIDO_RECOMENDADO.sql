-- =============================================================================
-- NT2-7: FN_CONTENIDO_RECOMENDADO
-- Autor  : Diego Garcia
-- Recibe : p_id_perfil NUMBER — ID del perfil a recomendar
-- Retorna: VARCHAR2 — titulo del contenido mas afin al perfil
--
-- Logica de recomendacion:
--   1. Identifica los generos mas reproducidos por el perfil
--      (ponderado por porcentaje_avance para dar mas peso a lo que
--       el perfil realmente disfruta, no solo lo que inicio)
--   2. Busca contenidos que tengan esos generos y que el perfil
--      NO haya reproducido aun
--   3. Entre esos candidatos, selecciona el de mayor score:
--      score = SUM(peso_genero) * (popularidad / 100)
--      donde peso_genero = AVG(porcentaje_avance) del perfil en ese genero
--   4. Si el perfil no tiene reproducciones, retorna el contenido
--      mas popular del catalogo como fallback
--   5. Si todos los contenidos ya fueron reproducidos, retorna
--      el mas popular entre los ya vistos
--
-- Relacion con NT2-6 (FN_CALCULAR_MONTO de Cristhian):
--   Ambas funciones usan logica de agrupacion por generos/planes.
--   FN_CONTENIDO_RECOMENDADO usa AVG(porcentaje_avance) como peso,
--   analogamente a como FN_CALCULAR_MONTO usa antiguedad como factor.
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_CONTENIDO_RECOMENDADO (
    p_id_perfil IN NUMBER
) RETURN VARCHAR2
AS
    v_titulo_recomendado    VARCHAR2(200);
    v_total_reproducciones  NUMBER := 0;
    v_perfil_existe         NUMBER := 0;

BEGIN
    -- -------------------------------------------------------------------------
    -- Validacion: perfil existe
    -- -------------------------------------------------------------------------
SELECT COUNT(*) INTO v_perfil_existe
FROM PERFILES WHERE id_perfil = p_id_perfil;

IF v_perfil_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Perfil con ID ' || p_id_perfil || ' no existe.');
END IF;

    -- -------------------------------------------------------------------------
    -- Verificar si el perfil tiene reproducciones
    -- -------------------------------------------------------------------------
SELECT COUNT(*) INTO v_total_reproducciones
FROM REPRODUCCIONES WHERE id_perfil = p_id_perfil;

-- -------------------------------------------------------------------------
-- Caso 1: perfil sin reproducciones — fallback al mas popular
-- -------------------------------------------------------------------------
IF v_total_reproducciones = 0 THEN
SELECT titulo INTO v_titulo_recomendado
FROM (
         SELECT titulo
         FROM CONTENIDO
         WHERE estado = 'ACTIVO'
         ORDER BY popularidad DESC
     )
WHERE ROWNUM = 1;

RETURN '[SIN HISTORIAL] ' || v_titulo_recomendado;
END IF;

    -- -------------------------------------------------------------------------
    -- Caso 2: perfil con reproducciones
    -- Busca contenido NO visto con mayor afinidad por genero
    --
    -- Subconsulta generos_perfil:
    --   Calcula el peso de cada genero para este perfil como el
    --   promedio de porcentaje_avance en reproducciones de ese genero.
    --   Un genero con avance promedio alto = el perfil lo disfruta mas.
    --
    -- Subconsulta score_candidatos:
    --   Para cada contenido no reproducido por el perfil, suma los
    --   pesos de sus generos y multiplica por la popularidad del contenido.
    --   Esto prioriza contenidos populares que ademas coinciden con
    --   los gustos demostrados por el perfil.
    -- -------------------------------------------------------------------------
BEGIN
SELECT titulo INTO v_titulo_recomendado
FROM (
         SELECT
             c.titulo,
             -- Score: suma de pesos de generos del contenido
             -- multiplicada por popularidad normalizada
             SUM(gp.peso_genero) * (c.popularidad / 100) AS score
         FROM CONTENIDO c
                  JOIN CONTENIDO_GENEROS cg ON cg.id_contenido = c.id_contenido
             -- Generos del perfil con su peso (AVG avance en ese genero)
                  JOIN (
             SELECT
                 cg2.id_genero,
                 AVG(r.porcentaje_avance) AS peso_genero
             FROM REPRODUCCIONES     r
                      JOIN CONTENIDO      c2  ON c2.id_contenido  = r.id_contenido
                      JOIN CONTENIDO_GENEROS cg2 ON cg2.id_contenido = c2.id_contenido
             WHERE r.id_perfil = p_id_perfil
             GROUP BY cg2.id_genero
         ) gp ON gp.id_genero = cg.id_genero
         WHERE c.estado = 'ACTIVO'
           -- Solo contenidos que el perfil NO ha reproducido
           AND c.id_contenido NOT IN (
             SELECT DISTINCT id_contenido
             FROM REPRODUCCIONES
             WHERE id_perfil = p_id_perfil
         )
         GROUP BY c.id_contenido, c.titulo, c.popularidad
         ORDER BY score DESC
     )
WHERE ROWNUM = 1;

EXCEPTION
        -- -------------------------------------------------------------------------
        -- Caso 3: todos los contenidos ya fueron reproducidos
        -- Recomienda el mas popular entre los ya vistos
        -- -------------------------------------------------------------------------
        WHEN NO_DATA_FOUND THEN
SELECT c.titulo INTO v_titulo_recomendado
FROM CONTENIDO c
WHERE c.id_contenido = (
    SELECT r.id_contenido
    FROM REPRODUCCIONES r
    WHERE r.id_perfil = p_id_perfil
    GROUP BY r.id_contenido
    ORDER BY AVG(r.porcentaje_avance) DESC
        FETCH FIRST 1 ROWS ONLY
);

RETURN '[YA VISTO TODO] ' || v_titulo_recomendado;
END;

RETURN v_titulo_recomendado;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Error en FN_CONTENIDO_RECOMENDADO para perfil ' ||
            p_id_perfil || ': ' || SQLERRM);
END FN_CONTENIDO_RECOMENDADO;
/

-- =============================================================================
-- Casos de prueba
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Prueba 1: perfil con reproducciones — debe recomendar contenido no visto
SELECT FN_CONTENIDO_RECOMENDADO(1) AS recomendacion FROM DUAL;

-- Prueba 2: otro perfil
SELECT FN_CONTENIDO_RECOMENDADO(2) AS recomendacion FROM DUAL;

-- Prueba 3: todos los perfiles con su recomendacion
SELECT
    p.id_perfil,
    p.nombre                            AS perfil,
    u.nombre || ' ' || u.apellido       AS usuario,
    FN_CONTENIDO_RECOMENDADO(p.id_perfil) AS recomendacion
FROM PERFILES p
         JOIN USUARIOS u ON u.id_usuario = p.id_usuario
WHERE p.id_perfil <= 10
ORDER BY p.id_perfil;

-- Prueba 4: perfil inexistente — debe lanzar ORA-20010
BEGIN
    DBMS_OUTPUT.PUT_LINE(FN_CONTENIDO_RECOMENDADO(9999));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Capturado: ' || SQLERRM);
END;
/