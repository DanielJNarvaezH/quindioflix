-- =============================================================================
-- V2.1: Correcciones al DDL — QuindioFlix
-- Script  : V2.1__fix_usuarios_particion_2026.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Motivo  : Alinear V2__create_tables.sql con el enunciado del proyecto
--           (Proyecto Final Estudiantes.pdf, seccion 1.2).
--           V2 no se modifica porque ya fue ejecutado en todas las maquinas;
--           este script aplica los cambios de forma incremental via ALTER.
-- Cambios:
--   1. USUARIOS      — agregar telefono y fecha_nacimiento (enunciado sec. 1.2)
--   2. REPRODUCCIONES — agregar particion p_2026 para soportar inserciones
--                       con fecha actual sin error ORA-14401
-- NOTAS IMPORTANTES sobre lo que NO va aqui:
--   - El rename ciudad → ciudad_residencia va en V4.1 (despues de V4 que
--     aun usa 'ciudad').
--   - Los CHECKs de PAGOS (metodo_pago, estado_pago) van en V4.1 (despues
--     de V4 que inserta con los valores viejos 'TARJETA', 'APROBADO', etc.)
--   Orden garantizado: V2 → V2.1 → V3 → V3.1 → V4 → V4.1
-- =============================================================================


-- =============================================================================
-- 1. USUARIOS — Agregar columnas requeridas por el enunciado (seccion 1.2)
--    "Los usuarios se registran con sus datos personales:
--     nombre, email, telefono, fecha de nacimiento, ciudad de residencia."
-- =============================================================================
ALTER TABLE USUARIOS ADD telefono VARCHAR2(20) DEFAULT NULL;
ALTER TABLE USUARIOS ADD fecha_nacimiento DATE DEFAULT NULL;

COMMENT ON COLUMN USUARIOS.telefono         IS 'Numero de telefono del usuario. Campo opcional.';
COMMENT ON COLUMN USUARIOS.fecha_nacimiento IS 'Fecha de nacimiento del usuario. Usada para validar clasificacion de edad.';


-- =============================================================================
-- 2. REPRODUCCIONES — Agregar particion p_2026
--    Las particiones existentes cubren solo hasta 2025-12-31.
--    Cualquier insercion con fecha >= 2026-01-01 lanza ORA-14401 sin esta
--    particion. El tablespace ts_quindioflix_reprod_2025 se reutiliza porque
--    el enunciado no requiere un tablespace dedicado para 2026.
-- =============================================================================
ALTER TABLE REPRODUCCIONES
    ADD PARTITION p_2026
    VALUES LESS THAN (TIMESTAMP '2027-01-01 00:00:00')
    TABLESPACE ts_quindioflix_reprod_2025;


-- =============================================================================
-- VERIFICACION — ejecutar en SQL Developer para confirmar V2.1:
--
-- 1) Confirmar nuevas columnas en USUARIOS:
-- SELECT column_name, data_type, nullable
-- FROM user_tab_columns
-- WHERE table_name = 'USUARIOS'
-- ORDER BY column_id;
-- Resultado esperado: telefono y fecha_nacimiento presentes.
--   - 'ciudad' aun se llama 'ciudad' aqui (rename ocurre en V4.1)
--   - Los CHECKs de PAGOS aun tienen valores originales (se corrigen en V4.1)
--
-- 2) Confirmar particion p_2026 en REPRODUCCIONES:
-- SELECT partition_name, high_value, tablespace_name
-- FROM user_tab_partitions
-- WHERE table_name = 'REPRODUCCIONES'
-- ORDER BY partition_position;
-- Resultado esperado: p_2024, p_2025, p_2026.
-- =============================================================================