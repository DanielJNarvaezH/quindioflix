-- =============================================================================
-- ENTREGABLE: Nucleo 4 — Indices | QuindioFlix
-- Archivo  : NT4_nucleo4_indices_NT4_COMPLETO.sql
-- Carpeta  : scripts/entregables/
-- Autores  : Daniel Narvaez, Diego Garcia, Cristhian Osorio
-- Curso    : Bases de Datos II — Universidad del Quindio 2026-1
-- =============================================================================
-- Contiene los 5 scripts del Nucleo 4 (Indices y EXPLAIN PLAN):
--
--   NT4-1  IDX_REPROD_PERFIL_FECHA    — Diego Garcia
--          Indice compuesto LOCAL en REPRODUCCIONES(id_perfil, fecha_hora_inicio).
--          Optimiza consultas de historial por perfil en tabla particionada.
--
--   NT4-2  IDX_USUARIOS_EMAIL         — Cristhian Osorio
--          Reemplaza el indice implicito UQ_USUARIOS_EMAIL por un indice
--          unico explicito con nombre semantico. Optimiza el login y las
--          validaciones de email duplicado en SP_REGISTRAR_USUARIO.
--
--   NT4-3  IDX_CONTENIDO_CAT_ANIO     — Daniel Narvaez
--          Indice compuesto en CONTENIDO(id_categoria, anio_lanzamiento).
--          Optimiza las consultas parametrizadas NT1 y FN_CONTENIDO_RECOMENDADO.
--
--   NT4-4  IDX_PAGOS_USUARIO_FECHA_ESTADO  — Diego Garcia
--          Indice compuesto en PAGOS(id_usuario, fecha_pago, estado_pago).
--          Optimiza el cursor de mora NT2-1, SP_REPORTE_CONSUMO y
--          SP_RENOVACION_MENSUAL.
--
--   NT4-5  EXPLAIN PLAN               — Cristhian Osorio
--          Analisis comparativo antes/despues usando ALTER INDEX INVISIBLE/VISIBLE
--          sobre IDX_USUARIOS_EMAIL. Demuestra la mejora de TABLE ACCESS FULL
--          a INDEX UNIQUE SCAN en una consulta con JOIN de 4 tablas.
--
-- PREREQUISITO: Esquema QUINDIOFLIX creado y datos cargados.
--   NT4-2 debe ejecutarse antes que NT4-5 (IDX_USUARIOS_EMAIL debe existir).
-- EJECUCION: Run as Script (F5) en SQL Developer como QUINDIOFLIX.
--   Los scripts son idempotentes: cada uno incluye DROP defensivo.
--
-- RESUMEN DE INDICES CREADOS:
--   Tabla            Indice                        Tipo       Columnas
--   REPRODUCCIONES   IDX_REPROD_PERFIL_FECHA       B-tree LOCAL  id_perfil, fecha_hora_inicio
--   USUARIOS         IDX_USUARIOS_EMAIL            B-tree UNIQUE email
--   CONTENIDO        IDX_CONTENIDO_CAT_ANIO        B-tree        id_categoria, anio_lanzamiento
--   PAGOS            IDX_PAGOS_USUARIO_FECHA_ESTADO B-tree        id_usuario, fecha_pago, estado_pago
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ============================================================
PROMPT  NT4 — Indices QuindioFlix
PROMPT  Daniel Narvaez | Diego Garcia | Cristhian Osorio
PROMPT ============================================================
PROMPT


-- =============================================================================
-- NT4-1: IDX_REPROD_PERFIL_FECHA
-- Indice compuesto LOCAL en REPRODUCCIONES(id_perfil, fecha_hora_inicio)
-- Autor: Diego Garcia
-- =============================================================================
-- Justificacion:
--   Las consultas de historial filtran siempre por id_perfil y ordenan
--   por fecha_hora_inicio DESC. Sin indice Oracle hace FULL TABLE SCAN
--   sobre REPRODUCCIONES (tabla particionada de mayor volumen).
--   Con este indice LOCAL: INDEX RANGE SCAN directo al perfil, ya ordenado
--   por fecha — elimina el sort adicional. Cada particion (p_2024, p_2025,
--   p_2026) tiene su propio segmento de indice, por lo que las consultas
--   por rango de fechas tambien activan partition pruning.
--
--   Columna 1 (id_perfil)         : reduce drasticamente los registros
--   Columna 2 (fecha_hora_inicio) : permite ORDER BY sin sort extra
-- =============================================================================

PROMPT --- NT4-1: Creando IDX_REPROD_PERFIL_FECHA ---

BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_REPROD_PERFIL_FECHA';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF;
END;
/

CREATE INDEX IDX_REPROD_PERFIL_FECHA
    ON REPRODUCCIONES (id_perfil, fecha_hora_inicio)
    LOCAL
    TABLESPACE ts_quindioflix_indices;

PROMPT NT4-1: IDX_REPROD_PERFIL_FECHA creado (LOCAL, particionado).

-- EXPLAIN PLAN con el indice creado
EXPLAIN PLAN FOR
SELECT r.id_reproduccion,
       r.fecha_hora_inicio,
       r.fecha_hora_fin,
       r.dispositivo,
       r.porcentaje_avance,
       c.titulo,
       cat.nombre AS categoria
FROM   REPRODUCCIONES r
           JOIN   CONTENIDO  c   ON c.id_contenido  = r.id_contenido
           JOIN   CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE  r.id_perfil = 1
ORDER  BY r.fecha_hora_inicio DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Verificacion en el catalogo
SELECT i.index_name, i.index_type, i.partitioned, i.status, i.tablespace_name,
       ic.column_name, ic.column_position
FROM   user_indexes i
           JOIN   user_ind_columns ic ON ic.index_name = i.index_name
WHERE  i.index_name = 'IDX_REPROD_PERFIL_FECHA'
ORDER  BY ic.column_position;

SELECT ip.index_name, ip.partition_name, ip.tablespace_name, ip.status
FROM   user_ind_partitions ip
WHERE  ip.index_name = 'IDX_REPROD_PERFIL_FECHA'
ORDER  BY ip.partition_name;


-- =============================================================================
-- NT4-2: IDX_USUARIOS_EMAIL
-- Indice unico explicito en USUARIOS(email)
-- Autor: Cristhian Osorio
-- =============================================================================
-- Justificacion:
--   Oracle genera automaticamente el indice implicito UQ_USUARIOS_EMAIL al
--   crear la constraint UNIQUE. Ese indice funciona, pero su nombre no sigue
--   la convencion IDX_* del proyecto, dificultando su identificacion en
--   EXPLAIN PLAN y en el catalogo.
--   Este script reemplaza el indice implicito por IDX_USUARIOS_EMAIL con
--   nombre semantico y lo religar a la constraint UNIQUE existente.
--
--   email es la columna de busqueda mas frecuente:
--     1. SP_REGISTRAR_USUARIO valida duplicados: WHERE email = LOWER(TRIM(?))
--     2. El login busca la cuenta por email en cada autenticacion.
--   Sin indice: TABLE ACCESS FULL sobre USUARIOS en cada login.
--   Con indice: INDEX UNIQUE SCAN — acceso O(log n).
-- =============================================================================

PROMPT
PROMPT --- NT4-2: Creando IDX_USUARIOS_EMAIL ---

DECLARE
v_idx_exists NUMBER := 0;
    v_cst_exists NUMBER := 0;
BEGIN
SELECT COUNT(*) INTO v_idx_exists
FROM   user_indexes
WHERE  index_name = 'IDX_USUARIOS_EMAIL';

IF v_idx_exists = 0 THEN
SELECT COUNT(*) INTO v_cst_exists
FROM   user_constraints
WHERE  constraint_name = 'UQ_USUARIOS_EMAIL'
  AND    table_name      = 'USUARIOS';

IF v_cst_exists > 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE USUARIOS DROP CONSTRAINT UQ_USUARIOS_EMAIL';
END IF;

EXECUTE IMMEDIATE
    'CREATE UNIQUE INDEX IDX_USUARIOS_EMAIL
        ON USUARIOS (email)
        TABLESPACE ts_quindioflix_indices';

EXECUTE IMMEDIATE
    'ALTER TABLE USUARIOS ADD CONSTRAINT UQ_USUARIOS_EMAIL
        UNIQUE (email)
        USING INDEX IDX_USUARIOS_EMAIL';

DBMS_OUTPUT.PUT_LINE('IDX_USUARIOS_EMAIL creado y constraint religada.');
ELSE
        DBMS_OUTPUT.PUT_LINE('IDX_USUARIOS_EMAIL ya existe — sin cambios.');
END IF;
END;
/

-- Verificacion
SELECT index_name, index_type, uniqueness, status, tablespace_name
FROM   user_indexes
WHERE  table_name = 'USUARIOS'
ORDER  BY index_name;

SELECT constraint_name, constraint_type, index_name, status
FROM   user_constraints
WHERE  table_name      = 'USUARIOS'
  AND    constraint_name = 'UQ_USUARIOS_EMAIL';


-- =============================================================================
-- NT4-3: IDX_CONTENIDO_CAT_ANIO
-- Indice compuesto en CONTENIDO(id_categoria, anio_lanzamiento)
-- Autor: Daniel Narvaez
-- =============================================================================
-- Justificacion:
--   Las consultas del catalogo filtran primero por categoria y refinan
--   por rango de anio. Patron presente en NT1-1a (consulta parametrizada
--   con &&categoria_id y &&anio_min) y en FN_CONTENIDO_RECOMENDADO.
--
--   Orden de columnas (criterio de prefijo):
--   Columna 1 (id_categoria)     : filtro principal, alta selectividad
--   Columna 2 (anio_lanzamiento) : refinamiento por rango BETWEEN
--
--   Cardinalidades: id_categoria tiene 8 valores distintos — se usa B-tree
--   (no Bitmap) porque CONTENIDO recibe INSERTs frecuentes y Bitmap degrada
--   con escrituras concurrentes.
-- =============================================================================

PROMPT
PROMPT --- NT4-3: Creando IDX_CONTENIDO_CAT_ANIO ---

BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_CONTENIDO_CAT_ANIO';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF;
END;
/

CREATE INDEX IDX_CONTENIDO_CAT_ANIO
    ON CONTENIDO (id_categoria, anio_lanzamiento)
    TABLESPACE ts_quindioflix_indices;

PROMPT NT4-3: IDX_CONTENIDO_CAT_ANIO creado.

-- EXPLAIN PLAN: consulta del catalogo por categoria y anio
EXPLAIN PLAN FOR
SELECT c.id_contenido, c.titulo, c.anio_lanzamiento, c.popularidad,
       cat.nombre AS categoria
FROM   CONTENIDO c
           JOIN   CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE  c.id_categoria     = 1
  AND    c.anio_lanzamiento BETWEEN 2015 AND 2026;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Verificacion
SELECT table_name, index_name, index_type, uniqueness, status
FROM   user_indexes
WHERE  table_name IN ('REPRODUCCIONES','USUARIOS','CONTENIDO','PAGOS')
ORDER  BY table_name, index_name;


-- =============================================================================
-- NT4-4: IDX_PAGOS_USUARIO_FECHA_ESTADO
-- Indice compuesto en PAGOS(id_usuario, fecha_pago, estado_pago)
-- Autor: Diego Garcia
-- =============================================================================
-- Justificacion:
--   Beneficia las tres consultas mas frecuentes sobre PAGOS:
--
--   1. NT2-1 Cursor mora: WHERE id_usuario = X AND estado_pago = 'EXITOSO'
--      ORDER BY fecha_pago DESC
--      -> Cubre filtro por usuario y estado; fechas ya ordenadas sin sort.
--
--   2. SP_REPORTE_CONSUMO: JOIN PAGOS ON id_usuario + rango de fechas
--      -> INDEX RANGE SCAN sobre id_usuario + fecha_pago.
--
--   3. SP_RENOVACION_MENSUAL: acceso al ultimo pago del usuario
--      -> Directo al rango del usuario sin recorrer toda la tabla.
--
--   Orden de columnas:
--   Columna 1 (id_usuario)  : cardinalidad alta — filtra desde el primer nivel
--   Columna 2 (fecha_pago)  : ORDER BY y filtros por rango sin sort adicional
--   Columna 3 (estado_pago) : cardinalidad baja — al final permite index skip
--                             scan cuando se filtra solo por estado
-- =============================================================================

PROMPT
PROMPT --- NT4-4: Creando IDX_PAGOS_USUARIO_FECHA_ESTADO ---

BEGIN
EXECUTE IMMEDIATE 'DROP INDEX IDX_PAGOS_USUARIO_FECHA_ESTADO';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1418 THEN RAISE; END IF;
END;
/

CREATE INDEX IDX_PAGOS_USUARIO_FECHA_ESTADO
    ON PAGOS (id_usuario, fecha_pago, estado_pago)
    TABLESPACE ts_quindioflix_indices;

PROMPT NT4-4: IDX_PAGOS_USUARIO_FECHA_ESTADO creado.

-- EXPLAIN PLAN: consulta de SP_REPORTE_CONSUMO
EXPLAIN PLAN FOR
SELECT COUNT(p.id_pago)                                          AS total_pagos,
       SUM(CASE WHEN p.estado_pago='EXITOSO' THEN p.monto ELSE 0 END) AS total_pagado,
       MAX(p.fecha_pago)                                         AS ultimo_pago
FROM   PAGOS p
WHERE  p.id_usuario = 1
  AND    p.fecha_pago BETWEEN DATE '2024-01-01' AND DATE '2024-12-31'
ORDER  BY p.fecha_pago DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- EXPLAIN PLAN: cursor mora NT2-1
EXPLAIN PLAN FOR
SELECT p.fecha_pago, p.monto, p.estado_pago
FROM   PAGOS p
WHERE  p.id_usuario  = 1
  AND    p.estado_pago = 'EXITOSO'
ORDER  BY p.fecha_pago DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Verificacion de columnas del indice
SELECT i.index_name, i.index_type, i.status, i.tablespace_name,
       ic.column_name, ic.column_position, ic.descend
FROM   user_indexes i
           JOIN   user_ind_columns ic ON ic.index_name = i.index_name
WHERE  i.index_name = 'IDX_PAGOS_USUARIO_FECHA_ESTADO'
ORDER  BY ic.column_position;


-- =============================================================================
-- NT4-5: EXPLAIN PLAN — Analisis comparativo IDX_USUARIOS_EMAIL
-- Autor: Cristhian Osorio
-- =============================================================================
-- Objetivo:
--   Comparar el plan de ejecucion de una consulta con JOIN de 4 tablas
--   (REPRODUCCIONES, PERFILES, USUARIOS, CONTENIDO) filtrando por email,
--   antes y despues de que IDX_USUARIOS_EMAIL este activo.
--
-- Metodologia:
--   ALTER INDEX IDX_USUARIOS_EMAIL INVISIBLE simula el estado sin indice
--   sin borrar el objeto. Oracle ignora indices INVISIBLE al construir el
--   plan, forzando TABLE ACCESS FULL sobre USUARIOS.
--   ALTER INDEX IDX_USUARIOS_EMAIL VISIBLE restaura el indice y el
--   optimizador usa INDEX UNIQUE SCAN.
--
-- Resultado esperado:
--   SIN indice: TABLE ACCESS FULL sobre USUARIOS (O(n), costo alto)
--   CON indice: INDEX UNIQUE SCAN sobre IDX_USUARIOS_EMAIL (O(log n))
-- =============================================================================

PROMPT
PROMPT --- NT4-5: EXPLAIN PLAN comparativo IDX_USUARIOS_EMAIL ---

-- BLOQUE 1: SIN INDICE (INVISIBLE)
PROMPT
PROMPT ============================================================
PROMPT NT4-5 PASO 1: Plan SIN indice (IDX_USUARIOS_EMAIL INVISIBLE)
PROMPT ============================================================

ALTER INDEX IDX_USUARIOS_EMAIL INVISIBLE;

EXPLAIN PLAN FOR
SELECT u.id_usuario,
       u.nombre || ' ' || u.apellido AS usuario,
       u.email,
       c.titulo                      AS contenido,
       r.porcentaje_avance,
       r.fecha_hora_inicio
FROM   REPRODUCCIONES r
           JOIN   PERFILES  p ON p.id_perfil    = r.id_perfil
           JOIN   USUARIOS  u ON u.id_usuario   = p.id_usuario
           JOIN   CONTENIDO c ON c.id_contenido = r.id_contenido
WHERE  u.email = 'sofia.perea@quindioflix.com'
ORDER  BY r.fecha_hora_inicio DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

-- BLOQUE 2: CON INDICE (VISIBLE)
PROMPT
PROMPT ============================================================
PROMPT NT4-5 PASO 2: Plan CON indice (IDX_USUARIOS_EMAIL VISIBLE)
PROMPT ============================================================

ALTER INDEX IDX_USUARIOS_EMAIL VISIBLE;

EXPLAIN PLAN FOR
SELECT u.id_usuario,
       u.nombre || ' ' || u.apellido AS usuario,
       u.email,
       c.titulo                      AS contenido,
       r.porcentaje_avance,
       r.fecha_hora_inicio
FROM   REPRODUCCIONES r
           JOIN   PERFILES  p ON p.id_perfil    = r.id_perfil
           JOIN   USUARIOS  u ON u.id_usuario   = p.id_usuario
           JOIN   CONTENIDO c ON c.id_contenido = r.id_contenido
WHERE  u.email = 'sofia.perea@quindioflix.com'
ORDER  BY r.fecha_hora_inicio DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

-- Verificar que el indice quedo VISIBLE
SELECT index_name, visibility, status
FROM   user_indexes
WHERE  table_name = 'USUARIOS'
  AND    index_name = 'IDX_USUARIOS_EMAIL';


-- =============================================================================
-- VERIFICACION FINAL — Resumen de todos los indices NT4 del proyecto
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT  VERIFICACION FINAL — Indices NT4 del proyecto QuindioFlix
PROMPT ============================================================

SELECT table_name,
       index_name,
       index_type,
       uniqueness,
       partitioned,
       status,
       tablespace_name
FROM   user_indexes
WHERE  index_name IN (
                      'IDX_REPROD_PERFIL_FECHA',
                      'IDX_USUARIOS_EMAIL',
                      'IDX_CONTENIDO_CAT_ANIO',
                      'IDX_PAGOS_USUARIO_FECHA_ESTADO'
    )
ORDER  BY table_name, index_name;

PROMPT
PROMPT ============================================================
PROMPT  NT4 completado — 4 indices creados exitosamente
PROMPT  IDX_REPROD_PERFIL_FECHA      : REPRODUCCIONES (LOCAL)
PROMPT  IDX_USUARIOS_EMAIL           : USUARIOS (UNIQUE)
PROMPT  IDX_CONTENIDO_CAT_ANIO       : CONTENIDO
PROMPT  IDX_PAGOS_USUARIO_FECHA_ESTADO: PAGOS
PROMPT ============================================================