-- =============================================================================
-- MOD-6: Datos de Prueba — Tablas Transaccionales | QuindioFlix
-- Script  : V4__datos_transaccionales.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Datos   : 30 USUARIOS, 50 PERFILES, 15 TEMPORADAS, 50 EPISODIOS,
--           80 PAGOS, 200 REPRODUCCIONES, 60 CALIFICACIONES, 40 FAVORITOS.
-- Nota    : Los datos son ASIMETRICOS a proposito para soportar NT1:
--           PIVOT, ROLLUP y vista materializada de popularidad.
-- =============================================================================


-- =============================================================================
-- 1. USUARIOS (30 registros)
--    Distribucion asimetrica:
--      Armenia   : 14
--      Pereira   : 10
--      Manizales :  6
--    Planes:
--      Basico    : 14
--      Estandar  : 10
--      Premium   :  6
--    Se incluyen algunos moderadores, estados variados y referidos.
-- =============================================================================
INSERT INTO USUARIOS (nombre, apellido, email, contrasena_hash, fecha_registro, fecha_vencimiento, estado_cuenta, es_moderador, ciudad, id_plan, id_referidor)
WITH usuarios_seed AS (
    SELECT 'Sofia' nombre, 'Perea' apellido, 'sofia.perea@quindioflix.com' email, 'hash_qf_001' contrasena_hash, DATE '2024-01-10' fecha_registro, DATE '2025-01-10' fecha_vencimiento, 'ACTIVO' estado_cuenta, 'N' es_moderador, 'Armenia' ciudad, 1 id_plan, CAST(NULL AS NUMBER(8)) id_referidor FROM DUAL UNION ALL
    SELECT 'Mateo', 'Perea', 'mateo.perea@quindioflix.com', 'hash_qf_002', DATE '2024-01-15', DATE '2025-01-15', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Valeria', 'Lozano', 'valeria.lozano@quindioflix.com', 'hash_qf_003', DATE '2024-02-01', DATE '2025-02-01', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Juan', 'Arias', 'juan.arias@quindioflix.com', 'hash_qf_004', DATE '2024-02-12', DATE '2025-02-12', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Laura', 'Giraldo', 'laura.giraldo@quindioflix.com', 'hash_qf_005', DATE '2024-03-05', DATE '2025-03-05', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Andres', 'Mejia', 'andres.mejia@quindioflix.com', 'hash_qf_006', DATE '2024-03-22', DATE '2025-03-22', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Paula', 'Mena', 'paula.mena@quindioflix.com', 'hash_qf_007', DATE '2024-04-02', DATE '2025-04-02', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Nicolas', 'Soto', 'nicolas.soto@quindioflix.com', 'hash_qf_008', DATE '2024-04-18', DATE '2025-04-18', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Juliana', 'Rendon', 'juliana.rendon@quindioflix.com', 'hash_qf_009', DATE '2024-05-01', DATE '2025-05-01', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Esteban', 'Buitrago', 'esteban.buitrago@quindioflix.com', 'hash_qf_010', DATE '2024-05-15', DATE '2025-05-15', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Maria', 'Duque', 'maria.duque@quindioflix.com', 'hash_qf_011', DATE '2024-06-03', DATE '2025-06-03', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Santiago', 'Bedoya', 'santiago.bedoya@quindioflix.com', 'hash_qf_012', DATE '2024-06-21', DATE '2025-06-21', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Daniela', 'Parra', 'daniela.parra@quindioflix.com', 'hash_qf_013', DATE '2024-07-08', DATE '2025-07-08', 'ACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Cristian', 'Salazar', 'cristian.salazar@quindioflix.com', 'hash_qf_014', DATE '2024-07-22', DATE '2025-07-22', 'INACTIVO', 'N', 'Armenia', 1, NULL FROM DUAL UNION ALL
    SELECT 'Karen', 'Restrepo', 'karen.restrepo@quindioflix.com', 'hash_qf_015', DATE '2024-01-11', DATE '2025-01-11', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Felipe', 'Londoño', 'felipe.londono@quindioflix.com', 'hash_qf_016', DATE '2024-01-28', DATE '2025-01-28', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Natalia', 'Franco', 'natalia.franco@quindioflix.com', 'hash_qf_017', DATE '2024-02-08', DATE '2025-02-08', 'ACTIVO', 'S', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'David', 'Marin', 'david.marin@quindioflix.com', 'hash_qf_018', DATE '2024-02-26', DATE '2025-02-26', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Luisa', 'Castaño', 'luisa.castano@quindioflix.com', 'hash_qf_019', DATE '2024-03-14', DATE '2025-03-14', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Sebastian', 'Roa', 'sebastian.roa@quindioflix.com', 'hash_qf_020', DATE '2024-04-06', DATE '2025-04-06', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Sara', 'Montes', 'sara.montes@quindioflix.com', 'hash_qf_021', DATE '2024-04-24', DATE '2025-04-24', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Tomas', 'Quintero', 'tomas.quintero@quindioflix.com', 'hash_qf_022', DATE '2024-05-16', DATE '2025-05-16', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Ana', 'Gomez', 'ana.gomez@quindioflix.com', 'hash_qf_023', DATE '2024-06-11', DATE '2025-06-11', 'ACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Julian', 'Colorado', 'julian.colorado@quindioflix.com', 'hash_qf_024', DATE '2024-07-03', DATE '2025-07-03', 'INACTIVO', 'N', 'Pereira', 2, NULL FROM DUAL UNION ALL
    SELECT 'Marcela', 'Botero', 'marcela.botero@quindioflix.com', 'hash_qf_025', DATE '2024-01-20', DATE '2025-01-20', 'ACTIVO', 'N', 'Manizales', 3, NULL FROM DUAL UNION ALL
    SELECT 'Pipe', 'Arango', 'pipe.arango@quindioflix.com', 'hash_qf_026', DATE '2024-02-18', DATE '2025-02-18', 'ACTIVO', 'S', 'Manizales', 3, NULL FROM DUAL UNION ALL
    SELECT 'Veronica', 'Osorio', 'veronica.osorio@quindioflix.com', 'hash_qf_027', DATE '2024-03-09', DATE '2025-03-09', 'ACTIVO', 'N', 'Manizales', 3, NULL FROM DUAL UNION ALL
    SELECT 'Camilo', 'Toro', 'camilo.toro@quindioflix.com', 'hash_qf_028', DATE '2024-04-13', DATE '2025-04-13', 'ACTIVO', 'S', 'Manizales', 3, NULL FROM DUAL UNION ALL
    SELECT 'Isabella', 'Bernal', 'isabella.bernal@quindioflix.com', 'hash_qf_029', DATE '2024-05-28', DATE '2025-05-28', 'ACTIVO', 'N', 'Manizales', 3, NULL FROM DUAL UNION ALL
    SELECT 'Samuel', 'Ocampo', 'samuel.ocampo@quindioflix.com', 'hash_qf_030', DATE '2024-06-30', DATE '2025-06-30', 'SUSPENDIDO', 'N', 'Manizales', 3, NULL FROM DUAL
)
SELECT nombre, apellido, email, contrasena_hash, fecha_registro, fecha_vencimiento, estado_cuenta, es_moderador, ciudad, id_plan, id_referidor
FROM usuarios_seed;

-- Referidos (se actualizan despues de insertar usuarios para respetar la FK reflexiva)
UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'sofia.perea@quindioflix.com')
WHERE u.email = 'mateo.perea@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'sofia.perea@quindioflix.com')
WHERE u.email = 'valeria.lozano@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'juan.arias@quindioflix.com')
WHERE u.email = 'andres.mejia@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'nicolas.soto@quindioflix.com')
WHERE u.email = 'maria.duque@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'karen.restrepo@quindioflix.com')
WHERE u.email = 'felipe.londono@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'natalia.franco@quindioflix.com')
WHERE u.email = 'david.marin@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'luisa.castano@quindioflix.com')
WHERE u.email = 'tomas.quintero@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'pipe.arango@quindioflix.com')
WHERE u.email = 'veronica.osorio@quindioflix.com';

UPDATE USUARIOS u
SET u.id_referidor = (SELECT ref.id_usuario FROM USUARIOS ref WHERE ref.email = 'camilo.toro@quindioflix.com')
WHERE u.email = 'isabella.bernal@quindioflix.com';


-- =============================================================================
-- 2. PERFILES (50 registros)
--    Se generan respetando el maximo de perfiles por plan y dejando algunos
--    perfiles INFANTIL para probar las reglas de clasificacion.
-- =============================================================================
INSERT INTO PERFILES (nombre, tipo_perfil, avatar, id_usuario)
WITH config AS (
    SELECT  1 seed_order, 'sofia.perea@quindioflix.com' email, 2 total FROM DUAL UNION ALL
    SELECT  2, 'mateo.perea@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT  3, 'valeria.lozano@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT  4, 'juan.arias@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT  5, 'laura.giraldo@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT  6, 'andres.mejia@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT  7, 'paula.mena@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT  8, 'nicolas.soto@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT  9, 'juliana.rendon@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 10, 'esteban.buitrago@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 11, 'maria.duque@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 12, 'santiago.bedoya@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 13, 'daniela.parra@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 14, 'cristian.salazar@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 15, 'karen.restrepo@quindioflix.com', 3 FROM DUAL UNION ALL
    SELECT 16, 'felipe.londono@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 17, 'natalia.franco@quindioflix.com', 3 FROM DUAL UNION ALL
    SELECT 18, 'david.marin@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 19, 'luisa.castano@quindioflix.com', 3 FROM DUAL UNION ALL
    SELECT 20, 'sebastian.roa@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 21, 'sara.montes@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 22, 'tomas.quintero@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 23, 'ana.gomez@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 24, 'julian.colorado@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 25, 'marcela.botero@quindioflix.com', 2 FROM DUAL UNION ALL
    SELECT 26, 'pipe.arango@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 27, 'veronica.osorio@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 28, 'camilo.toro@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 29, 'isabella.bernal@quindioflix.com', 1 FROM DUAL UNION ALL
    SELECT 30, 'samuel.ocampo@quindioflix.com', 1 FROM DUAL
), nums AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 5
), usuarios_base AS (
    SELECT id_usuario, email
    FROM USUARIOS
)
SELECT
    CASE
        WHEN nums.n = 1 THEN 'Principal'
        WHEN nums.n = 2 AND c.email IN (
            'sofia.perea@quindioflix.com',
            'juan.arias@quindioflix.com',
            'nicolas.soto@quindioflix.com',
            'karen.restrepo@quindioflix.com',
            'natalia.franco@quindioflix.com',
            'luisa.castano@quindioflix.com',
            'marcela.botero@quindioflix.com'
        ) THEN 'Kids'
        WHEN nums.n = 2 THEN 'Pareja'
        WHEN nums.n = 3 THEN 'Invitados'
        WHEN nums.n = 4 THEN 'Viajes'
        ELSE 'Extra'
    END AS nombre,
    CASE
        WHEN nums.n = 2 AND c.email IN (
            'sofia.perea@quindioflix.com',
            'juan.arias@quindioflix.com',
            'nicolas.soto@quindioflix.com',
            'karen.restrepo@quindioflix.com',
            'natalia.franco@quindioflix.com',
            'luisa.castano@quindioflix.com',
            'marcela.botero@quindioflix.com'
        ) THEN 'INFANTIL'
        ELSE 'ADULTO'
    END AS tipo_perfil,
    'avatar_' || c.seed_order || '_' || nums.n || '.png' AS avatar,
    u.id_usuario
FROM config c
JOIN usuarios_base u ON u.email = c.email
JOIN nums ON nums.n <= c.total
ORDER BY c.seed_order, nums.n;


-- =============================================================================
-- 3. TEMPORADAS (15 registros)
--    Solo para contenido seriado del catalogo maestro.
--    Contenidos elegidos por su potencial de consumo para NT1.
-- =============================================================================
INSERT INTO TEMPORADAS (numero_temporada, titulo_temporada, anio_estreno, id_contenido)
WITH temporadas_seed AS (
    SELECT 'Los Narcos del Pacifico' titulo_contenido, 1 numero_temporada, 'Temporada 1' titulo_temporada, 2022 anio_estreno FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico', 2, 'Temporada 2', 2023 FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico', 3, 'Temporada 3', 2024 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 1, 'Temporada 1', 2023 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 2, 'Temporada 2', 2024 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 3, 'Temporada 3', 2025 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 1, 'Temporada 1', 2023 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 2, 'Temporada 2', 2024 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 3, 'Temporada 3', 2025 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 4, 'Temporada 4', 2025 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 1, 'Temporada 1', 2024 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 2, 'Temporada 2', 2025 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 3, 'Temporada 3', 2025 FROM DUAL UNION ALL
    SELECT 'La Historia que No Te Contaron', 1, 'Temporada 1', 2023 FROM DUAL UNION ALL
    SELECT 'La Historia que No Te Contaron', 2, 'Temporada 2', 2024 FROM DUAL
)
SELECT ts.numero_temporada, ts.titulo_temporada, ts.anio_estreno, c.id_contenido
FROM temporadas_seed ts
JOIN CONTENIDO c ON c.titulo = ts.titulo_contenido;


-- =============================================================================
-- 4. EPISODIOS (50 registros)
--    Se generan a partir de las 15 temporadas creadas arriba.
-- =============================================================================
INSERT INTO EPISODIOS (numero_episodio, titulo_episodio, duracion_min, sinopsis, id_temporada)
WITH temporadas_seed AS (
    SELECT 'Los Narcos del Pacifico' titulo_contenido, 1 numero_temporada, 4 total_eps, 'Operativo Pacifico' prefijo, 52 base_dur FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico', 2, 4, 'Guerra de Puertos', 54 FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico', 3, 4, 'Caida del Imperio', 56 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 1, 4, 'Cosecha y Familia', 44 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 2, 4, 'Nuevas Tierras', 45 FROM DUAL UNION ALL
    SELECT 'Familia Cafetera', 3, 3, 'Legado Cafetero', 46 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 1, 3, 'Caso Insular', 47 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 2, 3, 'Sombras del Caribe', 48 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 3, 3, 'Red Criminal', 49 FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe', 4, 3, 'Juicio Final', 50 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 1, 4, 'Mision Temporal', 51 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 2, 3, 'Paradoja Andina', 53 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO', 3, 4, 'Cronicas Futuras', 54 FROM DUAL UNION ALL
    SELECT 'La Historia que No Te Contaron', 1, 2, 'Capitulo Historico', 38 FROM DUAL UNION ALL
    SELECT 'La Historia que No Te Contaron', 2, 2, 'Archivo Nacional', 39 FROM DUAL
), nums AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 4
), temporadas_lookup AS (
    SELECT t.id_temporada, c.titulo titulo_contenido, t.numero_temporada
    FROM TEMPORADAS t
    JOIN CONTENIDO c ON c.id_contenido = t.id_contenido
)
SELECT
    nums.n AS numero_episodio,
    ts.prefijo || ' E' || nums.n AS titulo_episodio,
    ts.base_dur + MOD(nums.n, 3) * 3 AS duracion_min,
    'Episodio ' || nums.n || ' de la temporada ' || ts.numero_temporada || ' de ' || ts.titulo_contenido || ' en el universo QuindioFlix.' AS sinopsis,
    tl.id_temporada
FROM temporadas_seed ts
JOIN temporadas_lookup tl
  ON tl.titulo_contenido = ts.titulo_contenido
 AND tl.numero_temporada = ts.numero_temporada
JOIN nums ON nums.n <= ts.total_eps
ORDER BY ts.titulo_contenido, ts.numero_temporada, nums.n;


-- =============================================================================
-- 5. PAGOS (80 registros)
--    Se generan con mayor concentracion en usuarios activos y recurrentes.
--    Los montos dependen del plan; algunos incluyen descuento por referidos.
-- =============================================================================
INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
WITH usuarios_ordenados AS (
    SELECT id_usuario, id_plan,
           ROW_NUMBER() OVER (ORDER BY ciudad, id_plan, id_usuario) rn
    FROM USUARIOS
    WHERE estado_cuenta <> 'SUSPENDIDO'
), gen AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 80
)
SELECT
    ADD_MONTHS(DATE '2024-01-15', MOD(g.n - 1, 12)) + MOD(g.n, 20) AS fecha_pago,
    ROUND(
        CASE uo.id_plan
            WHEN 1 THEN 14900
            WHEN 2 THEN 24900
            ELSE 34900
        END *
        (1 - CASE
            WHEN MOD(g.n, 13) = 0 THEN 0.15
            WHEN MOD(g.n, 9) = 0 THEN 0.10
            ELSE 0
        END),
        0
    ) AS monto,
    CASE MOD(g.n, 10)
        WHEN 0 THEN 'PSE'
        WHEN 1 THEN 'TARJETA'
        WHEN 2 THEN 'NEQUI'
        WHEN 3 THEN 'TARJETA'
        WHEN 4 THEN 'DAVIPLATA'
        WHEN 5 THEN 'PSE'
        WHEN 6 THEN 'TARJETA'
        WHEN 7 THEN 'EFECTIVO'
        WHEN 8 THEN 'PSE'
        ELSE 'TARJETA'
    END AS metodo_pago,
    CASE
        WHEN MOD(g.n, 29) = 0 THEN 'REEMBOLSADO'
        WHEN MOD(g.n, 17) = 0 THEN 'RECHAZADO'
        WHEN MOD(g.n, 11) = 0 THEN 'PENDIENTE'
        ELSE 'APROBADO'
    END AS estado_pago,
    CASE
        WHEN MOD(g.n, 13) = 0 THEN 15
        WHEN MOD(g.n, 9) = 0 THEN 10
        ELSE 0
    END AS descuento_aplicado,
    uo.id_usuario
FROM gen g
JOIN usuarios_ordenados uo
  ON uo.rn = CASE
      WHEN g.n <= 35 THEN MOD(g.n - 1, 12) + 1
      WHEN g.n <= 60 THEN MOD(g.n - 1, 20) + 1
      ELSE MOD(g.n - 1, 29) + 1
  END;


-- =============================================================================
-- 6. REPRODUCCIONES (200 registros)
--    Se distribuyen entre 2024 y 2025 para poblar ambas particiones.
--    Hay mas consumo en series y ciertos titulos populares, y el uso de
--    dispositivos es desigual para favorecer los reportes de NT1.
-- =============================================================================
INSERT INTO REPRODUCCIONES (fecha_hora_inicio, fecha_hora_fin, dispositivo, porcentaje_avance, id_perfil, id_contenido, id_episodio)
WITH gen AS (
    SELECT LEVEL n FROM DUAL CONNECT BY LEVEL <= 200
), perfiles_lookup AS (
    SELECT
        p.id_perfil,
        ROW_NUMBER() OVER (ORDER BY u.fecha_registro, u.email, p.id_perfil) AS perfil_pos
    FROM PERFILES p
    JOIN USUARIOS u ON u.id_usuario = p.id_usuario
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
        CASE
            WHEN g.n <= 90 THEN TIMESTAMP '2024-01-05 08:00:00' + NUMTODSINTERVAL((g.n - 1) * 36, 'HOUR')
            ELSE TIMESTAMP '2025-01-03 18:00:00' + NUMTODSINTERVAL((g.n - 91) * 24, 'HOUR')
        END AS fecha_hora_inicio,
        CASE MOD(g.n - 1, 10)
            WHEN 0 THEN 'CELULAR'
            WHEN 1 THEN 'TV'
            WHEN 2 THEN 'CELULAR'
            WHEN 3 THEN 'COMPUTADOR'
            WHEN 4 THEN 'TV'
            WHEN 5 THEN 'CELULAR'
            WHEN 6 THEN 'TABLET'
            WHEN 7 THEN 'TV'
            WHEN 8 THEN 'CELULAR'
            ELSE 'COMPUTADOR'
        END AS dispositivo,
        CASE MOD(g.n - 1, 8)
            WHEN 0 THEN 35
            WHEN 1 THEN 50
            WHEN 2 THEN 65
            WHEN 3 THEN 80
            WHEN 4 THEN 90
            WHEN 5 THEN 100
            WHEN 6 THEN 100
            ELSE 95
        END AS porcentaje_avance,
        CASE
            WHEN g.n <= 120 THEN MOD(g.n - 1, 25) + 1
            ELSE MOD(g.n - 1, 50) + 1
        END AS perfil_pos,
        CASE MOD(g.n - 1, 20)
            WHEN 0 THEN 'Los Narcos del Pacifico'
            WHEN 1 THEN 'Familia Cafetera'
            WHEN 2 THEN 'El Ministerio del Tiempo CO'
            WHEN 3 THEN 'El Juego del Poder'
            WHEN 4 THEN 'Noche de Carnaval'
            WHEN 5 THEN 'Cafe Amargo'
            WHEN 6 THEN 'El Eje Cafetero Desde el Cielo'
            WHEN 7 THEN 'Latidos del Tropico'
            WHEN 8 THEN 'Urbano Colombia'
            WHEN 9 THEN 'La Historia que No Te Contaron'
            WHEN 10 THEN 'El Ultimo Vuelo'
            WHEN 11 THEN 'La Gran Apuesta'
            WHEN 12 THEN 'Detectives del Caribe'
            WHEN 13 THEN 'Jovenes Hackers'
            WHEN 14 THEN 'Amazonas: El Pulmon que Respira'
            WHEN 15 THEN 'Salsa Cali Pura'
            WHEN 16 THEN 'Emprender en Colombia'
            WHEN 17 THEN 'Amor en Tiempos de Vallenato'
            WHEN 18 THEN 'Cumbia: Raices de un Pueblo'
            ELSE 'El Camino del Condor'
        END AS titulo_contenido
    FROM gen g
)
SELECT
    b.fecha_hora_inicio,
    CASE
        WHEN MOD(b.n, 9) = 0 THEN NULL
        ELSE b.fecha_hora_inicio + NUMTODSINTERVAL(20 + b.porcentaje_avance, 'MINUTE')
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
      WHEN b.titulo_contenido = 'Los Narcos del Pacifico' THEN 1  + MOD(b.n - 1, 12)
      WHEN b.titulo_contenido = 'Familia Cafetera' THEN 1  + MOD(b.n - 1, 11)
      WHEN b.titulo_contenido = 'Detectives del Caribe' THEN 1  + MOD(b.n - 1, 12)
      WHEN b.titulo_contenido = 'El Ministerio del Tiempo CO' THEN 1  + MOD(b.n - 1, 11)
      WHEN b.titulo_contenido = 'La Historia que No Te Contaron' THEN 1 + MOD(b.n - 1, 4)
      ELSE NULL
  END;


-- =============================================================================
-- 7. CALIFICACIONES (60 registros)
--    Se derivan del consumo real (reproducciones) para mantener coherencia.
--    Un perfil solo califica contenidos que ya reprodujo.
-- =============================================================================
INSERT INTO CALIFICACIONES (estrellas, resena, fecha_calificacion, id_perfil, id_contenido)
WITH pares AS (
    SELECT DISTINCT r.id_perfil, r.id_contenido
    FROM REPRODUCCIONES r
), ordenados AS (
    SELECT p.id_perfil, p.id_contenido,
           ROW_NUMBER() OVER (ORDER BY p.id_contenido, p.id_perfil) rn
    FROM pares p
)
SELECT
    CASE
        WHEN c.popularidad >= 90 THEN CASE WHEN MOD(o.rn, 5) = 0 THEN 4 ELSE 5 END
        WHEN c.popularidad >= 80 THEN CASE WHEN MOD(o.rn, 4) = 0 THEN 3 ELSE 4 END
        ELSE CASE MOD(o.rn, 3) WHEN 0 THEN 2 WHEN 1 THEN 3 ELSE 4 END
    END AS estrellas,
    CASE
        WHEN MOD(o.rn, 5) = 0 THEN 'Buen contenido para maratonear.'
        WHEN MOD(o.rn, 7) = 0 THEN 'Interesante, aunque pudo ser mejor.'
        WHEN MOD(o.rn, 9) = 0 THEN 'Muy recomendado en esta categoria.'
        ELSE NULL
    END AS resena,
    DATE '2025-02-01' + MOD(o.rn, 120) AS fecha_calificacion,
    o.id_perfil,
    o.id_contenido
FROM ordenados o
JOIN CONTENIDO c ON c.id_contenido = o.id_contenido
WHERE o.rn <= 60;


-- =============================================================================
-- 8. FAVORITOS (40 registros)
--    Tambien se derivan del consumo real, priorizando contenidos populares.
-- =============================================================================
INSERT INTO FAVORITOS (fecha_agregado, id_perfil, id_contenido)
WITH pares AS (
    SELECT DISTINCT r.id_perfil, r.id_contenido
    FROM REPRODUCCIONES r
), priorizados AS (
    SELECT p.id_perfil, p.id_contenido,
           ROW_NUMBER() OVER (ORDER BY c.popularidad DESC, p.id_perfil, p.id_contenido) rn
    FROM pares p
    JOIN CONTENIDO c ON c.id_contenido = p.id_contenido
)
SELECT
    DATE '2025-03-01' + MOD(rn, 90) AS fecha_agregado,
    id_perfil,
    id_contenido
FROM priorizados
WHERE rn <= 40;


COMMIT;

-- =============================================================================
-- VERIFICACION — ejecutar en SQL Developer / Oracle XE para validar V4:
--
-- SELECT 'USUARIOS'       AS tabla, COUNT(*) AS registros FROM USUARIOS       UNION ALL
-- SELECT 'PERFILES',               COUNT(*)               FROM PERFILES        UNION ALL
-- SELECT 'TEMPORADAS',             COUNT(*)               FROM TEMPORADAS      UNION ALL
-- SELECT 'EPISODIOS',              COUNT(*)               FROM EPISODIOS       UNION ALL
-- SELECT 'PAGOS',                  COUNT(*)               FROM PAGOS           UNION ALL
-- SELECT 'REPRODUCCIONES',         COUNT(*)               FROM REPRODUCCIONES  UNION ALL
-- SELECT 'CALIFICACIONES',         COUNT(*)               FROM CALIFICACIONES  UNION ALL
-- SELECT 'FAVORITOS',              COUNT(*)               FROM FAVORITOS;
--
-- Resultado esperado:
--   USUARIOS        30
--   PERFILES        50
--   TEMPORADAS      15
--   EPISODIOS       50
--   PAGOS           80
--   REPRODUCCIONES 200
--   CALIFICACIONES  60
--   FAVORITOS       40
--
-- 1) Verificar distribucion de usuarios por ciudad y plan (base para ROLLUP):
-- SELECT ciudad, id_plan, COUNT(*)
-- FROM USUARIOS
-- GROUP BY ciudad, id_plan
-- ORDER BY ciudad, id_plan;
--
-- 2) Verificar dispositivos y categorias (base para PIVOT):
-- SELECT c.id_categoria, r.dispositivo, COUNT(*)
-- FROM REPRODUCCIONES r
-- JOIN CONTENIDO c ON c.id_contenido = r.id_contenido
-- GROUP BY c.id_categoria, r.dispositivo
-- ORDER BY c.id_categoria, r.dispositivo;
--
-- 3) Verificar particiones 2024 / 2025:
-- SELECT partition_name, tablespace_name, high_value
-- FROM user_tab_partitions
-- WHERE table_name = 'REPRODUCCIONES'
-- ORDER BY partition_position;
--
-- 4) Confirmar que ambas particiones recibieron datos:
-- SELECT EXTRACT(YEAR FROM fecha_hora_inicio) AS anio, COUNT(*)
-- FROM REPRODUCCIONES
-- GROUP BY EXTRACT(YEAR FROM fecha_hora_inicio)
-- ORDER BY anio;
--
-- 5) Verificar que los perfiles por usuario no exceden el plan:
-- SELECT u.id_usuario, u.email, p.nombre AS plan, p.max_perfiles, COUNT(pe.id_perfil) AS perfiles_creados
-- FROM USUARIOS u
-- JOIN PLANES p   ON p.id_plan = u.id_plan
-- JOIN PERFILES pe ON pe.id_usuario = u.id_usuario
-- GROUP BY u.id_usuario, u.email, p.nombre, p.max_perfiles
-- HAVING COUNT(pe.id_perfil) > p.max_perfiles;
--
-- Resultado esperado en la consulta anterior: 0 filas.
-- =============================================================================
