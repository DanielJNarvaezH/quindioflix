-- =============================================================================
-- MOD-2: Tablespaces y Datafiles — QuindioFlix
-- Script  : V1__tablespaces.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autor   : Equipo QuindioFlix
-- Nota    : ${ruta_base} es un placeholder Flyway resuelto en tiempo de
--           ejecucion desde spring.flyway.placeholders.ruta_base en
--           application.properties. Cada integrante configura su ruta local.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ts_quindioflix_datos
--    Almacena las tablas del dominio principal: USUARIOS, PERFILES, PLANES,
--    PAGOS, CATEGORIAS, GENEROS, CONTENIDO, CONTENIDO_GENEROS,
--    CONTENIDO_RELACIONADO, TEMPORADAS, EPISODIOS, CALIFICACIONES,
--    FAVORITOS, REPORTES_INAPROPIADO, DEPARTAMENTOS, EMPLEADOS.
-- -----------------------------------------------------------------------------
CREATE TABLESPACE ts_quindioflix_datos
  DATAFILE '${ruta_base}/ts_quindioflix_datos01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M MAXSIZE 500M
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE
  SEGMENT SPACE MANAGEMENT AUTO
  ONLINE;

-- -----------------------------------------------------------------------------
-- 2. ts_quindioflix_indices
--    Almacena todos los indices de las tablas del dominio principal.
--    Separar indices de datos reduce la contension de I/O en consultas
--    frecuentes (busqueda por titulo, filtrado por categoria, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLESPACE ts_quindioflix_indices
  DATAFILE '${ruta_base}/ts_quindioflix_indices01.dbf'
    SIZE 50M
    AUTOEXTEND ON NEXT 25M MAXSIZE 200M
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE
  SEGMENT SPACE MANAGEMENT AUTO
  ONLINE;

-- -----------------------------------------------------------------------------
-- 3. ts_quindioflix_reprod_2024
--    Tablespace dedicado a la particion 2024 de la tabla REPRODUCCIONES.
--    REPRODUCCIONES es la tabla de mayor volumen del sistema (cada sesion
--    de usuario genera un registro). Particionar por anio permite purgar
--    datos historicos sin afectar la particion activa y mejora el
--    rendimiento de los reportes de consumo por periodo.
-- -----------------------------------------------------------------------------
CREATE TABLESPACE ts_quindioflix_reprod_2024
  DATAFILE '${ruta_base}/ts_quindioflix_reprod_202401.dbf'
    SIZE 200M
    AUTOEXTEND ON NEXT 100M MAXSIZE 2G
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE
  SEGMENT SPACE MANAGEMENT AUTO
  ONLINE;

-- -----------------------------------------------------------------------------
-- 4. ts_quindioflix_reprod_2025
--    Tablespace dedicado a la particion 2025 de la tabla REPRODUCCIONES.
--    Mismo esquema que el de 2024. La tabla REPRODUCCIONES se creara en
--    MOD-3 como tabla particionada por rango (PARTITION BY RANGE sobre
--    fecha_hora_inicio) apuntando cada particion a su tablespace.
-- -----------------------------------------------------------------------------
CREATE TABLESPACE ts_quindioflix_reprod_2025
  DATAFILE '${ruta_base}/ts_quindioflix_reprod_202501.dbf'
    SIZE 200M
    AUTOEXTEND ON NEXT 100M MAXSIZE 2G
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE
  SEGMENT SPACE MANAGEMENT AUTO
  ONLINE;
