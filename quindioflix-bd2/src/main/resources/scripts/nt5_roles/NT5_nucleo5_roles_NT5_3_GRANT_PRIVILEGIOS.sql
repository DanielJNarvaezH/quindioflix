-- =============================================================================
-- NT5-3: GRANT de privilegios detallados por rol — QuindioFlix
-- Archivo : NT5_nucleo5_roles_NT5_3_GRANT_PRIVILEGIOS.sql
-- Autor   : Cristhian Eduardo Osorio Restrepo
-- Sprint  : 5 — S15 (18/05–24/05/2026)
-- Ticket  : SCRUM-62
-- =============================================================================
-- Dependencias:
--   NT5-1 (SCRUM-60): Los roles deben existir antes de ejecutar este script.
--   NT5-2 (SCRUM-61): Los usuarios deben existir para la asignacion final.
--
-- Los scripts NT5-1 y NT5-2 deben ejecutarse ANTES que este script.
-- Si los roles no existen, los GRANT fallaran con "ORA-01919: role does not exist".
--
-- Roles definidos (desde la Seccion 6 del documento de definicion del proyecto):
--   ROL_ADMIN      — Administracion total del esquema QUINDIOFLIX
--   ROL_CONTENIDO  — Gestion del catalogo de contenido
--   ROL_SOPORTE    — Atencion al cliente y moderacion de reportes
--   ROL_ANALISTA   — Reportes y analisis de datos (solo lectura)
--
-- Convencion de usuarios (desde NT5-2):
--   usr_admin     → ROL_ADMIN
--   usr_contenido → ROL_CONTENIDO
--   usr_soporte   → ROL_SOPORTE
--   usr_analista  → ROL_ANALISTA
-- =============================================================================
-- Nota de ejecucion:
--   Ejecutar en SQL Developer con Run as Script (F5) como usuario SYSTEM
--   conectado al PDB XEPDB1. No es necesario SERVEROUTPUT.
--   Los GRANT son acumulativos y seguros de re-ejecutar (Oracle ignora
--   silenciosamente los privilegios ya otorgados).
-- =============================================================================

PROMPT ============================================================
PROMPT NT5-3: GRANT DE PRIVILEGIOS DETALLADOS POR ROL
PROMPT ============================================================
PROMPT

-- =============================================================================
-- SECCION 1: ROL_ADMIN — Privilegios de administracion total
-- =============================================================================
PROMPT >>> Asignando privilegios a ROL_ADMIN...

-- Privilegios de sistema (DDL completo sobre el esquema)
GRANT CREATE SESSION               TO ROL_ADMIN;
GRANT CREATE TABLE                 TO ROL_ADMIN;
GRANT CREATE VIEW                  TO ROL_ADMIN;
GRANT CREATE SEQUENCE              TO ROL_ADMIN;
GRANT CREATE PROCEDURE             TO ROL_ADMIN;
GRANT CREATE TRIGGER               TO ROL_ADMIN;
GRANT CREATE MATERIALIZED VIEW     TO ROL_ADMIN;
GRANT CREATE TABLESPACE            TO ROL_ADMIN;
GRANT CREATE USER                  TO ROL_ADMIN;
GRANT CREATE ROLE                  TO ROL_ADMIN;
GRANT CREATE ANY INDEX             TO ROL_ADMIN;
GRANT CREATE ANY SYNONYM           TO ROL_ADMIN;
GRANT CREATE ANY DIRECTORY         TO ROL_ADMIN;

GRANT ALTER ANY TABLE              TO ROL_ADMIN;
GRANT ALTER ANY INDEX              TO ROL_ADMIN;
GRANT ALTER USER                   TO ROL_ADMIN;
GRANT ALTER TABLESPACE             TO ROL_ADMIN;

GRANT DROP ANY TABLE               TO ROL_ADMIN;
GRANT DROP ANY VIEW                TO ROL_ADMIN;
GRANT DROP ANY SEQUENCE            TO ROL_ADMIN;
GRANT DROP ANY PROCEDURE           TO ROL_ADMIN;
GRANT DROP ANY TRIGGER             TO ROL_ADMIN;
GRANT DROP ANY MATERIALIZED VIEW   TO ROL_ADMIN;
GRANT DROP ANY INDEX               TO ROL_ADMIN;
GRANT DROP USER                    TO ROL_ADMIN;
GRANT DROP TABLESPACE              TO ROL_ADMIN;

-- Privilegios DML sobre cualquier objeto del esquema
GRANT SELECT ANY TABLE             TO ROL_ADMIN;
GRANT INSERT ANY TABLE             TO ROL_ADMIN;
GRANT UPDATE ANY TABLE             TO ROL_ADMIN;
GRANT DELETE ANY TABLE             TO ROL_ADMIN;
GRANT EXECUTE ANY PROCEDURE        TO ROL_ADMIN;
GRANT FLASHBACK ANY TABLE          TO ROL_ADMIN;
GRANT ANALYZE ANY                  TO ROL_ADMIN;
GRANT UNLIMITED TABLESPACE         TO ROL_ADMIN;

-- Privilegios especificos sobre el esquema QUINDIOFLIX (redundante con
-- SELECT ANY TABLE, pero refuerza la intencion de administracion local)
GRANT ALL PRIVILEGES ON PLANES                 TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON DEPARTAMENTOS          TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON EMPLEADOS              TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON CATEGORIAS             TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON GENEROS                TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON CONTENIDO              TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON CONTENIDO_GENEROS      TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON CONTENIDO_RELACIONADO  TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON TEMPORADAS             TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON EPISODIOS              TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON USUARIOS               TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON PERFILES               TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON PAGOS                  TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON REPRODUCCIONES         TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON CALIFICACIONES         TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON FAVORITOS              TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON REPORTES_INAPROPIADO   TO ROL_ADMIN;

-- Vistas materializadas
GRANT ALL PRIVILEGES ON MV_CONTENIDO_POPULAR   TO ROL_ADMIN;
GRANT ALL PRIVILEGES ON MV_INGRESOS_MENSUALES  TO ROL_ADMIN;

-- DBMS_MVIEW (necesario para refrescar vistas materializadas)
GRANT EXECUTE ON DBMS_MVIEW TO ROL_ADMIN;

PROMPT   ROL_ADMIN completado.
PROMPT

-- =============================================================================
-- SECCION 2: ROL_CONTENIDO — Gestion del catalogo
-- =============================================================================
PROMPT >>> Asignando privilegios a ROL_CONTENIDO...

GRANT CREATE SESSION TO ROL_CONTENIDO;

-- CRUD completo sobre tablas del catalogo
GRANT SELECT, INSERT, UPDATE, DELETE ON CONTENIDO              TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON CATEGORIAS             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON GENEROS                TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON CONTENIDO_GENEROS      TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON CONTENIDO_RELACIONADO  TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON TEMPORADAS             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON EPISODIOS              TO ROL_CONTENIDO;

-- Solo lectura en tablas de referencia
GRANT SELECT ON PLANES      TO ROL_CONTENIDO;
GRANT SELECT ON EMPLEADOS   TO ROL_CONTENIDO;
GRANT SELECT ON DEPARTAMENTOS TO ROL_CONTENIDO;
GRANT SELECT ON CATEGORIAS  TO ROL_CONTENIDO;

-- Lectura de metadatos del esquema (para consultar estructura)
GRANT SELECT ON USUARIOS    TO ROL_CONTENIDO;
GRANT SELECT ON PERFILES    TO ROL_CONTENIDO;

PROMPT   ROL_CONTENIDO completado.
PROMPT

-- =============================================================================
-- SECCION 3: ROL_SOPORTE — Atencion al cliente y moderacion
-- =============================================================================
PROMPT >>> Asignando privilegios a ROL_SOPORTE...

GRANT CREATE SESSION TO ROL_SOPORTE;

-- Gestion de usuarios y perfiles (buscar, actualizar estado)
GRANT SELECT, UPDATE ON USUARIOS TO ROL_SOPORTE;
GRANT SELECT       ON PERFILES   TO ROL_SOPORTE;

-- Gestion de reportes de contenido inapropiado (moderacion)
GRANT SELECT, UPDATE ON REPORTES_INAPROPIADO TO ROL_SOPORTE;

-- Consulta de historial del cliente
GRANT SELECT ON PAGOS          TO ROL_SOPORTE;
GRANT SELECT ON REPRODUCCIONES TO ROL_SOPORTE;

-- Contexto del contenido reportado
GRANT SELECT ON CONTENIDO   TO ROL_SOPORTE;
GRANT SELECT ON CATEGORIAS  TO ROL_SOPORTE;
GRANT SELECT ON GENEROS     TO ROL_SOPORTE;

-- Ejecucion de procedimientos operativos
GRANT EXECUTE ON SP_CAMBIAR_PLAN    TO ROL_SOPORTE;
GRANT EXECUTE ON SP_REPORTE_CONSUMO TO ROL_SOPORTE;

PROMPT   ROL_SOPORTE completado.
PROMPT

-- =============================================================================
-- SECCION 4: ROL_ANALISTA — Reportes y analisis (solo lectura)
-- =============================================================================
PROMPT >>> Asignando privilegios a ROL_ANALISTA...

GRANT CREATE SESSION TO ROL_ANALISTA;

-- SELECT sobre todas las tablas del esquema
GRANT SELECT ON PLANES                 TO ROL_ANALISTA;
GRANT SELECT ON DEPARTAMENTOS          TO ROL_ANALISTA;
GRANT SELECT ON EMPLEADOS              TO ROL_ANALISTA;
GRANT SELECT ON CATEGORIAS             TO ROL_ANALISTA;
GRANT SELECT ON GENEROS                TO ROL_ANALISTA;
GRANT SELECT ON CONTENIDO              TO ROL_ANALISTA;
GRANT SELECT ON CONTENIDO_GENEROS      TO ROL_ANALISTA;
GRANT SELECT ON CONTENIDO_RELACIONADO  TO ROL_ANALISTA;
GRANT SELECT ON TEMPORADAS             TO ROL_ANALISTA;
GRANT SELECT ON EPISODIOS              TO ROL_ANALISTA;
GRANT SELECT ON USUARIOS               TO ROL_ANALISTA;
GRANT SELECT ON PERFILES               TO ROL_ANALISTA;
GRANT SELECT ON PAGOS                  TO ROL_ANALISTA;
GRANT SELECT ON REPRODUCCIONES         TO ROL_ANALISTA;
GRANT SELECT ON CALIFICACIONES         TO ROL_ANALISTA;
GRANT SELECT ON FAVORITOS              TO ROL_ANALISTA;
GRANT SELECT ON REPORTES_INAPROPIADO   TO ROL_ANALISTA;

-- Vistas materializadas (reportes precalculados del NT1)
GRANT SELECT ON MV_CONTENIDO_POPULAR   TO ROL_ANALISTA;
GRANT SELECT ON MV_INGRESOS_MENSUALES  TO ROL_ANALISTA;

-- Ejecucion de funciones y procedimientos de reporte
GRANT EXECUTE ON SP_REPORTE_CONSUMO      TO ROL_ANALISTA;
GRANT EXECUTE ON FN_CONTENIDO_RECOMENDADO TO ROL_ANALISTA;

PROMPT   ROL_ANALISTA completado.
PROMPT

-- =============================================================================
-- SECCION 5: Asignacion de roles a usuarios (NT5-2 complemento)
-- =============================================================================
-- NOTA: Esta seccion asigna cada rol al usuario correspondiente creado en
-- NT5-2 (SCRUM-61). Si los nombres de usuario difieren, ajustar antes de
-- ejecutar.
-- =============================================================================
PROMPT >>> Asignando roles a usuarios...

GRANT ROL_ADMIN      TO usr_admin;
GRANT ROL_CONTENIDO  TO usr_contenido;
GRANT ROL_SOPORTE    TO usr_soporte;
GRANT ROL_ANALISTA   TO usr_analista;

PROMPT   Roles asignados a usuarios.
PROMPT

-- =============================================================================
-- VERIFICACION
-- =============================================================================
PROMPT ============================================================
PROMPT VERIFICACION: Privilegios por rol
PROMPT ============================================================

-- 1. Privilegios de sistema por rol
PROMPT --- Privilegios de sistema ---
SELECT role, privilege, admin_option
FROM   role_sys_privs
WHERE  role IN ('ROL_ADMIN','ROL_CONTENIDO','ROL_SOPORTE','ROL_ANALISTA')
ORDER  BY role, privilege;

-- 2. Privilegios de objeto (tablas) por rol
PROMPT --- Privilegios de objeto ---
SELECT role, table_name, privilege
FROM   role_tab_privs
WHERE  role IN ('ROL_ADMIN','ROL_CONTENIDO','ROL_SOPORTE','ROL_ANALISTA')
ORDER  BY role, table_name, privilege;

-- 3. Roles asignados a usuarios
PROMPT --- Roles por usuario ---
SELECT grantee, granted_role, admin_option
FROM   dba_role_privs
WHERE  grantee IN ('USR_ADMIN','USR_CONTENIDO','USR_SOPORTE','USR_ANALISTA')
ORDER  BY grantee;

PROMPT
PROMPT ============================================================
PROMPT FIN DEL SCRIPT NT5_nucleo5_roles_NT5_3_GRANT_PRIVILEGIOS.sql
PROMPT
PROMPT RESULTADO ESPERADO:
PROMPT   1. ROL_ADMIN      — 30+ privilegios de sistema + ALL sobre 19 objetos
PROMPT   2. ROL_CONTENIDO  — CRUD sobre 7 tablas de catalogo + SELECT en 7 de referencia
PROMPT   3. ROL_SOPORTE    — SELECT/UPDATE en USUARIOS/REPORTES + SPs operativos
PROMPT   4. ROL_ANALISTA   — SELECT sobre 17 tablas + 2 MV + 2 SPs/FNs de reporte
PROMPT   5. 4 usuarios con su rol asignado
PROMPT
PROMPT Si las consultas SELECT devuelven 0 filas, verificar que NT5-1 (roles)
PROMPT y NT5-2 (usuarios) se hayan ejecutado antes que este script.
PROMPT ============================================================

PROMPT
PROMPT Listo. Todos los privilegios han sido otorgados.
