-- =============================================================================
-- NT5-4: Demostracion de restriccion de acceso por rol — QuindioFlix
-- Archivo : NT5_nucleo5_acceso_NT5_4_DEMO_RESTRICCION_ACCESO.sql
-- Autor   : Daniel Narvaez
-- Sprint  : 5
-- =============================================================================
-- Objetivo:
--   Demostrar que cada rol de QuindioFlix tiene EXACTAMENTE los privilegios
--   que le corresponden y que las operaciones fuera de su alcance son
--   rechazadas por Oracle con ORA-01031: insufficient privileges.
--
-- Metodologia:
--   Para cada usuario se demuestra:
--     a) Una operacion PERMITIDA  — debe completarse sin error
--     b) Una operacion PROHIBIDA  — debe generar ORA-01031
--
-- INSTRUCCIONES DE EJECUCION:
--   Abrir 4 ventanas SQL Worksheet en SQL Developer.
--   Conectar cada ventana con el usuario correspondiente:
--     Ventana 1: admin_qflix     / Admin_Qflix2026#
--     Ventana 2: analista_qflix  / Analista_Qflix2026#
--     Ventana 3: soporte_qflix   / Soporte_Qflix2026#
--     Ventana 4: contenido_qflix / Contenido_Qflix2026#
--
--   En cada ventana ejecutar los bloques de su seccion.
--   Tomar captura de pantalla de:
--     - El resultado OK de la operacion permitida
--     - El ORA-01031 de la operacion prohibida
--
-- PREREQUISITO: NT5-1 (roles), NT5-2 (usuarios) ejecutados.
-- =============================================================================


-- =============================================================================
-- VENTANA 1: admin_qflix — ROL_ADMIN
-- Copiar y ejecutar en la ventana conectada como admin_qflix
-- =============================================================================

-- -----------------------------------------------------------------------
-- OPERACION PERMITIDA: DELETE en USUARIOS
-- ROL_ADMIN tiene CRUD completo en todas las tablas. Hacemos ROLLBACK
-- para no eliminar datos reales.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana admin_qflix:
/*
DELETE FROM QUINDIOFLIX.USUARIOS WHERE id_usuario = 999999; -- no existe, 0 rows
ROLLBACK;
*/

-- Resultado esperado: 0 rows deleted (el id no existe pero el DELETE fue
-- PERMITIDO — Oracle no lanza error de privilegios, solo de datos)

-- -----------------------------------------------------------------------
-- OPERACION PROHIBIDA: DROP TABLE
-- ROL_ADMIN de QuindioFlix tiene privilegios de objeto sobre las tablas
-- del esquema pero NO tiene DROP ANY TABLE (es un rol de aplicacion,
-- no un DBA de Oracle). Intentar eliminar una tabla debe generar ORA-01031.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana admin_qflix:
/*
DROP TABLE QUINDIOFLIX.USUARIOS;
*/

-- Resultado esperado:
-- ORA-01031: insufficient privileges
-- admin_qflix puede hacer CRUD pero no DDL destructivo sobre el esquema.


-- =============================================================================
-- VENTANA 2: analista_qflix — ROL_ANALISTA
-- Copiar y ejecutar en la ventana conectada como analista_qflix
-- =============================================================================

-- -----------------------------------------------------------------------
-- OPERACION PERMITIDA: SELECT en REPRODUCCIONES con agrupacion
-- ROL_ANALISTA tiene SELECT en todas las tablas. Puede generar reportes.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana analista_qflix:
/*
SELECT EXTRACT(YEAR FROM fecha_hora_inicio) AS anio,
       COUNT(*)                             AS total_reproducciones,
       COUNT(DISTINCT id_perfil)            AS perfiles_activos
FROM   QUINDIOFLIX.REPRODUCCIONES
GROUP  BY EXTRACT(YEAR FROM fecha_hora_inicio)
ORDER  BY anio;
*/

-- Resultado esperado: filas con datos de 2024, 2025 y 2026 (SELECT permitido)

-- -----------------------------------------------------------------------
-- OPERACION PROHIBIDA: INSERT en PAGOS
-- ROL_ANALISTA es de solo lectura. Nunca debe registrar transacciones.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana analista_qflix:
/*
INSERT INTO QUINDIOFLIX.PAGOS
    (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES
    (SYSDATE, 14900, 'PSE', 'EXITOSO', 0, 1);
*/

-- Resultado esperado:
-- ORA-01031: insufficient privileges
-- analista_qflix solo tiene SELECT — no puede insertar datos financieros.


-- =============================================================================
-- VENTANA 3: soporte_qflix — ROL_SOPORTE
-- Copiar y ejecutar en la ventana conectada como soporte_qflix
-- =============================================================================

-- -----------------------------------------------------------------------
-- OPERACION PERMITIDA: SELECT en USUARIOS + INSERT en PAGOS
-- ROL_SOPORTE puede consultar cuentas y registrar/actualizar pagos.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana soporte_qflix:
/*
-- Ver datos del usuario con mora
SELECT id_usuario, nombre, apellido, email, estado_cuenta, fecha_vencimiento
FROM   QUINDIOFLIX.USUARIOS
WHERE  estado_cuenta = 'INACTIVO'
AND    ROWNUM <= 3;
*/

-- Resultado esperado: hasta 3 filas de usuarios inactivos (SELECT permitido)

-- -----------------------------------------------------------------------
-- OPERACION PROHIBIDA: DELETE en CONTENIDO
-- soporte_qflix no tiene ningun privilegio sobre CONTENIDO.
-- Un agente de soporte no debe poder eliminar el catalogo.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana soporte_qflix:
/*
DELETE FROM QUINDIOFLIX.CONTENIDO WHERE id_contenido = 1;
*/

-- Resultado esperado:
-- ORA-01031: insufficient privileges
-- ROL_SOPORTE no tiene ningun privilegio sobre la tabla CONTENIDO.


-- =============================================================================
-- VENTANA 4: contenido_qflix — ROL_CONTENIDO
-- Copiar y ejecutar en la ventana conectada como contenido_qflix
-- =============================================================================

-- -----------------------------------------------------------------------
-- OPERACION PERMITIDA: INSERT en CONTENIDO
-- ROL_CONTENIDO tiene CRUD completo sobre el catalogo. Hacemos ROLLBACK
-- para no dejar datos de prueba en la BD.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana contenido_qflix:
/*
INSERT INTO QUINDIOFLIX.CONTENIDO (
    titulo, anio_lanzamiento, clasificacion_edad,
    es_original_quindioflix, estado, id_categoria, id_empleado_publicacion
) VALUES (
    'Titulo de Prueba NT5-4', 2026, 'TP',
    'S', 'ACTIVO', 1, 1
);
ROLLBACK;
*/

-- Resultado esperado: 1 row inserted + Rollback complete
-- (INSERT permitido por ROL_CONTENIDO, ROLLBACK limpia el dato de prueba)

-- -----------------------------------------------------------------------
-- OPERACION PROHIBIDA: SELECT en PAGOS
-- ROL_CONTENIDO gestiona el catalogo pero NO debe ver datos financieros
-- de los usuarios. Esa informacion es sensible y corresponde a ROL_SOPORTE
-- o ROL_ADMIN.
-- -----------------------------------------------------------------------

-- Ejecutar en ventana contenido_qflix:
/*
SELECT id_pago, id_usuario, monto, estado_pago
FROM   QUINDIOFLIX.PAGOS
WHERE  ROWNUM <= 5;
*/

-- Resultado esperado:
-- ORA-01031: insufficient privileges
-- ROL_CONTENIDO no tiene ningun privilegio sobre la tabla PAGOS.


-- =============================================================================
-- VERIFICACION FINAL — Ejecutar como SYSTEM para confirmar los privilegios
-- =============================================================================

-- Confirmar que los privilegios estan correctamente asignados
-- (ejecutar en una ventana conectada como SYSTEM):
/*
SELECT grantee      AS rol,
       table_name   AS tabla,
       privilege    AS privilegio
FROM   dba_tab_privs
WHERE  grantee IN ('ROL_ADMIN','ROL_ANALISTA','ROL_SOPORTE','ROL_CONTENIDO')
  AND  table_name IN ('CONTENIDO','PAGOS','USUARIOS','REPRODUCCIONES')
ORDER  BY grantee, table_name, privilege;
*/

-- =============================================================================
-- RESUMEN DE RESTRICCIONES DEMOSTRADAS
-- =============================================================================
--
--  Usuario          Rol             Operacion prohibida        Error esperado
--  -----------------------------------------------------------------------
--  admin_qflix      ROL_ADMIN       DROP TABLE USUARIOS        ORA-01031
--  analista_qflix   ROL_ANALISTA    INSERT en PAGOS            ORA-01031
--  soporte_qflix    ROL_SOPORTE     DELETE en CONTENIDO        ORA-01031
--  contenido_qflix  ROL_CONTENIDO   SELECT en PAGOS            ORA-01031
--
--  En todos los casos Oracle lanza:
--    ORA-01031: insufficient privileges
--  porque el usuario no tiene el privilegio requerido sobre ese objeto,
--  ni directamente ni a traves de ningun rol asignado.
--
-- =============================================================================