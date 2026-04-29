-- =============================================================================
-- QuindioFlix — Datos Extra: cobertura 2025 completo + 2026
-- Archivo : Insercion_de_datos_extra.sql
-- Carpeta : scripts/arreglos_y_detalles/
-- Autores : Equipo QuindioFlix
-- Motivo  : Los datos de V4 solo cubren hasta mayo 2025 en REPRODUCCIONES
--           y enero-diciembre 2024 en PAGOS. Para que los reportes NT1
--           (ROLLUP, CUBE, PIVOT, GROUPING SETS por periodo de tiempo)
--           muestren diferencias reales entre 2024, 2025 y 2026, se agregan:
--             - 120 reproducciones adicionales (jun-dic 2025 + ene-abr 2026)
--             - 60 pagos adicionales (ene-dic 2025 + ene-abr 2026)
--             - 30 calificaciones adicionales coherentes con las nuevas repro.
--             - 20 favoritos adicionales
-- Prerequisito: ejecutar DESPUES de V4 y V4.1 (ya deben existir todos los
--               datos base). No usa Flyway — ejecutar manualmente en
--               SQL Developer conectado como QUINDIOFLIX.
-- Nota    : Este script es idempotente solo si la BD esta en estado limpio
--           post-V4.1. No volver a ejecutar si ya se corrio una vez.
-- =============================================================================


-- =============================================================================
-- 1. REPRODUCCIONES ADICIONALES — 120 registros
--    Distribucion por periodo:
--      jun-dic 2025 : 80 registros  (cubre el hueco de V4)
--      ene-abr 2026 : 40 registros  (aprovecha la particion p_2026)
--    Distribucion asimetrica por ciudad (via perfil->usuario):
--      Armenia  : mayor consumo (refleja 14 usuarios vs 10 Pereira vs 6 Mza)
--    Dispositivos variados para soportar reporte PIVOT por dispositivo (NT1).
--    Contenidos: se repiten los mas populares + algunos nuevos para diversidad.
-- =============================================================================
INSERT INTO REPRODUCCIONES (fecha_hora_inicio, fecha_hora_fin, dispositivo, porcentaje_avance, id_perfil, id_contenido, id_episodio)
WITH gen AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 120
    ), perfiles_lookup AS (
SELECT
    p.id_perfil,
    u.ciudad_residencia,
    ROW_NUMBER() OVER (ORDER BY u.ciudad_residencia DESC, u.id_usuario, p.id_perfil) AS perfil_pos
FROM PERFILES p
    JOIN USUARIOS u ON u.id_usuario = p.id_usuario
WHERE u.estado_cuenta <> 'SUSPENDIDO'
    ), episodios_lookup AS (
SELECT
    e.id_episodio,
    c.titulo AS titulo_contenido,
    ROW_NUMBER() OVER (
    PARTITION BY c.titulo
    ORDER BY t.numero_temporada, e.numero_episodio, e.id_episodio
    ) AS episodio_pos
FROM EPISODIOS e
    JOIN TEMPORADAS t ON t.id_temporada = e.id_temporada
    JOIN CONTENIDO c ON c.id_contenido = t.id_contenido
    ), base AS (
SELECT
    g.n,
    -- jun-dic 2025: n=1..80, separados cada 26 horas para cubrir 7 meses
    -- ene-abr 2026: n=81..120, separados cada 25 horas para cubrir 4 meses
    CASE
    WHEN g.n <= 80
    THEN TIMESTAMP '2025-06-01 09:00:00' + NUMTODSINTERVAL((g.n - 1) * 26, 'HOUR')
    ELSE TIMESTAMP '2026-01-02 10:00:00' + NUMTODSINTERVAL((g.n - 81) * 25, 'HOUR')
    END AS fecha_hora_inicio,
    -- Dispositivos asimetricos: TV y CELULAR dominan, TABLET poco
    CASE MOD(g.n - 1, 11)
    WHEN 0  THEN 'TV'
    WHEN 1  THEN 'CELULAR'
    WHEN 2  THEN 'TV'
    WHEN 3  THEN 'CELULAR'
    WHEN 4  THEN 'COMPUTADOR'
    WHEN 5  THEN 'TV'
    WHEN 6  THEN 'CELULAR'
    WHEN 7  THEN 'TV'
    WHEN 8  THEN 'TABLET'
    WHEN 9  THEN 'CELULAR'
    ELSE         'COMPUTADOR'
    END AS dispositivo,
    -- Porcentaje: mas completos que en V4 para simular usuarios fidelizados
    CASE MOD(g.n - 1, 7)
    WHEN 0 THEN 55
    WHEN 1 THEN 75
    WHEN 2 THEN 90
    WHEN 3 THEN 100
    WHEN 4 THEN 100
    WHEN 5 THEN 85
    ELSE        95
    END AS porcentaje_avance,
    -- Perfiles: los primeros 35 posiciones son Armenia (mas usuarios)
    -- esto genera asimetria geografica en los reportes
    CASE
    WHEN g.n <= 60 THEN MOD(g.n - 1, 35) + 1  -- concentrar en Armenia
    ELSE                 MOD(g.n - 1, 45) + 1  -- ampliar a toda la BD
    END AS perfil_pos,
    -- Contenidos: mix de series populares + algunos menos vistos para
    -- que ROLLUP muestre diferencias reales de popularidad
    CASE MOD(g.n - 1, 15)
    WHEN 0  THEN 'Los Narcos del Pacifico'
    WHEN 1  THEN 'Familia Cafetera'
    WHEN 2  THEN 'El Juego del Poder'
    WHEN 3  THEN 'Los Narcos del Pacifico'
    WHEN 4  THEN 'Noche de Carnaval'
    WHEN 5  THEN 'Detectives del Caribe'
    WHEN 6  THEN 'Cafe Amargo'
    WHEN 7  THEN 'El Ministerio del Tiempo CO'
    WHEN 8  THEN 'Jovenes Hackers'
    WHEN 9  THEN 'Latidos del Tropico'
    WHEN 10 THEN 'Familia Cafetera'
    WHEN 11 THEN 'Amor en Tiempos de Vallenato'
    WHEN 12 THEN 'El Eje Cafetero Desde el Cielo'
    WHEN 13 THEN 'La Gran Apuesta'
    ELSE         'El Camino del Condor'
    END AS titulo_contenido
FROM gen g
    )
SELECT
    b.fecha_hora_inicio,
    -- 1 de cada 8 reproducciones queda sin fecha fin (usuario salio a medias)
    CASE
        WHEN MOD(b.n, 8) = 0 THEN NULL
        ELSE b.fecha_hora_inicio + NUMTODSINTERVAL(18 + b.porcentaje_avance, 'MINUTE')
        END AS fecha_hora_fin,
    b.dispositivo,
    b.porcentaje_avance,
    pl.id_perfil,
    c.id_contenido,
    el.id_episodio
FROM base b
         JOIN perfiles_lookup pl
              ON pl.perfil_pos = b.perfil_pos
         JOIN CONTENIDO c
              ON c.titulo = b.titulo_contenido
         LEFT JOIN episodios_lookup el
                   ON el.titulo_contenido = b.titulo_contenido
                       AND el.episodio_pos = CASE
                                                 WHEN b.titulo_contenido = 'Los Narcos del Pacifico'    THEN 1 + MOD(b.n - 1, 12)
                                                 WHEN b.titulo_contenido = 'Familia Cafetera'           THEN 1 + MOD(b.n - 1, 11)
                                                 WHEN b.titulo_contenido = 'Detectives del Caribe'      THEN 1 + MOD(b.n - 1, 12)
                                                 WHEN b.titulo_contenido = 'El Ministerio del Tiempo CO' THEN 1 + MOD(b.n - 1, 11)
                                                 WHEN b.titulo_contenido = 'La Historia que No Te Contaron' THEN 1 + MOD(b.n - 1, 4)
                                                 ELSE NULL
                           END;

COMMIT;


-- =============================================================================
-- 2. PAGOS ADICIONALES — 60 registros
--    Los 80 pagos de V4 cubren ene-dic 2024 (ADD_MONTHS desde 2024-01-15,
--    MOD 12 meses). Se agregan 60 pagos para cubrir ene-dic 2025 y ene-abr 2026.
--    Distribucion:
--      ene-dic 2025 : 42 pagos (un pago mensual por usuario activo en ~14)
--      ene-abr 2026 : 18 pagos (4 meses x ~4-5 usuarios distintos)
--    Metodos ya con los valores corregidos por V4.1:
--      TARJETA_CREDITO, TARJETA_DEBITO, PSE, NEQUI, DAVIPLATA, EFECTIVO
--    Estados corregidos: EXITOSO, FALLIDO, PENDIENTE, REEMBOLSADO
-- =============================================================================
INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
WITH usuarios_activos AS (
    SELECT
        id_usuario,
        id_plan,
        ROW_NUMBER() OVER (ORDER BY ciudad_residencia, id_plan, id_usuario) AS rn
    FROM USUARIOS
    WHERE estado_cuenta IN ('ACTIVO', 'INACTIVO')  -- incluir inactivos: pueden tener pagos historicos
), gen AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 60
    )
SELECT
    -- 2025: n=1..42 → ADD_MONTHS desde 2025-01-10 ciclando 12 meses
    -- 2026: n=43..60 → ADD_MONTHS desde 2026-01-08 ciclando 4 meses
    CASE
        WHEN g.n <= 42
            THEN ADD_MONTHS(DATE '2025-01-10', MOD(g.n - 1, 12)) + MOD(g.n, 15)
        ELSE
            ADD_MONTHS(DATE '2026-01-08', MOD(g.n - 43, 4)) + MOD(g.n, 10)
        END AS fecha_pago,
    ROUND(
            CASE ua.id_plan
                WHEN 1 THEN 14900
                WHEN 2 THEN 24900
                ELSE 34900
                END *
            (1 - CASE
                     WHEN MOD(g.n, 11) = 0 THEN 0.15  -- descuento 15% por referido
                     WHEN MOD(g.n, 7)  = 0 THEN 0.10  -- descuento 10%
                     ELSE 0
                END),
            0
    ) AS monto,
    -- Metodos con valores corregidos (post-V4.1)
    CASE MOD(g.n, 10)
        WHEN 0 THEN 'PSE'
        WHEN 1 THEN 'TARJETA_CREDITO'
        WHEN 2 THEN 'NEQUI'
        WHEN 3 THEN 'TARJETA_DEBITO'
        WHEN 4 THEN 'DAVIPLATA'
        WHEN 5 THEN 'PSE'
        WHEN 6 THEN 'TARJETA_CREDITO'
        WHEN 7 THEN 'EFECTIVO'
        WHEN 8 THEN 'TARJETA_DEBITO'
        ELSE         'NEQUI'
        END AS metodo_pago,
    -- Estados con valores corregidos (post-V4.1)
    -- Asimetria: mayoria exitosos, algunos fallidos/pendientes
    CASE
        WHEN MOD(g.n, 20) = 0 THEN 'REEMBOLSADO'
        WHEN MOD(g.n, 13) = 0 THEN 'FALLIDO'
        WHEN MOD(g.n, 9)  = 0 THEN 'PENDIENTE'
        ELSE 'EXITOSO'
        END AS estado_pago,
    CASE
        WHEN MOD(g.n, 11) = 0 THEN 15
        WHEN MOD(g.n, 7)  = 0 THEN 10
        ELSE 0
        END AS descuento_aplicado,
    ua.id_usuario
FROM gen g
         JOIN usuarios_activos ua
              ON ua.rn = MOD(g.n - 1, 28) + 1;  -- ciclar entre los 28 usuarios activos/inactivos

COMMIT;


-- =============================================================================
-- 3. CALIFICACIONES ADICIONALES — hasta 30 registros
--    Se toman directamente los pares unicos perfil-contenido de reproducciones
--    nuevas que aun no tienen calificacion. Este enfoque evita duplicados
--    internos (el JOIN con gen generaba el mismo par varias veces).
-- =============================================================================
INSERT INTO CALIFICACIONES (estrellas, resena, fecha_calificacion, id_perfil, id_contenido)
SELECT
    CASE MOD(rn - 1, 10)
        WHEN 0 THEN 5
        WHEN 1 THEN 4
        WHEN 2 THEN 5
        WHEN 3 THEN 3
        WHEN 4 THEN 5
        WHEN 5 THEN 4
        WHEN 6 THEN 2
        WHEN 7 THEN 5
        WHEN 8 THEN 4
        ELSE        3
        END AS estrellas,
    CASE MOD(rn - 1, 8)
        WHEN 0 THEN 'Excelente produccion nacional, muy recomendada.'
        WHEN 1 THEN 'Buen contenido para ver en familia.'
        WHEN 2 THEN 'Supero mis expectativas, historia bien contada.'
        WHEN 3 THEN 'Correcta, aunque esperaba un poco mas.'
        WHEN 4 THEN 'De lo mejor del catalogo colombiano.'
        WHEN 5 THEN 'Muy entretenida, la vi de una sentada.'
        WHEN 6 THEN 'Le falta ritmo en los primeros episodios.'
        ELSE        'Gran historia, personajes muy bien desarrollados.'
        END AS resena,
    CASE
        WHEN rn <= 20 THEN DATE '2025-07-01' + MOD(rn * 11, 184)
        ELSE               DATE '2026-01-05' + MOD(rn * 7,  115)
        END AS fecha_calificacion,
    id_perfil,
    id_contenido
FROM (
         -- Nivel 2: numerar los pares YA unicos
         SELECT id_perfil, id_contenido,
                ROW_NUMBER() OVER (ORDER BY id_perfil, id_contenido) AS rn
         FROM (
                  -- Nivel 1: garantizar unicidad via GROUP BY antes de numerar
                  SELECT r.id_perfil, r.id_contenido
                  FROM REPRODUCCIONES r
                  WHERE r.fecha_hora_inicio >= TIMESTAMP '2025-06-01 00:00:00'
                    AND r.porcentaje_avance >= 75
                    AND NOT EXISTS (
                      SELECT 1 FROM CALIFICACIONES c
                      WHERE c.id_perfil    = r.id_perfil
                        AND c.id_contenido = r.id_contenido
                  )
                  GROUP BY r.id_perfil, r.id_contenido  -- garantiza un solo registro por par
              )
     )
WHERE rn <= 30;

COMMIT;


-- =============================================================================
-- 4. FAVORITOS ADICIONALES — 20 registros
--    El enunciado pide 40 favoritos. V4 ya tiene 40, estos son extra para
--    enriquecer el catalogo de preferencias con contenidos de 2025-2026.
--    Se evita duplicar pares id_perfil + id_contenido ya existentes.
-- =============================================================================
INSERT INTO FAVORITOS (fecha_agregado, id_perfil, id_contenido)
WITH contenidos_populares AS (
    -- Los contenidos mas reproducidos en el periodo nuevo
    SELECT r.id_contenido,
           COUNT(*) AS total_repros,
           ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn
    FROM REPRODUCCIONES r
    WHERE r.fecha_hora_inicio >= TIMESTAMP '2025-06-01 00:00:00'
    GROUP BY r.id_contenido
), perfiles_activos AS (
    SELECT p.id_perfil,
           ROW_NUMBER() OVER (ORDER BY p.id_perfil) AS rn
    FROM PERFILES p
             JOIN USUARIOS u ON u.id_usuario = p.id_usuario
    WHERE u.estado_cuenta = 'ACTIVO'
), gen AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 20
    )
SELECT
    DATE '2025-08-01' + MOD(g.n * 13, 270) AS fecha_agregado,  -- ago 2025 - abr 2026
    pa.id_perfil,
    cp.id_contenido
FROM gen g
         JOIN perfiles_activos pa ON pa.rn = MOD(g.n - 1, 30) + 1
         JOIN contenidos_populares cp ON cp.rn = MOD(g.n - 1, 10) + 1
WHERE NOT EXISTS (
    SELECT 1 FROM FAVORITOS f
    WHERE f.id_perfil   = pa.id_perfil
      AND f.id_contenido = cp.id_contenido
);

COMMIT;


-- =============================================================================
-- VERIFICACION — ejecutar despues del script para confirmar:
--
-- 1) Total de reproducciones por año (debe mostrar 2024, 2025, 2026):
-- SELECT EXTRACT(YEAR FROM fecha_hora_inicio) anio, COUNT(*) total
-- FROM REPRODUCCIONES
-- GROUP BY EXTRACT(YEAR FROM fecha_hora_inicio)
-- ORDER BY anio;
--
-- 2) Total de pagos por año:
-- SELECT EXTRACT(YEAR FROM fecha_pago) anio, COUNT(*) total, SUM(monto) ingresos
-- FROM PAGOS
-- GROUP BY EXTRACT(YEAR FROM fecha_pago)
-- ORDER BY anio;
--
-- 3) Conteos generales:
-- SELECT 'REPRODUCCIONES' tabla, COUNT(*) total FROM REPRODUCCIONES UNION ALL
-- SELECT 'PAGOS',                COUNT(*)        FROM PAGOS          UNION ALL
-- SELECT 'CALIFICACIONES',       COUNT(*)        FROM CALIFICACIONES  UNION ALL
-- SELECT 'FAVORITOS',            COUNT(*)        FROM FAVORITOS;
-- Esperado: REPRODUCCIONES>=320, PAGOS>=140, CALIFICACIONES>=90, FAVORITOS>=60
--
-- 4) Verificar particiones en REPRODUCCIONES:
-- SELECT partition_name, num_rows
-- FROM user_tab_partitions
-- WHERE table_name = 'REPRODUCCIONES'
-- ORDER BY partition_position;
-- =============================================================================