-- =============================================================================
-- V3.1: Correcciones a datos maestros — QuindioFlix
-- Script  : V3.1__fix_datos_maestros_generos_relaciones.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Motivo  : V3__datos_maestros.sql no poblo CONTENIDO_GENEROS ni
--           CONTENIDO_RELACIONADO, y omitio el genero 'Infantil' que el
--           enunciado lista explicitamente (seccion 4, tabla de datos).
--           Sin CONTENIDO_GENEROS las consultas NT1 por genero devuelven
--           resultados vacios (GROUPING SETS, consulta parametrizada).
-- Cambios:
--   1. GENEROS          — insertar 'Infantil' (noveno genero del enunciado)
--   2. CONTENIDO_GENEROS — 63 asociaciones para los 40 contenidos del catalogo
--   3. CONTENIDO_RELACIONADO — 8 relaciones entre contenidos (seccion 1.1)
-- =============================================================================


-- =============================================================================
-- 1. GENEROS — Agregar Infantil
--    El enunciado (seccion 4) lista exactamente:
--    Accion, Comedia, Drama, Suspenso, Romance, Ciencia Ficcion, Terror, Infantil
--    V3 inserto Documental en lugar de Infantil. Documental se conserva como
--    genero valido ("entre otros que el grupo considere"); Infantil se agrega.
-- =============================================================================
INSERT INTO GENEROS (nombre) VALUES ('Infantil');


-- =============================================================================
-- 2. CONTENIDO_GENEROS — Asociar los 40 contenidos con sus generos
--    IDs de genero insertados por V3 + este script:
--      1=Accion  2=Comedia  3=Drama  4=Suspenso  5=Ciencia Ficcion
--      6=Terror  7=Romance  8=Documental  9=Infantil (este script)
--    Los IDs de contenido se resuelven por titulo para evitar dependencia
--    de valores de IDENTITY que pueden variar entre instalaciones.
-- =============================================================================
INSERT INTO CONTENIDO_GENEROS (id_contenido, id_genero)
WITH gen_seed AS (
    -- PELICULAS
    SELECT 'El Ultimo Vuelo'                    titulo, 'Suspenso'        genero FROM DUAL UNION ALL
    SELECT 'El Ultimo Vuelo',                           'Accion'                 FROM DUAL UNION ALL
    SELECT 'Cafe Amargo',                               'Drama'                  FROM DUAL UNION ALL
    SELECT 'Cafe Amargo',                               'Romance'                FROM DUAL UNION ALL
    SELECT 'Sombras del Pasado',                        'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Sombras del Pasado',                        'Drama'                  FROM DUAL UNION ALL
    SELECT 'La Gran Apuesta',                           'Suspenso'               FROM DUAL UNION ALL
    SELECT 'La Gran Apuesta',                           'Drama'                  FROM DUAL UNION ALL
    SELECT 'Marea Roja',                                'Accion'                 FROM DUAL UNION ALL
    SELECT 'Marea Roja',                                'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Noche de Carnaval',                         'Comedia'                FROM DUAL UNION ALL
    SELECT 'Noche de Carnaval',                         'Romance'                FROM DUAL UNION ALL
    SELECT 'Herencia Maldita',                          'Drama'                  FROM DUAL UNION ALL
    SELECT 'Herencia Maldita',                          'Suspenso'               FROM DUAL UNION ALL
    SELECT 'El Camino del Condor',                      'Drama'                  FROM DUAL UNION ALL
    SELECT 'Codigo Cero',                               'Accion'                 FROM DUAL UNION ALL
    SELECT 'Codigo Cero',                               'Ciencia Ficcion'        FROM DUAL UNION ALL
    SELECT 'Entre Flores',                              'Romance'                FROM DUAL UNION ALL
    SELECT 'Entre Flores',                              'Infantil'               FROM DUAL UNION ALL
    SELECT 'La Fractura',                               'Drama'                  FROM DUAL UNION ALL
    SELECT 'La Fractura',                               'Accion'                 FROM DUAL UNION ALL
    SELECT 'Velocidad Maxima',                          'Accion'                 FROM DUAL UNION ALL
    SELECT 'El Detective y la Orquidea',                'Suspenso'               FROM DUAL UNION ALL
    SELECT 'El Detective y la Orquidea',                'Drama'                  FROM DUAL UNION ALL
    SELECT 'Apocalipsis Verde',                         'Ciencia Ficcion'        FROM DUAL UNION ALL
    SELECT 'Apocalipsis Verde',                         'Terror'                 FROM DUAL UNION ALL
    SELECT 'Amor en Tiempos de Vallenato',              'Romance'                FROM DUAL UNION ALL
    SELECT 'Amor en Tiempos de Vallenato',              'Comedia'                FROM DUAL UNION ALL
    SELECT 'La Sombra del Libertador',                  'Drama'                  FROM DUAL UNION ALL
    -- SERIES
    SELECT 'Los Narcos del Pacifico',                   'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico',                   'Drama'                  FROM DUAL UNION ALL
    SELECT 'Familia Cafetera',                          'Comedia'                FROM DUAL UNION ALL
    SELECT 'Familia Cafetera',                          'Drama'                  FROM DUAL UNION ALL
    SELECT 'Familia Cafetera',                          'Infantil'               FROM DUAL UNION ALL
    SELECT 'Clinica Central',                           'Drama'                  FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe',                     'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe',                     'Accion'                 FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO',               'Ciencia Ficcion'        FROM DUAL UNION ALL
    SELECT 'El Ministerio del Tiempo CO',               'Accion'                 FROM DUAL UNION ALL
    SELECT 'Sabores de Colombia',                       'Comedia'                FROM DUAL UNION ALL
    SELECT 'Tierra Roja',                               'Drama'                  FROM DUAL UNION ALL
    SELECT 'Jovenes Hackers',                           'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Jovenes Hackers',                           'Ciencia Ficcion'        FROM DUAL UNION ALL
    SELECT 'La Reina de Oro',                           'Drama'                  FROM DUAL UNION ALL
    SELECT 'Monstruos de la Sabana',                    'Terror'                 FROM DUAL UNION ALL
    SELECT 'El Juego del Poder',                        'Suspenso'               FROM DUAL UNION ALL
    SELECT 'El Juego del Poder',                        'Drama'                  FROM DUAL UNION ALL
    SELECT 'Amor Prohibition',                          'Romance'                FROM DUAL UNION ALL
    SELECT 'Amor Prohibition',                          'Drama'                  FROM DUAL UNION ALL
    -- DOCUMENTALES
    SELECT 'El Eje Cafetero Desde el Cielo',            'Documental'             FROM DUAL UNION ALL
    SELECT 'Amazonas: El Pulmon que Respira',           'Documental'             FROM DUAL UNION ALL
    SELECT 'Cumbia: Raices de un Pueblo',               'Documental'             FROM DUAL UNION ALL
    SELECT 'La Ruta de las Esmeraldas',                 'Documental'             FROM DUAL UNION ALL
    SELECT 'La Ruta de las Esmeraldas',                 'Suspenso'               FROM DUAL UNION ALL
    SELECT 'Mares de Colombia',                         'Documental'             FROM DUAL UNION ALL
    SELECT 'Pioneros del Valle',                        'Documental'             FROM DUAL UNION ALL
    SELECT 'Pioneros del Valle',                        'Drama'                  FROM DUAL UNION ALL
    -- MUSICA
    SELECT 'Latidos del Tropico',                       'Romance'                FROM DUAL UNION ALL
    SELECT 'Rock Andino Vol. 1',                        'Accion'                 FROM DUAL UNION ALL
    SELECT 'Salsa Cali Pura',                           'Romance'                FROM DUAL UNION ALL
    SELECT 'Salsa Cali Pura',                           'Comedia'                FROM DUAL UNION ALL
    SELECT 'Urbano Colombia',                           'Accion'                 FROM DUAL UNION ALL
    -- PODCASTS
    SELECT 'La Historia que No Te Contaron',            'Documental'             FROM DUAL UNION ALL
    SELECT 'Emprender en Colombia',                     'Drama'                  FROM DUAL
)
SELECT c.id_contenido, g.id_genero
FROM gen_seed gs
         JOIN CONTENIDO c ON c.titulo = gs.titulo
         JOIN GENEROS   g ON g.nombre = gs.genero;


-- =============================================================================
-- 3. CONTENIDO_RELACIONADO — Relaciones entre contenidos
--    El enunciado (seccion 1.1) dice: "QuindioFlix permite asociar contenido
--    relacionado entre si... secuela, precuela, remake, spin-off..."
--    La tabla existia en V2 pero quedo sin datos en V3.
-- =============================================================================
INSERT INTO CONTENIDO_RELACIONADO (id_origen, id_destino, tipo_relacion)
WITH rel_seed AS (
    SELECT 'El Ultimo Vuelo'              titulo_origen, 'Codigo Cero'                   titulo_destino, 'SECUELA'    tipo FROM DUAL UNION ALL
    SELECT 'Sombras del Pasado',                         'La Gran Apuesta',                              'SECUELA'         FROM DUAL UNION ALL
    SELECT 'Los Narcos del Pacifico',                    'El Juego del Poder',                           'SPIN-OFF'        FROM DUAL UNION ALL
    SELECT 'Detectives del Caribe',                      'Jovenes Hackers',                              'SPIN-OFF'        FROM DUAL UNION ALL
    SELECT 'Familia Cafetera',                           'Amor Prohibition',                             'SPIN-OFF'        FROM DUAL UNION ALL
    SELECT 'El Camino del Condor',                       'El Eje Cafetero Desde el Cielo',               'ADAPTACION'      FROM DUAL UNION ALL
    SELECT 'Cumbia: Raices de un Pueblo',                'Salsa Cali Pura',                              'SPIN-OFF'        FROM DUAL UNION ALL
    SELECT 'Apocalipsis Verde',                          'Monstruos de la Sabana',                       'PRECUELA'        FROM DUAL
)
SELECT c_orig.id_contenido, c_dest.id_contenido, rs.tipo
FROM rel_seed rs
         JOIN CONTENIDO c_orig ON c_orig.titulo = rs.titulo_origen
         JOIN CONTENIDO c_dest ON c_dest.titulo = rs.titulo_destino;


COMMIT;


-- =============================================================================
-- VERIFICACION — ejecutar en SQL Developer para confirmar V3.1:
--
-- 1) Total de generos (debe ser 9):
-- SELECT COUNT(*) FROM GENEROS;
-- SELECT nombre FROM GENEROS ORDER BY id_genero;
--
-- 2) Total de asociaciones contenido-genero (debe ser 63):
-- SELECT COUNT(*) FROM CONTENIDO_GENEROS;
--
-- 3) Verificar cobertura: todo contenido tiene al menos un genero:
-- SELECT COUNT(*) FROM CONTENIDO c
-- WHERE NOT EXISTS (
--     SELECT 1 FROM CONTENIDO_GENEROS cg WHERE cg.id_contenido = c.id_contenido
-- );
-- Resultado esperado: 0 filas.
--
-- 4) Total de relaciones entre contenidos (debe ser 8):
-- SELECT COUNT(*) FROM CONTENIDO_RELACIONADO;
--
-- 5) Ver relaciones con nombres legibles:
-- SELECT co.titulo AS origen, cr.tipo_relacion, cd.titulo AS destino
-- FROM CONTENIDO_RELACIONADO cr
-- JOIN CONTENIDO co ON co.id_contenido = cr.id_origen
-- JOIN CONTENIDO cd ON cd.id_contenido = cr.id_destino
-- ORDER BY cr.tipo_relacion;
-- =============================================================================