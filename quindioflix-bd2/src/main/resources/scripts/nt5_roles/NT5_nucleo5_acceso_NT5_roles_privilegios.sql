-- =============================================================================
-- NT5-1: Roles y Privilegios — QuindioFlix
-- Script  : NT5_nucleo5_acceso_NT5_1_ROLES_PRIVILEGIOS.sql
-- Autor   : Equipo QuindioFlix (Daniel Narvaez, Diego Garcia, Cristhian Osorio)
-- Sprint  : 5
-- =============================================================================
-- Crea los 4 roles de acceso de la plataforma QuindioFlix siguiendo el
-- principio de minimo privilegio: cada rol accede solo a lo que su
-- funcion de negocio requiere.
--
-- ROLES:
--   ROL_ADMIN     — Administrador: CRUD en todas las tablas + todos los SPs
--   ROL_ANALISTA  — Analista de datos: SELECT todas las tablas + vistas mat.
--   ROL_SOPORTE   — Soporte al cliente: gestion de suscripciones y pagos
--   ROL_CONTENIDO — Gestor de catalogo: CRUD de contenido y metadatos
--
-- PREREQUISITO: Ejecutar como SYSTEM o usuario con privilegio DBA.
--   El esquema QUINDIOFLIX debe existir y tener todos los objetos creados
--   (ENT_01_creacion_esquema.sql + NT2 + NT3 ya ejecutados).
--
-- EJECUCION: Run as Script (F5) en SQL Developer como SYSTEM.
--
-- OBJETOS EN LA BD:
--   Tablas (17): PLANES, USUARIOS, PERFILES, PAGOS, CONTENIDO, TEMPORADAS,
--     EPISODIOS, REPRODUCCIONES, CALIFICACIONES, FAVORITOS,
--     REPORTES_INAPROPIADO, CATEGORIAS, GENEROS, CONTENIDO_GENEROS,
--     CONTENIDO_RELACIONADO, DEPARTAMENTOS, EMPLEADOS
--   Procedimientos (6): SP_REGISTRAR_USUARIO, SP_CAMBIAR_PLAN,
--     SP_REPORTE_CONSUMO, SP_REGISTRO_COMPLETO, SP_RENOVACION_MENSUAL,
--     SP_ELIMINAR_CUENTA
--   Funciones (2): FN_CALCULAR_MONTO, FN_CONTENIDO_RECOMENDADO
--   Vistas mat. (2): MV_CONTENIDO_POPULAR, MV_INGRESOS_MENSUALES
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ============================================================
PROMPT  NT5-1: Creacion de Roles y Privilegios — QuindioFlix
PROMPT ============================================================
PROMPT


-- =============================================================================
-- LIMPIEZA PREVIA — Eliminar roles si existen de ejecuciones anteriores
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ADMIN';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ANALISTA';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_SOPORTE';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_CONTENIDO'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Limpieza de roles anterior completada.
PROMPT


-- =============================================================================
-- ROL_ADMIN — Administrador de la plataforma
-- =============================================================================
-- Perfil: DBA funcional de QuindioFlix. Gestiona usuarios, planes, pagos,
-- contenido y supervisa toda la operacion. Puede ejecutar cualquier SP.
-- Acceso: CRUD en las 17 tablas + EXECUTE en todos los SPs y funciones.
-- No tiene CREATE SESSION propio — se asigna a un usuario Oracle que
-- ya puede conectarse, o se le agrega GRANT CREATE SESSION al ROL_ADMIN.
-- =============================================================================

PROMPT --- Creando ROL_ADMIN ---

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

-- Tablas de catalogo de contenido
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO             TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.TEMPORADAS            TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.EPISODIOS             TO ROL_ADMIN;

-- Tablas de actividad de usuarios
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.REPRODUCCIONES        TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CALIFICACIONES        TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.FAVORITOS             TO ROL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.REPORTES_INAPROPIADO  TO ROL_ADMIN;

-- Todos los procedimientos almacenados (NT2 + NT3)
GRANT EXECUTE ON QUINDIOFLIX.SP_REGISTRAR_USUARIO  TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_CAMBIAR_PLAN       TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_REPORTE_CONSUMO    TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_REGISTRO_COMPLETO  TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_RENOVACION_MENSUAL TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.SP_ELIMINAR_CUENTA    TO ROL_ADMIN;

-- Todas las funciones
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO         TO ROL_ADMIN;
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO  TO ROL_ADMIN;

-- Vistas materializadas (NT1)
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR   TO ROL_ADMIN;
GRANT SELECT ON QUINDIOFLIX.MV_INGRESOS_MENSUALES  TO ROL_ADMIN;

PROMPT ROL_ADMIN creado: CRUD en 17 tablas + EXECUTE en 6 SPs y 2 funciones.


-- =============================================================================
-- ROL_ANALISTA — Analista de datos / Gerencia
-- =============================================================================
-- Perfil: Genera reportes de negocio, analiza consumo, ingresos y popularidad.
-- Solo necesita leer datos — nunca modifica ni elimina.
-- Acceso: SELECT en todas las tablas + vistas materializadas + SPs de reporte.
-- =============================================================================

PROMPT
PROMPT --- Creando ROL_ANALISTA ---

CREATE ROLE ROL_ANALISTA;
GRANT CREATE SESSION TO ROL_ANALISTA;

-- Tablas de configuracion (necesita ver planes, categorias para cruzar reportes)
GRANT SELECT ON QUINDIOFLIX.PLANES                TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CATEGORIAS            TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.GENEROS               TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.DEPARTAMENTOS         TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.EMPLEADOS             TO ROL_ANALISTA;

-- Tablas de usuarios y suscripciones (para reportes de ingresos y mora)
GRANT SELECT ON QUINDIOFLIX.USUARIOS              TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.PERFILES              TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.PAGOS                 TO ROL_ANALISTA;

-- Tablas de catalogo (para reportes de popularidad y catalogo)
GRANT SELECT ON QUINDIOFLIX.CONTENIDO             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.TEMPORADAS            TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.EPISODIOS             TO ROL_ANALISTA;

-- Tablas de actividad (consumo, calificaciones, favoritos)
GRANT SELECT ON QUINDIOFLIX.REPRODUCCIONES        TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.CALIFICACIONES        TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.FAVORITOS             TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.REPORTES_INAPROPIADO  TO ROL_ANALISTA;

-- SPs y funciones de reporte (puede llamar reportes pero no modificar datos)
GRANT EXECUTE ON QUINDIOFLIX.SP_REPORTE_CONSUMO       TO ROL_ANALISTA;
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO        TO ROL_ANALISTA;
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO TO ROL_ANALISTA;

-- Vistas materializadas: acceso directo a los resúmenes precalculados de NT1
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR   TO ROL_ANALISTA;
GRANT SELECT ON QUINDIOFLIX.MV_INGRESOS_MENSUALES  TO ROL_ANALISTA;

PROMPT ROL_ANALISTA creado: SELECT en 17 tablas + vistas mat. + SPs de reporte.


-- =============================================================================
-- ROL_SOPORTE — Soporte al cliente
-- =============================================================================
-- Perfil: Atiende solicitudes de usuarios: problemas de pago, cambios de plan,
-- consulta de cuentas. NO puede ver contenido del catalogo ni eliminar nada.
-- Acceso: SELECT en USUARIOS/PERFILES/PLANES/PAGOS + INSERT/UPDATE en PAGOS
--         + EXECUTE SP_CAMBIAR_PLAN + EXECUTE FN_CALCULAR_MONTO.
-- =============================================================================

PROMPT
PROMPT --- Creando ROL_SOPORTE ---

CREATE ROLE ROL_SOPORTE;
GRANT CREATE SESSION TO ROL_SOPORTE;

-- Consulta de cuentas (solo lectura — para identificar al usuario)
GRANT SELECT ON QUINDIOFLIX.USUARIOS  TO ROL_SOPORTE;
GRANT SELECT ON QUINDIOFLIX.PERFILES  TO ROL_SOPORTE;
GRANT SELECT ON QUINDIOFLIX.PLANES    TO ROL_SOPORTE;

-- Gestion de pagos: puede ver, registrar y actualizar pagos (ej: marcar reembolso)
-- NO puede DELETE — un pago nunca se elimina, solo se cambia su estado
GRANT SELECT, INSERT, UPDATE ON QUINDIOFLIX.PAGOS TO ROL_SOPORTE;

-- SP de cambio de plan: unica accion de modificacion permitida sobre usuarios
GRANT EXECUTE ON QUINDIOFLIX.SP_CAMBIAR_PLAN    TO ROL_SOPORTE;
GRANT EXECUTE ON QUINDIOFLIX.FN_CALCULAR_MONTO  TO ROL_SOPORTE;

PROMPT ROL_SOPORTE creado: SELECT USUARIOS/PERFILES/PLANES + INSERT/UPDATE PAGOS + SP_CAMBIAR_PLAN.


-- =============================================================================
-- ROL_CONTENIDO — Gestor del catalogo
-- =============================================================================
-- Perfil: Equipo editorial que gestiona el catalogo de la plataforma.
-- Puede agregar, editar y eliminar contenido, episodios y metadatos.
-- Solo lectura en reproducciones y calificaciones para medir rendimiento.
-- NO puede ver datos de usuarios ni pagos.
-- =============================================================================

    PROMPT
    PROMPT --- Creando ROL_CONTENIDO ---

CREATE ROLE ROL_CONTENIDO;
GRANT CREATE SESSION TO ROL_CONTENIDO;

-- CRUD completo en el catalogo de contenido
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.TEMPORADAS            TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.EPISODIOS             TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.GENEROS               TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CATEGORIAS            TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_GENEROS     TO ROL_CONTENIDO;
GRANT SELECT, INSERT, UPDATE, DELETE ON QUINDIOFLIX.CONTENIDO_RELACIONADO TO ROL_CONTENIDO;

-- Solo lectura: para analizar rendimiento del contenido publicado
GRANT SELECT ON QUINDIOFLIX.REPRODUCCIONES  TO ROL_CONTENIDO;
GRANT SELECT ON QUINDIOFLIX.CALIFICACIONES  TO ROL_CONTENIDO;
GRANT SELECT ON QUINDIOFLIX.FAVORITOS       TO ROL_CONTENIDO;

-- Vista materializada de popularidad: metrica clave para el equipo editorial
GRANT SELECT ON QUINDIOFLIX.MV_CONTENIDO_POPULAR TO ROL_CONTENIDO;

-- Funcion de recomendacion: util para validar la logica del catalogo
GRANT EXECUTE ON QUINDIOFLIX.FN_CONTENIDO_RECOMENDADO TO ROL_CONTENIDO;

PROMPT ROL_CONTENIDO creado: CRUD CONTENIDO/TEMPORADAS/EPISODIOS/GENEROS/CATEGORIAS + SELECT REPRODUCCIONES/CALIFICACIONES/FAVORITOS.


    -- =============================================================================
-- VERIFICACION FINAL
-- =============================================================================

    PROMPT
                                                                                                 PROMPT ============================================================
PROMPT  VERIFICACION — Roles creados
PROMPT ============================================================

SELECT role, password_required
FROM   dba_roles
WHERE  role IN ('ROL_ADMIN', 'ROL_ANALISTA', 'ROL_SOPORTE', 'ROL_CONTENIDO')
ORDER  BY role;

PROMPT
PROMPT --- Privilegios de sistema por rol ---
SELECT grantee, privilege
FROM   dba_sys_privs
WHERE  grantee IN ('ROL_ADMIN', 'ROL_ANALISTA', 'ROL_SOPORTE', 'ROL_CONTENIDO')
ORDER  BY grantee, privilege;

PROMPT
PROMPT --- Privilegios de objeto por rol (resumen) ---
SELECT grantee, privilege, COUNT(*) AS num_objetos
FROM   dba_tab_privs
WHERE  grantee IN ('ROL_ADMIN', 'ROL_ANALISTA', 'ROL_SOPORTE', 'ROL_CONTENIDO')
GROUP  BY grantee, privilege
ORDER  BY grantee, privilege;

PROMPT
PROMPT ============================================================
PROMPT  NT5-1 completado. Roles listos para asignar a usuarios.
PROMPT  Siguiente paso NT5-2: crear usuarios Oracle y asignar roles.
PROMPT ============================================================