-- =============================================================================
-- V4.1: Correcciones a datos transaccionales — QuindioFlix
-- Script  : V4.1__fix_datos_transaccionales.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Motivo  : Corregir los datos insertados por V4 para que sean coherentes
--           con los cambios de DDL aplicados en V2.1, y completar ajustes
--           pendientes de estructura que deben ejecutarse DESPUES de V4.
-- Cambios:
--   0. USUARIOS  — renombrar ciudad → ciudad_residencia (se hace aqui y no
--                  en V2.1 para que V4 pueda ejecutarse con el nombre original)
--   1. UPDATE USUARIOS — poblar telefono y fecha_nacimiento
--   2. UPDATE USUARIOS — redistribuir fecha_vencimiento 2025-2027
--   3. UPDATE PAGOS    — corregir metodo_pago y estado_pago a nuevos dominios
--   4. UPDATE PAGOS    — vincular descuento_aplicado con usuarios referidos
--   5. INSERT REPORTES_INAPROPIADO — 10 registros con estados variados
-- Orden de ejecucion garantizado por Flyway:
--   V2 → V2.1 → V3 → V3.1 → V4 (usa ciudad) → V4.1 (renombra a ciudad_residencia)
-- =============================================================================


-- =============================================================================
-- 0. USUARIOS — Renombrar ciudad → ciudad_residencia
--    Se hace AQUI (despues de V4) y no en V2.1 (antes de V4) porque
--    V4__datos_transaccionales.sql usa el nombre original 'ciudad' en su
--    INSERT y no puede modificarse (checksum Flyway).
--    Una vez ejecutado este rename, todos los scripts futuros (V5+) deben
--    usar ciudad_residencia.
-- =============================================================================
ALTER TABLE USUARIOS RENAME COLUMN ciudad TO ciudad_residencia;

COMMENT ON COLUMN USUARIOS.ciudad_residencia IS 'Ciudad de residencia del usuario. Usada en reportes de consumo por ciudad.';


-- =============================================================================
-- 1 y 2. USUARIOS — Poblar telefono, fecha_nacimiento y redistribuir
--         fecha_vencimiento.
--         La redistribucion es necesaria para que el cursor NT2 de suscripciones
--         vencidas tenga escenarios reales (~8 vencidos, ~18 activos).
--         Antes: todos en 2025 (todos morosos desde 2026-01-01).
--         Despues: distribucion realista para demostracion.
-- =============================================================================
UPDATE USUARIOS SET
                    telefono         = '3001111001',
                    fecha_nacimiento = DATE '1995-03-12',
                    fecha_vencimiento = DATE '2026-07-10'
WHERE email = 'sofia.perea@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111002',
                    fecha_nacimiento = DATE '1997-06-20',
                    fecha_vencimiento = DATE '2026-08-15'
WHERE email = 'mateo.perea@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111003',
                    fecha_nacimiento = DATE '1998-11-05',
                    fecha_vencimiento = DATE '2026-09-01'
WHERE email = 'valeria.lozano@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111004',
                    fecha_nacimiento = DATE '1990-04-18',
                    fecha_vencimiento = DATE '2026-10-12'
WHERE email = 'juan.arias@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111005',
                    fecha_nacimiento = DATE '1993-07-30',
                    fecha_vencimiento = DATE '2026-11-05'
WHERE email = 'laura.giraldo@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111006',
                    fecha_nacimiento = DATE '1994-09-14',
                    fecha_vencimiento = DATE '2026-12-22'
WHERE email = 'andres.mejia@quindioflix.com';

-- paula.mena — vencida en 2025 (morosa para el cursor NT2)
UPDATE USUARIOS SET
                    telefono         = '3001111007',
                    fecha_nacimiento = DATE '1999-01-25'
WHERE email = 'paula.mena@quindioflix.com';

-- nicolas.soto — vencida en 2025 (moroso)
UPDATE USUARIOS SET
                    telefono         = '3001111008',
                    fecha_nacimiento = DATE '1992-05-08'
WHERE email = 'nicolas.soto@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111009',
                    fecha_nacimiento = DATE '1996-08-22',
                    fecha_vencimiento = DATE '2027-02-01'
WHERE email = 'juliana.rendon@quindioflix.com';

-- esteban.buitrago — vencida en 2025 (moroso)
UPDATE USUARIOS SET
                    telefono         = '3001111010',
                    fecha_nacimiento = DATE '1991-12-03'
WHERE email = 'esteban.buitrago@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111011',
                    fecha_nacimiento = DATE '1988-02-17',
                    fecha_vencimiento = DATE '2027-03-03'
WHERE email = 'maria.duque@quindioflix.com';

-- santiago.bedoya — vencida en 2025 (moroso)
UPDATE USUARIOS SET
                    telefono         = '3001111012',
                    fecha_nacimiento = DATE '2000-10-09'
WHERE email = 'santiago.bedoya@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3001111013',
                    fecha_nacimiento = DATE '1997-03-28',
                    fecha_vencimiento = DATE '2027-04-08'
WHERE email = 'daniela.parra@quindioflix.com';

-- cristian.salazar — ya INACTIVO, dejar fecha_vencimiento original
UPDATE USUARIOS SET
                    telefono         = '3001111014',
                    fecha_nacimiento = DATE '1995-07-15'
WHERE email = 'cristian.salazar@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222015',
                    fecha_nacimiento = DATE '1993-01-11',
                    fecha_vencimiento = DATE '2026-07-11'
WHERE email = 'karen.restrepo@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222016',
                    fecha_nacimiento = DATE '1994-04-28',
                    fecha_vencimiento = DATE '2026-08-28'
WHERE email = 'felipe.londono@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222017',
                    fecha_nacimiento = DATE '1990-09-08',
                    fecha_vencimiento = DATE '2027-05-08'
WHERE email = 'natalia.franco@quindioflix.com';

-- david.marin — vencida en 2025 (moroso)
UPDATE USUARIOS SET
                    telefono         = '3002222018',
                    fecha_nacimiento = DATE '1998-12-26'
WHERE email = 'david.marin@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222019',
                    fecha_nacimiento = DATE '1996-06-14',
                    fecha_vencimiento = DATE '2027-06-14'
WHERE email = 'luisa.castano@quindioflix.com';

-- sebastian.roa — vencida en 2025 (moroso)
UPDATE USUARIOS SET
                    telefono         = '3002222020',
                    fecha_nacimiento = DATE '1991-11-06'
WHERE email = 'sebastian.roa@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222021',
                    fecha_nacimiento = DATE '2001-02-24',
                    fecha_vencimiento = DATE '2026-10-24'
WHERE email = 'sara.montes@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3002222022',
                    fecha_nacimiento = DATE '1999-08-16',
                    fecha_vencimiento = DATE '2027-07-16'
WHERE email = 'tomas.quintero@quindioflix.com';

-- ana.gomez — vencida en 2025 (morosa)
UPDATE USUARIOS SET
                    telefono         = '3002222023',
                    fecha_nacimiento = DATE '1987-05-11'
WHERE email = 'ana.gomez@quindioflix.com';

-- julian.colorado — ya INACTIVO
UPDATE USUARIOS SET
                    telefono         = '3002222024',
                    fecha_nacimiento = DATE '1993-10-03'
WHERE email = 'julian.colorado@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3003333025',
                    fecha_nacimiento = DATE '1989-04-20',
                    fecha_vencimiento = DATE '2026-11-20'
WHERE email = 'marcela.botero@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3003333026',
                    fecha_nacimiento = DATE '1992-07-18',
                    fecha_vencimiento = DATE '2027-08-18'
WHERE email = 'pipe.arango@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3003333027',
                    fecha_nacimiento = DATE '1997-02-09',
                    fecha_vencimiento = DATE '2027-09-09'
WHERE email = 'veronica.osorio@quindioflix.com';

UPDATE USUARIOS SET
                    telefono         = '3003333028',
                    fecha_nacimiento = DATE '1985-11-13',
                    fecha_vencimiento = DATE '2026-12-13'
WHERE email = 'camilo.toro@quindioflix.com';

-- isabella.bernal — vencida en 2025 (morosa)
UPDATE USUARIOS SET
                    telefono         = '3003333029',
                    fecha_nacimiento = DATE '2000-08-28'
WHERE email = 'isabella.bernal@quindioflix.com';

-- samuel.ocampo — ya SUSPENDIDO
UPDATE USUARIOS SET
                    telefono         = '3003333030',
                    fecha_nacimiento = DATE '1994-01-30'
WHERE email = 'samuel.ocampo@quindioflix.com';


-- =============================================================================
-- 3. PAGOS — Corregir metodo_pago y estado_pago a los nuevos valores
--    Orden correcto: DROP constraints viejos → UPDATE datos → ADD constraints nuevos.
--    Oracle valida todos los datos al hacer ADD CONSTRAINT, por eso los datos
--    deben estar ya corregidos antes de recrear el CHECK con los valores nuevos.
-- =============================================================================

-- Paso 3a: Eliminar CHECKs viejos para poder actualizar los datos sin restriccion
ALTER TABLE PAGOS DROP CONSTRAINT chk_pagos_metodo;
ALTER TABLE PAGOS DROP CONSTRAINT chk_pagos_estado;

-- Paso 3b: Convertir datos a los nuevos valores del enunciado (sec. 1.5)
UPDATE PAGOS SET metodo_pago = 'TARJETA_CREDITO'
WHERE metodo_pago = 'TARJETA' AND MOD(id_pago, 2) = 0;

UPDATE PAGOS SET metodo_pago = 'TARJETA_DEBITO'
WHERE metodo_pago = 'TARJETA' AND MOD(id_pago, 2) = 1;

UPDATE PAGOS SET estado_pago = 'EXITOSO' WHERE estado_pago = 'APROBADO';
UPDATE PAGOS SET estado_pago = 'FALLIDO' WHERE estado_pago = 'RECHAZADO';

-- Paso 3c: Recrear CHECKs con los valores correctos (ahora todos los datos cumplen)
ALTER TABLE PAGOS ADD CONSTRAINT chk_pagos_metodo
    CHECK (metodo_pago IN ('TARJETA_CREDITO', 'TARJETA_DEBITO', 'PSE', 'EFECTIVO', 'NEQUI', 'DAVIPLATA'));

ALTER TABLE PAGOS ADD CONSTRAINT chk_pagos_estado
    CHECK (estado_pago IN ('PENDIENTE', 'EXITOSO', 'FALLIDO', 'REEMBOLSADO'));

COMMENT ON COLUMN PAGOS.metodo_pago IS 'Medio de pago: TARJETA_CREDITO, TARJETA_DEBITO, PSE, EFECTIVO, NEQUI o DAVIPLATA.';
COMMENT ON COLUMN PAGOS.estado_pago IS 'Estado del pago: PENDIENTE, EXITOSO, FALLIDO o REEMBOLSADO.';


-- =============================================================================
-- 4. PAGOS — Vincular descuento_aplicado con usuarios que tienen referidor
--    Regla de negocio (enunciado seccion 1.2 y 1.5): el descuento por
--    referidos aplica solo cuando el usuario tiene id_referidor activo.
--    Los pagos de usuarios sin referidor deben tener descuento = 0.
-- =============================================================================

-- Quitar descuentos a usuarios sin referidor
UPDATE PAGOS p
SET descuento_aplicado = 0,
    monto = ROUND(
            CASE (SELECT id_plan FROM USUARIOS WHERE id_usuario = p.id_usuario)
                WHEN 1 THEN 14900
                WHEN 2 THEN 24900
                ELSE 34900
                END, 0)
WHERE p.descuento_aplicado > 0
  AND NOT EXISTS (
    SELECT 1 FROM USUARIOS u
    WHERE u.id_usuario = p.id_usuario
      AND u.id_referidor IS NOT NULL
);


-- =============================================================================
-- 5. REPORTES_INAPROPIADO — 10 registros con estados variados
--    Requerido para demostrar el flujo de moderacion (NT2) y la consulta
--    de rendimiento de moderadores del enunciado (seccion 1.6):
--    "cuantos reportes ha resuelto cada moderador".
--    Los tres moderadores son natalia.franco, pipe.arango, camilo.toro.
-- =============================================================================
INSERT INTO REPORTES_INAPROPIADO
(motivo, estado_reporte, fecha_reporte, fecha_resolucion, id_perfil_reporta, id_contenido, id_moderador)
WITH rep_seed AS (
    -- RESUELTOS: moderador asignado + fecha de resolucion
    SELECT
        'Contenido con lenguaje inapropiado para menores' motivo,
        'RESUELTO'        estado,
        DATE '2025-02-10' f_rep,
        DATE '2025-02-12' f_res,
        'Monstruos'       titulo_parcial,
        'natalia.franco@quindioflix.com' email_mod
    FROM DUAL UNION ALL
    SELECT
        'Escenas de violencia extrema sin advertencia previa',
        'RESUELTO', DATE '2025-02-18', DATE '2025-02-20',
        'Narcos', 'pipe.arango@quindioflix.com'
    FROM DUAL UNION ALL
    SELECT
        'Audio del episodio 3 contiene lenguaje soez sin clasificacion',
        'RESUELTO', DATE '2025-03-05', DATE '2025-03-07',
        'Herencia', 'camilo.toro@quindioflix.com'
    FROM DUAL UNION ALL
    SELECT
        'El contenido promueve estereotipos negativos de una region',
        'RESUELTO', DATE '2025-03-15', DATE '2025-03-18',
        'Tierra Roja', 'natalia.franco@quindioflix.com'
    FROM DUAL UNION ALL
    -- DESCARTADOS: revisados y descartados por el moderador
    SELECT
        'El titulo parece estar mal escrito, no es contenido inapropiado',
        'DESCARTADO', DATE '2025-03-22', DATE '2025-03-23',
        'Velocidad', 'pipe.arango@quindioflix.com'
    FROM DUAL UNION ALL
    SELECT
        'La clasificacion +16 deberia ser +18 segun mi criterio personal',
        'DESCARTADO', DATE '2025-04-01', DATE '2025-04-02',
        'Sombras', 'camilo.toro@quindioflix.com'
    FROM DUAL UNION ALL
    -- EN REVISION: moderador asignado, aun sin resolver
    SELECT
        'Posible publicidad encubierta dentro del contenido del podcast',
        'EN_REVISION', DATE '2025-11-10', NULL,
        'Emprender', 'natalia.franco@quindioflix.com'
    FROM DUAL UNION ALL
    SELECT
        'Fragmento musical usa samples sin creditar al artista original',
        'EN_REVISION', DATE '2025-11-20', NULL,
        'Urbano', 'pipe.arango@quindioflix.com'
    FROM DUAL UNION ALL
    -- PENDIENTES: sin moderador asignado aun
    SELECT
        'El documental contiene imagenes perturbadoras sin advertencia previa',
        'PENDIENTE', DATE '2025-12-05', NULL,
        'Amazonas', NULL
    FROM DUAL UNION ALL
    SELECT
        'El titulo del episodio 2 revela el final de la serie completa',
        'PENDIENTE', DATE '2025-12-18', NULL,
        'Hackers', NULL
    FROM DUAL
)
SELECT
    rs.motivo,
    rs.estado,
    rs.f_rep,
    rs.f_res,
    -- Tomar el perfil de menor id que haya reproducido contenido similar
    NVL(
            (SELECT MIN(r.id_perfil)
             FROM REPRODUCCIONES r
                      JOIN CONTENIDO c ON c.id_contenido = r.id_contenido
             WHERE UPPER(c.titulo) LIKE '%' || UPPER(rs.titulo_parcial) || '%'),
            (SELECT MIN(id_perfil) FROM PERFILES)
    ) AS id_perfil_reporta,
    -- Resolver id_contenido por titulo parcial
    (SELECT id_contenido FROM CONTENIDO
     WHERE UPPER(titulo) LIKE '%' || UPPER(rs.titulo_parcial) || '%'
       AND ROWNUM = 1
    ) AS id_contenido,
    -- Resolver id_moderador por email (NULL si el reporte esta PENDIENTE)
    CASE
        WHEN rs.email_mod IS NULL THEN NULL
        ELSE (SELECT id_usuario FROM USUARIOS WHERE email = rs.email_mod)
        END AS id_moderador
FROM rep_seed rs;


COMMIT;


-- =============================================================================
-- VERIFICACION — ejecutar en SQL Developer para confirmar V4.1:
--
-- 1) Confirmar telefono y fecha_nacimiento poblados en todos los usuarios:
-- SELECT email, telefono, fecha_nacimiento
-- FROM USUARIOS ORDER BY id_usuario;
-- Resultado esperado: 30 filas con telefono y fecha_nacimiento no nulos.
--
-- 0) Confirmar que el rename ciudad → ciudad_residencia se aplico:
-- SELECT column_name FROM user_tab_columns
-- WHERE table_name = 'USUARIOS' AND column_name IN ('CIUDAD', 'CIUDAD_RESIDENCIA');
-- Resultado esperado: solo CIUDAD_RESIDENCIA (CIUDAD ya no existe).
--
-- 2) Distribucion de fechas de vencimiento (activos vs vencidos):
-- SELECT
--     CASE WHEN fecha_vencimiento > SYSDATE THEN 'VIGENTE' ELSE 'VENCIDA' END AS estado_vc,
--     COUNT(*) AS total
-- FROM USUARIOS
-- GROUP BY CASE WHEN fecha_vencimiento > SYSDATE THEN 'VIGENTE' ELSE 'VENCIDA' END;
-- Resultado esperado: ~18 VIGENTES, ~8 VENCIDAS, 4 ya en INACTIVO/SUSPENDIDO.
--
-- 3) Confirmar que no quedan valores 'TARJETA', 'APROBADO' o 'RECHAZADO' en PAGOS:
-- SELECT DISTINCT metodo_pago FROM PAGOS ORDER BY 1;
-- SELECT DISTINCT estado_pago  FROM PAGOS ORDER BY 1;
-- Resultado esperado: solo TARJETA_CREDITO, TARJETA_DEBITO, PSE, EFECTIVO,
--                     NEQUI, DAVIPLATA para metodo; PENDIENTE, EXITOSO,
--                     FALLIDO, REEMBOLSADO para estado.
--
-- 4) Confirmar descuentos solo en usuarios con referidor:
-- SELECT u.email, u.id_referidor, p.descuento_aplicado
-- FROM PAGOS p JOIN USUARIOS u ON u.id_usuario = p.id_usuario
-- WHERE p.descuento_aplicado > 0
-- ORDER BY u.email;
-- Resultado esperado: solo filas donde id_referidor IS NOT NULL.
--
-- 5) Confirmar 10 reportes con distribucion de estados:
-- SELECT estado_reporte, COUNT(*) FROM REPORTES_INAPROPIADO
-- GROUP BY estado_reporte ORDER BY 1;
-- Resultado esperado:
--   DESCARTADO  2
--   EN_REVISION 2
--   PENDIENTE   2
--   RESUELTO    4
--
-- 6) Rendimiento de moderadores (consulta del enunciado seccion 1.6):
-- SELECT u.nombre || ' ' || u.apellido AS moderador,
--        COUNT(*) AS reportes_resueltos
-- FROM REPORTES_INAPROPIADO ri
-- JOIN USUARIOS u ON u.id_usuario = ri.id_moderador
-- WHERE ri.estado_reporte = 'RESUELTO'
-- GROUP BY u.nombre, u.apellido
-- ORDER BY reportes_resueltos DESC;
-- =============================================================================