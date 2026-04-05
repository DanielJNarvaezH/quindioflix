-- =============================================================================
-- MOD-5: Datos de Prueba — Tablas Maestras | QuindioFlix
-- Script  : V3__datos_maestros.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Datos   : 3 PLANES, 5 CATEGORIAS, 8 GENEROS, 5 DEPARTAMENTOS,
--           10 EMPLEADOS, 40 CONTENIDOS distribuidos asimetricamente.
-- Nota    : Los datos son ASIMETRICOS a proposito para que las consultas
--           avanzadas del NT1 (ROLLUP, CUBE, PIVOT) produzcan resultados
--           interesantes y no uniformes.
-- =============================================================================


-- =============================================================================
-- 1. PLANES (3 registros)
--    Basico: 1 pantalla SD $14.900 | Estandar: 2 pantallas HD $24.900
--    Premium: 4 pantallas 4K $34.900
-- =============================================================================
INSERT INTO PLANES (nombre, precio_mensual, max_pantallas, calidad_video, max_perfiles)
VALUES ('Basico', 14900, 1, 'SD', 2);

INSERT INTO PLANES (nombre, precio_mensual, max_pantallas, calidad_video, max_perfiles)
VALUES ('Estandar', 24900, 2, 'HD', 3);

INSERT INTO PLANES (nombre, precio_mensual, max_pantallas, calidad_video, max_perfiles)
VALUES ('Premium', 34900, 4, '4K', 5);


-- =============================================================================
-- 2. CATEGORIAS (5 registros)
-- =============================================================================
INSERT INTO CATEGORIAS (nombre) VALUES ('Peliculas');
INSERT INTO CATEGORIAS (nombre) VALUES ('Series');
INSERT INTO CATEGORIAS (nombre) VALUES ('Documentales');
INSERT INTO CATEGORIAS (nombre) VALUES ('Musica');
INSERT INTO CATEGORIAS (nombre) VALUES ('Podcasts');


-- =============================================================================
-- 3. GENEROS (8 registros)
-- =============================================================================
INSERT INTO GENEROS (nombre) VALUES ('Accion');
INSERT INTO GENEROS (nombre) VALUES ('Comedia');
INSERT INTO GENEROS (nombre) VALUES ('Drama');
INSERT INTO GENEROS (nombre) VALUES ('Suspenso');
INSERT INTO GENEROS (nombre) VALUES ('Ciencia Ficcion');
INSERT INTO GENEROS (nombre) VALUES ('Terror');
INSERT INTO GENEROS (nombre) VALUES ('Romance');
INSERT INTO GENEROS (nombre) VALUES ('Documental');


-- =============================================================================
-- 4. DEPARTAMENTOS (5 registros)
--    id_jefe se actualiza al final del script, una vez insertados
--    los empleados. Se deja NULL por ahora para evitar FK ciclica.
-- =============================================================================
INSERT INTO DEPARTAMENTOS (nombre, id_jefe) VALUES ('Tecnologia', NULL);
INSERT INTO DEPARTAMENTOS (nombre, id_jefe) VALUES ('Contenido', NULL);
INSERT INTO DEPARTAMENTOS (nombre, id_jefe) VALUES ('Marketing', NULL);
INSERT INTO DEPARTAMENTOS (nombre, id_jefe) VALUES ('Soporte', NULL);
INSERT INTO DEPARTAMENTOS (nombre, id_jefe) VALUES ('Finanzas', NULL);


-- =============================================================================
-- 5. EMPLEADOS (10 registros)
--    Distribucion asimetrica (realista para una empresa de streaming):
--      Tecnologia : 1 (infra minima, equipo externo contratado)
--      Contenido  : 4 (equipo mas grande; publican y gestionan catalogo)
--      Marketing  : 1
--      Soporte    : 3 (atienden reportes y usuarios; segundo equipo mas grande)
--      Finanzas   : 1
--    Cada departamento tiene un jefe. El jefe pertenece al mismo departamento.
--    Algunos empleados tienen supervisor, otros no (jefes no tienen supervisor).
-- =============================================================================

-- ---- Tecnologia (id_departamento = 1) ----
-- Empleado 1: Jefe de Tecnologia, sin supervisor
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Ricardo', 'Montoya', 'r.montoya@quindioflix.co', 'Jefe de Tecnologia', DATE '2020-03-15', 8500000, 1, NULL);

-- ---- Contenido (id_departamento = 2) ----
-- Empleado 2: Jefe de Contenido, sin supervisor
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Lucia', 'Rios', 'l.rios@quindioflix.co', 'Jefe de Contenido', DATE '2019-07-01', 9000000, 2, NULL);

-- Empleado 3: Analista de Contenido, supervisor = Lucia Rios (id 2)
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Andres', 'Castillo', 'a.castillo@quindioflix.co', 'Analista de Contenido', DATE '2021-02-10', 4200000, 2, 2);

-- Empleado 4: Coordinador de Catalogo, supervisor = Lucia Rios (id 2)
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Valentina', 'Torres', 'v.torres@quindioflix.co', 'Coordinadora de Catalogo', DATE '2021-08-20', 4800000, 2, 2);

-- Empleado 5: Editor de Contenido, supervisor = Lucia Rios (id 2)
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Sebastian', 'Mora', 's.mora@quindioflix.co', 'Editor de Contenido', DATE '2022-05-05', 3900000, 2, 2);

-- ---- Marketing (id_departamento = 3) ----
-- Empleado 6: Jefe de Marketing, sin supervisor
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Camila', 'Herrera', 'c.herrera@quindioflix.co', 'Jefe de Marketing', DATE '2020-11-01', 7800000, 3, NULL);

-- ---- Soporte (id_departamento = 4) ----
-- Empleado 7: Jefe de Soporte, sin supervisor
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Jorge', 'Ramirez', 'j.ramirez@quindioflix.co', 'Jefe de Soporte', DATE '2020-06-15', 7200000, 4, NULL);

-- Empleado 8: Agente de Soporte, supervisor = Jorge Ramirez (id 7)
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Daniela', 'Gutierrez', 'd.gutierrez@quindioflix.co', 'Agente de Soporte', DATE '2022-09-12', 3200000, 4, 7);

-- Empleado 9: Agente de Soporte, supervisor = Jorge Ramirez (id 7)
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Felipe', 'Vargas', 'f.vargas@quindioflix.co', 'Agente de Soporte', DATE '2023-01-20', 3200000, 4, 7);

-- ---- Finanzas (id_departamento = 5) ----
-- Empleado 10: Jefe de Finanzas, sin supervisor
INSERT INTO EMPLEADOS (nombre, apellido, email, cargo, fecha_ingreso, salario, id_departamento, id_supervisor)
VALUES ('Mariana', 'Lopez', 'm.lopez@quindioflix.co', 'Jefe de Finanzas', DATE '2019-04-01', 8800000, 5, NULL);


-- =============================================================================
-- 5.1 Actualizar id_jefe en DEPARTAMENTOS
--     Ahora que los empleados existen, se asigna el jefe de cada departamento.
--     Los jefes son los primeros empleados de cada departamento (los que
--     no tienen supervisor).
-- =============================================================================
UPDATE DEPARTAMENTOS SET id_jefe = 1  WHERE nombre = 'Tecnologia';  -- Ricardo Montoya
UPDATE DEPARTAMENTOS SET id_jefe = 2  WHERE nombre = 'Contenido';   -- Lucia Rios
UPDATE DEPARTAMENTOS SET id_jefe = 6  WHERE nombre = 'Marketing';   -- Camila Herrera
UPDATE DEPARTAMENTOS SET id_jefe = 7  WHERE nombre = 'Soporte';     -- Jorge Ramirez
UPDATE DEPARTAMENTOS SET id_jefe = 10 WHERE nombre = 'Finanzas';    -- Mariana Lopez


-- =============================================================================
-- 6. CONTENIDO (40 registros)
--    Distribucion asimetrica (refleja una plataforma de streaming real):
--      Peliculas    : 16 (categoria dominante)
--      Series       : 12 (segunda mas popular)
--      Documentales :  6
--      Musica       :  4
--      Podcasts     :  2
--    Empleados que publican contenido pertenecen al departamento Contenido
--    (ids 2, 3, 4, 5). Se distribuyen asimetricamente entre ellos.
--    Clasificaciones variadas para permitir pruebas de acceso infantil.
--    Mezcla de originales QuindioFlix y contenido licenciado.
-- =============================================================================

-- ============================================================
-- PELICULAS (id_categoria = 1) — 16 registros
-- ============================================================
INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Ultimo Vuelo', 'Un piloto debe salvar su avion en medio de una tormenta electrica sobre el Pacifico.', 2022, 118, '+13', 'N', 87.5, 1, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Cafe Amargo', 'Comedia romantica ambientada en un pueblo cafetero del Quindio.', 2023, 95, 'TP', 'S', 92.1, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Sombras del Pasado', 'Un detective retirado investiga su propio pasado en Bogota.', 2021, 132, '+16', 'N', 74.3, 1, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Gran Apuesta', 'Thriller financiero sobre el colapso de una multinacional colombiana.', 2023, 110, '+13', 'S', 88.9, 1, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Marea Roja', 'Accion submarina: un equipo de rescate enfrenta una catastrofe en el fondo del mar.', 2022, 125, '+13', 'N', 81.2, 1, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Noche de Carnaval', 'Una familia barranquillera vive una noche memorable durante el Carnaval.', 2024, 88, 'TP', 'S', 95.4, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Herencia Maldita', 'Terror psicologico: una herencia familiar esconde un oscuro secreto.', 2021, 105, '+18', 'N', 69.7, 1, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Camino del Condor', 'Aventura familiar por la cordillera de los Andes.', 2023, 97, 'TP', 'S', 90.8, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Codigo Cero', 'Ciencia ficcion: un hacker descubre que la realidad es una simulacion.', 2022, 140, '+13', 'N', 83.6, 1, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Entre Flores', 'Drama romantico en un pueblo floricultor de Cundinamarca.', 2024, 102, '+7', 'S', 76.2, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Fractura', 'Suspense medico: un cirujano debe operar bajo amenaza de muerte.', 2023, 115, '+16', 'N', 79.4, 1, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Velocidad Maxima', 'Accion: pilotos ilegales compiten en las curvas de la montana antioquena.', 2022, 98, '+13', 'S', 86.3, 1, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Detective y la Orquidea', 'Misterio botanico: un detective investiga robos en el Jardin Botanico de Medellin.', 2021, 108, '+7', 'N', 71.8, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Apocalipsis Verde', 'Ciencia ficcion: un virus desconocido convierte la selva amazonica en zona de exclusion.', 2024, 122, '+16', 'S', 84.7, 1, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Amor en Tiempos de Vallenato', 'Comedia romantica musical ambientada en Valledupar.', 2023, 93, 'TP', 'S', 91.5, 1, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Sombra del Libertador', 'Drama historico sobre los ultimos dias de Simon Bolivar.', 2022, 148, '+13', 'N', 78.9, 1, 2);

-- ============================================================
-- SERIES (id_categoria = 2) — 12 registros
-- ============================================================
INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Los Narcos del Pacifico', 'Thriller: el ascenso de un cartel en el litoral pacifico colombiano.', 2022, NULL, '+18', 'S', 96.2, 2, 2);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Familia Cafetera', 'Comedia familiar sobre tres generaciones de caficultores quindianenses.', 2023, NULL, 'TP', 'S', 94.8, 2, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Clinica Central', 'Drama medico en el hospital mas grande de Bogota.', 2021, NULL, '+13', 'N', 82.4, 2, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Detectives del Caribe', 'Policial: dos detectives resuelven crimenes en las islas del Caribe colombiano.', 2023, NULL, '+13', 'S', 89.1, 2, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Ministerio del Tiempo CO', 'Ciencia ficcion: agentes viajan en el tiempo para proteger la historia colombiana.', 2024, NULL, '+7', 'S', 93.7, 2, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Sabores de Colombia', 'Reality culinario donde chefs compiten usando ingredientes de cada region.', 2022, NULL, 'TP', 'N', 88.3, 2, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Tierra Roja', 'Drama: conflicto por tierras entre familias campesinas en el Tolima.', 2021, NULL, '+16', 'S', 77.6, 2, 2);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Jovenes Hackers', 'Thriller tecnologico: adolescentes descubren una red de corrupcion gubernamental.', 2023, NULL, '+13', 'S', 85.9, 2, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Reina de Oro', 'Drama: la historia de una mujer que construye un imperio esmeraldero en Boyaca.', 2022, NULL, '+16', 'N', 80.1, 2, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Monstruos de la Sabana', 'Terror sobrenatural en los llanos orientales colombianos.', 2024, NULL, '+18', 'S', 72.4, 2, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Juego del Poder', 'Suspenso politico: una asesora presidencial descubre un complot.', 2023, NULL, '+16', 'S', 91.3, 2, 2);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Amor Prohibition', 'Romance: dos j√≥venes de familias rivales en el barrio La Candelaria.', 2024, NULL, '+7', 'S', 87.6, 2, 4);

-- ============================================================
-- DOCUMENTALES (id_categoria = 3) — 6 registros
-- ============================================================
INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('El Eje Cafetero Desde el Cielo', 'Documental aereo del paisaje cultural cafetero declarado Patrimonio de la Humanidad.', 2022, 75, 'TP', 'S', 85.2, 3, 2);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Amazonas: El Pulmon que Respira', 'La biodiversidad del Amazonas colombiano y las amenazas que enfrenta.', 2023, 90, 'TP', 'N', 79.8, 3, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Cumbia: Raices de un Pueblo', 'Documental musical sobre el origen y evolucion de la cumbia colombiana.', 2021, 68, 'TP', 'S', 73.5, 3, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Ruta de las Esmeraldas', 'Investigacion sobre la extraccion y comercio de esmeraldas en Boyaca.', 2022, 82, '+13', 'N', 68.9, 3, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Mares de Colombia', 'Exploracion submarina del Pacifico y el Caribe colombiano.', 2024, 95, 'TP', 'S', 81.7, 3, 3);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Pioneros del Valle', 'Historia de los empresarios que transformaron el Valle del Cauca en el siglo XX.', 2023, 78, '+7', 'S', 66.3, 3, 2);

-- ============================================================
-- MUSICA (id_categoria = 4) — 4 registros
-- ============================================================
INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Latidos del Tropico', 'Coleccion de vallenatos clasicos interpretados por nuevos artistas colombianos.', 2023, 58, 'TP', 'S', 88.4, 4, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Rock Andino Vol. 1', 'Lo mejor del rock colombiano de los 90 y 2000.', 2022, 72, '+13', 'N', 76.1, 4, 5);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Salsa Cali Pura', 'Concierto en vivo de las mejores orquestas de salsa calena.', 2024, 65, 'TP', 'S', 91.9, 4, 4);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Urbano Colombia', 'Los exitos del reggaeton y trap colombiano de los ultimos tres anos.', 2024, 55, '+13', 'S', 93.2, 4, 3);

-- ============================================================
-- PODCASTS (id_categoria = 5) — 2 registros
-- ============================================================
INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('La Historia que No Te Contaron', 'Podcast de historia colombiana: episodios olvidados que cambiaron el pais.', 2023, NULL, 'TP', 'S', 84.6, 5, 2);

INSERT INTO CONTENIDO (titulo, sinopsis, anio_lanzamiento, duracion_min, clasificacion_edad, es_original_quindioflix, popularidad, id_categoria, id_empleado_publicacion)
VALUES ('Emprender en Colombia', 'Historias de exito y fracaso de emprendedores colombianos en diferentes sectores.', 2024, NULL, 'TP', 'S', 78.3, 5, 3);


COMMIT;

-- =============================================================================
-- VERIFICACION — ejecutar en SQL Developer para confirmar los datos:
--
-- SELECT 'PLANES'       AS tabla, COUNT(*) AS registros FROM PLANES       UNION ALL
-- SELECT 'CATEGORIAS',           COUNT(*)               FROM CATEGORIAS    UNION ALL
-- SELECT 'GENEROS',              COUNT(*)               FROM GENEROS       UNION ALL
-- SELECT 'DEPARTAMENTOS',        COUNT(*)               FROM DEPARTAMENTOS UNION ALL
-- SELECT 'EMPLEADOS',            COUNT(*)               FROM EMPLEADOS     UNION ALL
-- SELECT 'CONTENIDO',            COUNT(*)               FROM CONTENIDO;
--
-- Resultado esperado:
--   PLANES        3
--   CATEGORIAS    5
--   GENEROS       8
--   DEPARTAMENTOS 5
--   EMPLEADOS    10
--   CONTENIDO    40
-- =============================================================================
