
-- =============================================
-- PREREQUISITO: Ejecutar como SYSTEM en XEPDB1
-- SQL Developer: conectarse al PDB antes de correr
-- =============================================

SHOW CON_NAME;

-- Ver qué PDBs tienes disponibles
SELECT NAME FROM V$PDBS;


-- Cambiar al PDB si es necesario
ALTER SESSION SET CONTAINER = XEPDB1;


-- Crear el usuario
CREATE USER quindioflix IDENTIFIED BY quindioflix2026;

-- Darle espacio para crear objetos
ALTER USER quindioflix DEFAULT TABLESPACE USERS;
ALTER USER quindioflix QUOTA UNLIMITED ON USERS;

-- Permisos básicos para trabajar
GRANT CREATE SESSION TO quindioflix;
GRANT CREATE TABLE TO quindioflix;
GRANT CREATE VIEW TO quindioflix;
GRANT CREATE SEQUENCE TO quindioflix;
GRANT CREATE PROCEDURE TO quindioflix;
GRANT CREATE TRIGGER TO quindioflix;
GRANT CREATE MATERIALIZED VIEW TO quindioflix;
GRANT CREATE TABLESPACE TO quindioflix;
GRANT CREATE ANY TABLE TO quindioflix;

-- Para los tablespaces del proyecto
GRANT CREATE ANY DIRECTORY TO quindioflix;
GRANT UNLIMITED TABLESPACE TO quindioflix;