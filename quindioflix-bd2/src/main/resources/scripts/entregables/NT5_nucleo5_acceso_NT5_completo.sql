-- =============================================================================
-- ENTREGABLE: Nucleo 5 — Administracion de Acceso | QuindioFlix
-- Archivo  : NT5_nucleo5_acceso_NT5_COMPLETO.sql
-- Carpeta  : scripts/entregables/
-- Autores  : Daniel Narvaez, Diego Garcia, Cristhian Osorio
-- Curso    : Bases de Datos II — Universidad del Quindio 2026-1
-- =============================================================================
-- Contiene los 4 scripts del Nucleo 5 (Administracion de Acceso):
--
--   NT5-1  Roles y privilegios            — Equipo QuindioFlix
--          Crea los 4 roles con el principio de minimo privilegio:
--          ROL_ADMIN, ROL_ANALISTA, ROL_SOPORTE, ROL_CONTENIDO.
--          GRANT especifico por tabla, SP, funcion y vista materializada.
--
--   NT5-2  Crear usuarios Oracle          — Diego Garcia
--          Crea 4 usuarios en XEPDB1 y asigna el rol correspondiente:
--          admin_qflix, analista_qflix, soporte_qflix, contenido_qflix.
--
--   NT5-4  Demostracion de restriccion    — Daniel Narvaez
--          Instrucciones para demostrar ORA-01031/ORA-00942 al intentar
--          operaciones no permitidas por el rol asignado. Ejecutar en
--          4 ventanas SQL Developer, una por usuario.
--
--   NT5-5  Profile de recursos            — Diego Garcia
--          Crea PERFIL_QUINDIOFLIX con limites de sesion y contrasena
--          justificados y lo asigna a los 4 usuarios.
--
-- ORDEN DE EJECUCION:
--   1. NT5-1 como SYSTEM — crea los roles
--   2. NT5-2 como SYSTEM en XEPDB1 — crea los usuarios
--   3. NT5-4 — ejecutar manualmente en 4 ventanas (una por usuario)
--   4. NT5-5 como SYS en XEPDB1 — crea y asigna el profile
--
-- PREREQUISITO: Esquema QUINDIOFLIX con todos los objetos NT1-NT4 creados.
-- =============================================================================


-- =============================================================================
-- NT5-1: Roles y privilegios
-- Autor: Equipo QuindioFlix
-- Ejecutar como SYSTEM
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT  NT5-1: Creacion de Roles y Privilegios
PROMPT ============================================================
PROMPT

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Limpieza previa
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ADMIN';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ANALISTA';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_SOPORTE';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_CONTENIDO'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- -------------------------------------------------------------------------
-- ROL_ADMIN — Administrador de la plataforma
-- Perfil: DBA funcional. Gestiona usuarios, planes, pagos, contenido.
-- Acceso: CRUD en las 17 tablas + EXECUTE en todos los SPs y funciones.
-- -------------------------------------------------------------------------
CREATE ROLE ROL_ADMIN;
GRANT CREATE SESSION TO ROL_ADMIN;

-- Tablas de configuracion y negocio
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.PLANES                TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CATEGORIAS            TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.GENEROS               TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.DEPARTAMENTOS         TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.EMPLEADOS             TO ROL_ADMIN;
-- Tablas de usuarios y suscripciones
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.USUARIOS              TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.PERFILES              TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.PAGOS                 TO ROL_ADMIN;
-- Tablas de catalogo
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO             TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.TEMPORADAS            TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.EPISODIOS             TO ROL_ADMIN;
-- Tablas de actividad
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.REPRODUCCIONES        TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CALIFICACIONES        TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.FAVORITOS             TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.REPORTES_INAPROPIADO  TO ROL_ADMIN;
-- SPs (NT2 + NT3)
GRANT EXECUTE ON QUINDIOFLIX.SP_REGISTRAR_USUARIO  TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_CAMBIAR_PLAN       TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_REPORTE_CONSUMO    TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_REGISTRO_COMPLETO  TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_RENOVACION_MENSUAL TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_ELIMINAR_CUENTA    TO ROL_ADMIN;
-- Funciones
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO        TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO TO ROL_ADMIN;
-- Vistas materializadas (NT1)
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR  TO ROL_ADMIN;
GRANT SELECT ON QUINDIOFLIX.MV_INGRESOS_MENSUALES TO ROL_ADMIN;

PROMPT ROL_ADMIN: CRUD 17 tablas + EXECUTE 6 SPs + 2 funciones + 2 MVs.

-- -------------------------------------------------------------------------
-- ROL_ANALISTA — Analista de datos / Gerencia
-- Perfil: Solo lectura. Genera reportes y analiza el negocio.
-- Acceso: SELECT en todas las tablas + vistas mat. + SPs de reporte.
-- -------------------------------------------------------------------------
CREATE ROLE ROL_ANALISTA;
GRANT CREATE SESSION TO ROL_ANALISTA;

GRANT SELECT ON QUINDIOFLIX.PLANES                TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CATEGORIAS            TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.GENEROS               TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.DEPARTAMENTOS         TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.EMPLEADOS             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.USUARIOS              TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.PERFILES              TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.PAGOS                 TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CONTENIDO             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.TEMPORADAS            TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.EPISODIOS             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.REPRODUCCIONES        TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CALIFICACIONES        TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.FAVORITOS             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.REPORTES_INAPROPIADO  TO ROL_ANALISTA;
GRANT EXECUTE ON QUINDIOFLIX.SP_REPORTE_CONSUMO       TO ROL_ANALISTA;
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO        TO ROL_ANALISTA;
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR  TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.MV_INGRESOS_MENSUALES TO ROL_ANALISTA;

PROMPT ROL_ANALISTA: SELECT 17 tablas + 2 MVs + SPs de reporte.

-- -------------------------------------------------------------------------
-- ROL_SOPORTE — Soporte al cliente
-- Perfil: Atiende problemas de pago y cambios de plan. No ve catalogo.
-- Acceso: SELECT USUARIOS/PERFILES/PLANES + INSERT/UPDATE PAGOS + SPs.
-- -------------------------------------------------------------------------
CREATE ROLE ROL_SOPORTE;
GRANT CREATE SESSION TO ROL_SOPORTE;

GRANT SELECT ON QUINDIOFLIX.USUARIOS              TO ROL_SOPORTE;
GRANT SELECT ON QUINDIOFLIX.PERFILES              TO ROL_SOPORTE;
GRANT SELECT ON QUINDIOFLIX.PLANES                TO ROL_SOPORTE;
-- INSERT/UPDATE en PAGOS — NO DELETE (un pago solo cambia de estado)
GRANT SELECT, INSERT, UPDATE ON QUINDIOFLIX.PAGOS TO ROL_SOPORTE;
GRANT EXECUTE ON QUINDIOFLIX.SP_CAMBIAR_PLAN   TO ROL_SOPORTE;
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO TO ROL_SOPORTE;

PROMPT ROL_SOPORTE: SELECT USUARIOS/PERFILES/PLANES + INSERT/UPDATE PAGOS + SP_CAMBIAR_PLAN.

-- -------------------------------------------------------------------------
-- ROL_CONTENIDO — Gestor del catalogo
-- Perfil: Equipo editorial. CRUD en catalogo, lectura de consumo.
-- NO puede ver datos de usuarios ni pagos.
-- -------------------------------------------------------------------------
    CREATE ROLE ROL_CONTENIDO;
GRANT CREATE SESSION TO ROL_CONTENIDO;

GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.TEMPORADAS            TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.EPISODIOS             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.GENEROS               TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CATEGORIAS            TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_CONTENIDO;
-- Solo lectura: medir rendimiento del contenido publicado
GRANT SELECT ON QUINDIOFLIX.REPRODUCCIONES TO ROL_CONTENIDO;
GRANT SELECT ON QUINDIOFLIX.CALIFICACIONES TO ROL_CONTENIDO;
GRANT SELECT ON QUINDIOFLIX.FAVORITOS      TO ROL_CONTENIDO;
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR      TO ROL_CONTENIDO;
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO TO ROL_CONTENIDO;

PROMPT ROL_CONTENIDO: CRUD catalogo + SELECT actividad + MV popularidad.

-- Verificacion
SELECT role, password_required
                                      FROM   dba_roles
                                      WHERE  role IN ('ROL_ADMIN','ROL_ANALISTA','ROL_SOPORTE','ROL_CONTENIDO')
                                      ORDER  BY role;

PROMPT
PROMPT NT5-1 completado.


-- =============================================================================
-- NT5-2: Crear usuarios Oracle
-- Autor: Diego Garcia
-- Ejecutar como SYSTEM en XEPDB1
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT  NT5-2: Creacion de usuarios Oracle
PROMPT ============================================================
PROMPT

ALTER SESSION SET CONTAINER = XEPDB1;

-- Limpieza previa
BEGIN EXECUTE IMMEDIATE 'DROP USER admin_qflix     CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER analista_qflix  CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER soporte_qflix   CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER contenido_qflix CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- admin_qflix — ROL_ADMIN
CREATE USER admin_qflix
    IDENTIFIED BY Admin_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 10M ON USERS;
GRANT ROL_ADMIN TO admin_qflix;
PROMPT admin_qflix creado con ROL_ADMIN.

-- analista_qflix — ROL_ANALISTA
CREATE USER analista_qflix
    IDENTIFIED BY Analista_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;
GRANT ROL_ANALISTA TO analista_qflix;
PROMPT analista_qflix creado con ROL_ANALISTA.

-- soporte_qflix — ROL_SOPORTE
CREATE USER soporte_qflix
    IDENTIFIED BY Soporte_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;
GRANT ROL_SOPORTE TO soporte_qflix;
PROMPT soporte_qflix creado con ROL_SOPORTE.

-- contenido_qflix — ROL_CONTENIDO
CREATE USER contenido_qflix
    IDENTIFIED BY Contenido_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;
GRANT ROL_CONTENIDO TO contenido_qflix;
PROMPT contenido_qflix creado con ROL_CONTENIDO.

-- Verificacion
SELECT username, account_status, default_tablespace, created
FROM   dba_users
WHERE  username IN ('ADMIN_QFLIX','ANALISTA_QFLIX','SOPORTE_QFLIX','CONTENIDO_QFLIX')
ORDER  BY username;

SELECT grantee AS usuario, granted_role AS rol
FROM   dba_role_privs
WHERE  grantee IN ('ADMIN_QFLIX','ANALISTA_QFLIX','SOPORTE_QFLIX','CONTENIDO_QFLIX')
ORDER  BY grantee;

PROMPT
PROMPT NT5-2 completado.


-- =============================================================================
-- NT5-4: Demostracion de restriccion de acceso
-- Autor: Daniel Narvaez
-- Ejecutar manualmente en 4 ventanas SQL Developer (una por usuario)
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT  NT5-4: Demostracion de restriccion de acceso
PROMPT  Ejecutar cada bloque en la ventana del usuario indicado
PROMPT ============================================================
PROMPT

-- -------------------------------------------------------------------------
-- VENTANA 1: admin_qflix / Admin_Qflix2026#
-- -------------------------------------------------------------------------
-- PERMITIDA: DELETE (con ROLLBACK para no afectar datos reales)
/*
DELETE FROM QUINDIOFLIX.USUARIOS WHERE id_usuario = 999999;
COMMIT;
-- Resultado esperado: 0 rows deleted (id no existe, pero DELETE PERMITIDO)
*/

-- PROHIBIDA: DROP TABLE (ROL_ADMIN tiene DML, no DDL destructivo)
/*
DROP TABLE QUINDIOFLIX.USUARIOS;
-- Resultado esperado: ORA-01031: insufficient privileges
*/

-- -------------------------------------------------------------------------
-- VENTANA 2: analista_qflix / Analista_Qflix2026#
-- -------------------------------------------------------------------------
-- PERMITIDA: SELECT con agrupacion
/*
SELECT EXTRACT(YEAR FROM fecha_hora_inicio) AS anio,
       COUNT(*) AS reproducciones
FROM   QUINDIOFLIX.REPRODUCCIONES
GROUP  BY EXTRACT(YEAR FROM fecha_hora_inicio)
ORDER  BY anio;
-- Resultado esperado: filas 2024/2025/2026
*/

-- PROHIBIDA: INSERT en PAGOS (ROL_ANALISTA es solo lectura)
/*
INSERT INTO QUINDIOFLIX.PAGOS
    (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES (SYSDATE, 14900, 'PSE', 'EXITOSO', 0, 1);
-- Resultado esperado: ORA-01031: insufficient privileges
*/

-- -------------------------------------------------------------------------
-- VENTANA 3: soporte_qflix / Soporte_Qflix2026#
-- -------------------------------------------------------------------------
-- PERMITIDA: SELECT en USUARIOS
/*
SELECT id_usuario, nombre, apellido, estado_cuenta
FROM   QUINDIOFLIX.USUARIOS
WHERE  estado_cuenta = 'INACTIVO' AND ROWNUM <= 3;
-- Resultado esperado: hasta 3 filas (SELECT PERMITIDO)
*/

-- PROHIBIDA: DELETE en CONTENIDO (ROL_SOPORTE no tiene ningun privilegio en CONTENIDO)
/*
DELETE FROM QUINDIOFLIX.CONTENIDO WHERE id_contenido = 1;
-- Resultado esperado: ORA-00942: table or view does not exist
-- (Oracle oculta la existencia del objeto cuando no hay ningun privilegio)
*/

-- -------------------------------------------------------------------------
-- VENTANA 4: contenido_qflix / Contenido_Qflix2026#
-- -------------------------------------------------------------------------
-- PERMITIDA: INSERT en CONTENIDO (con ROLLBACK para no dejar datos de prueba)
/*
INSERT INTO QUINDIOFLIX.CONTENIDO (
    titulo, anio_lanzamiento, clasificacion_edad,
    es_original_quindioflix, estado, id_categoria, id_empleado_publicacion
) VALUES ('Titulo Prueba NT5-4', 2026, 'TP', 'S', 'ACTIVO', 1, 1);
ROLLBACK;
-- Resultado esperado: 1 row inserted + Rollback complete
*/

-- PROHIBIDA: SELECT en PAGOS (ROL_CONTENIDO no tiene ningun privilegio en PAGOS)
/*
SELECT id_pago, id_usuario, monto, estado_pago
FROM   QUINDIOFLIX.PAGOS WHERE ROWNUM <= 5;
-- Resultado esperado: ORA-00942: table or view does not exist
*/

-- -------------------------------------------------------------------------
-- Resumen de restricciones demostradas
-- -------------------------------------------------------------------------
-- Usuario          Rol             Permitida            Prohibida / Error
-- admin_qflix      ROL_ADMIN       DELETE (ROLLBACK)    DROP TABLE   ORA-01031
-- analista_qflix   ROL_ANALISTA    SELECT agrupado      INSERT PAGOS ORA-01031
-- soporte_qflix    ROL_SOPORTE     SELECT USUARIOS      DELETE CONT  ORA-00942
-- contenido_qflix  ROL_CONTENIDO   INSERT (ROLLBACK)    SELECT PAGOS ORA-00942
--
-- ORA-00942 equivale a ORA-01031 cuando el usuario no tiene NINGUN
-- privilegio sobre el objeto — Oracle oculta la existencia de la tabla
-- por seguridad para no revelar la estructura del esquema.


-- =============================================================================
-- NT5-5: Profile de recursos
-- Autor: Diego Garcia
-- Ejecutar como SYS en XEPDB1
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT  NT5-5: Creacion de PERFIL_QUINDIOFLIX
PROMPT ============================================================
PROMPT

ALTER SESSION SET CONTAINER = XEPDB1;

-- DROP defensivo
BEGIN
EXECUTE IMMEDIATE 'DROP PROFILE PERFIL_QUINDIOFLIX CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2380 THEN RAISE; END IF;
END;
/

-- Crear perfil con limites justificados
CREATE PROFILE PERFIL_QUINDIOFLIX LIMIT
    -- Limites de sesion
    SESSIONS_PER_USER   3       -- max 3 sesiones simultaneas (SQL Dev + reporte + emergencia)
    IDLE_TIME           30      -- cierra sesion inactiva tras 30 min (seguridad operativa)
    CONNECT_TIME        480     -- max 8 horas continuas (jornada laboral)
    -- Seguridad de contrasena
    FAILED_LOGIN_ATTEMPTS   5       -- bloquea tras 5 intentos fallidos (anti fuerza bruta)
    PASSWORD_LOCK_TIME      1/24    -- desbloqueo automatico en 1 hora
    PASSWORD_LIFE_TIME      180     -- expira cada 180 dias (6 meses)
    PASSWORD_REUSE_TIME     365     -- no reusar contrasena por 1 anno
    PASSWORD_REUSE_MAX      5;      -- no reusar ninguna de las ultimas 5

-- Asignar a los 4 usuarios
ALTER USER admin_qflix     PROFILE PERFIL_QUINDIOFLIX;
ALTER USER analista_qflix  PROFILE PERFIL_QUINDIOFLIX;
ALTER USER soporte_qflix   PROFILE PERFIL_QUINDIOFLIX;
ALTER USER contenido_qflix PROFILE PERFIL_QUINDIOFLIX;

PROMPT PERFIL_QUINDIOFLIX asignado a los 4 usuarios.

-- Verificacion del perfil
SELECT resource_name, limit
FROM   dba_profiles
WHERE  profile = 'PERFIL_QUINDIOFLIX'
ORDER  BY resource_name;

-- Verificacion de usuarios con perfil asignado
SELECT username, profile, account_status
FROM   dba_users
WHERE  username IN ('ADMIN_QFLIX','ANALISTA_QFLIX','SOPORTE_QFLIX','CONTENIDO_QFLIX')
ORDER  BY username;

PROMPT
PROMPT ============================================================
PROMPT  NT5 completado — 4 roles, 4 usuarios, 1 perfil de recursos
PROMPT  ROL_ADMIN      -> admin_qflix     (CRUD total + todos los SPs)
PROMPT  ROL_ANALISTA   -> analista_qflix  (solo lectura + reportes)
PROMPT  ROL_SOPORTE    -> soporte_qflix   (suscripciones y pagos)
PROMPT  ROL_CONTENIDO  -> contenido_qflix (gestion del catalogo)
PROMPT  PERFIL_QUINDIOFLIX asignado a los 4 usuarios
PROMPT ============================================================