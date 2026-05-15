-- =============================================================================
-- NT5-2: Crear usuarios Oracle — uno por rol
-- Archivo : NT5_nucleo5_acceso_NT5_2_CREAR_USUARIOS.sql
-- Autor   : Diego Garcia
-- Sprint  : 5
-- =============================================================================
-- Crea 4 usuarios Oracle en XEPDB1, uno por cada rol de QuindioFlix.
-- Cada usuario recibe CREATE SESSION (via su rol) y el rol correspondiente.
--
-- PREREQUISITO: NT5-1 ejecutado (roles ya existentes).
-- EJECUCION   : Run as Script (F5) como SYS o SYSTEM en XEPDB1.
--
-- Usuarios creados:
--   admin_qflix    -> ROL_ADMIN     (administrador de la plataforma)
--   analista_qflix -> ROL_ANALISTA  (analista de datos / gerencia)
--   soporte_qflix  -> ROL_SOPORTE   (soporte al cliente)
--   contenido_qflix-> ROL_CONTENIDO (gestor del catalogo)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Cambiar al PDB correcto
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT
PROMPT ============================================================
PROMPT  NT5-2: Creacion de usuarios Oracle — QuindioFlix
PROMPT ============================================================
PROMPT

-- =============================================================================
-- LIMPIEZA PREVIA — eliminar usuarios si existen de ejecuciones anteriores
-- CASCADE elimina todos sus objetos y sesiones activas
-- =============================================================================
BEGIN EXECUTE IMMEDIATE 'DROP USER admin_qflix     CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER analista_qflix  CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER soporte_qflix   CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER contenido_qflix CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Limpieza de usuarios anterior completada.
PROMPT

-- =============================================================================
-- USUARIO 1: admin_qflix — Administrador de la plataforma
-- ROL_ADMIN: CRUD en las 17 tablas + EXECUTE en todos los SPs y funciones
-- =============================================================================
PROMPT --- Creando admin_qflix ---

CREATE USER admin_qflix
    IDENTIFIED BY Admin_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 10M ON USERS;

GRANT ROL_ADMIN TO admin_qflix;

PROMPT admin_qflix creado y asignado a ROL_ADMIN.

-- =============================================================================
-- USUARIO 2: analista_qflix — Analista de datos / Gerencia
-- ROL_ANALISTA: SELECT en todas las tablas + vistas mat. + SPs de reporte
-- =============================================================================
PROMPT
PROMPT --- Creando analista_qflix ---

CREATE USER analista_qflix
    IDENTIFIED BY Analista_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;

GRANT ROL_ANALISTA TO analista_qflix;

PROMPT analista_qflix creado y asignado a ROL_ANALISTA.

-- =============================================================================
-- USUARIO 3: soporte_qflix — Soporte al cliente
-- ROL_SOPORTE: SELECT USUARIOS/PERFILES/PLANES + INSERT/UPDATE PAGOS
--              + SP_CAMBIAR_PLAN + FN_CALCULAR_MONTO
-- =============================================================================
PROMPT
PROMPT --- Creando soporte_qflix ---

CREATE USER soporte_qflix
    IDENTIFIED BY Soporte_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;

GRANT ROL_SOPORTE TO soporte_qflix;

PROMPT soporte_qflix creado y asignado a ROL_SOPORTE.

-- =============================================================================
-- USUARIO 4: contenido_qflix — Gestor del catalogo
-- ROL_CONTENIDO: CRUD CONTENIDO/TEMPORADAS/EPISODIOS/GENEROS/CATEGORIAS
--                + SELECT REPRODUCCIONES/CALIFICACIONES/FAVORITOS
-- =============================================================================
PROMPT
PROMPT --- Creando contenido_qflix ---

CREATE USER contenido_qflix
    IDENTIFIED BY Contenido_Qflix2026#
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;

GRANT ROL_CONTENIDO TO contenido_qflix;

PROMPT contenido_qflix creado y asignado a ROL_CONTENIDO.


-- =============================================================================
-- VERIFICACION — usuarios y roles asignados
-- =============================================================================
PROMPT
PROMPT ============================================================
PROMPT  VERIFICACION — Usuarios creados
PROMPT ============================================================

SELECT
    u.username,
    u.account_status,
    u.default_tablespace,
    u.created
FROM dba_users u
WHERE u.username IN (
                     'ADMIN_QFLIX', 'ANALISTA_QFLIX',
                     'SOPORTE_QFLIX', 'CONTENIDO_QFLIX'
    )
ORDER BY u.username;

PROMPT
PROMPT --- Roles asignados a cada usuario ---
SELECT
    grantee     AS usuario,
    granted_role AS rol,
    default_role,
    admin_option
FROM dba_role_privs
WHERE grantee IN (
                  'ADMIN_QFLIX', 'ANALISTA_QFLIX',
                  'SOPORTE_QFLIX', 'CONTENIDO_QFLIX'
    )
ORDER BY grantee;

PROMPT
PROMPT --- Privilegios de sistema efectivos (via rol) ---
SELECT
    rp.grantee      AS usuario,
    rp.granted_role AS rol,
    sp.privilege
FROM dba_role_privs rp
         JOIN dba_sys_privs sp ON sp.grantee = rp.granted_role
WHERE rp.grantee IN (
                     'ADMIN_QFLIX', 'ANALISTA_QFLIX',
                     'SOPORTE_QFLIX', 'CONTENIDO_QFLIX'
    )
ORDER BY rp.grantee, sp.privilege;

PROMPT
PROMPT ============================================================
PROMPT  NT5-2 completado. Usuarios listos para prueba de acceso.
PROMPT  Siguiente paso NT5-4: demostrar restriccion de acceso.
PROMPT ============================================================