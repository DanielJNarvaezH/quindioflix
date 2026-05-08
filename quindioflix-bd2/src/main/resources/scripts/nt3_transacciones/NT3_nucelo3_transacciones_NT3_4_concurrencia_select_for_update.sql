-- =============================================================================
-- NT3-4: Escenario de concurrencia — SELECT FOR UPDATE
-- Archivo : NT3_nucleo3_transacciones_NT3_4_CONCURRENCIA_SELECT_FOR_UPDATE.sql
-- Autor   : Daniel Narvaez
-- Sprint  : 4 — S14 (11/05–17/05/2026)
-- =============================================================================
-- Descripcion:
--   Demuestra como Oracle maneja la concurrencia cuando dos sesiones intentan
--   modificar el mismo registro simultaneamente. Se usa SELECT FOR UPDATE para
--   bloquear la fila antes de modificarla, garantizando que solo una sesion
--   pueda procesar el cambio de plan en un momento dado.
--
-- Escenario:
--   Dos sesiones abiertas en SQL Developer intentan cambiar el plan del
--   mismo usuario (id_usuario = 3, Valeria Lozano). La Sesion 1 bloquea
--   la fila primero. La Sesion 2 intenta bloquear la misma fila y queda
--   ESPERANDO hasta que la Sesion 1 haga COMMIT o ROLLBACK.
--
-- Mecanismo Oracle:
--   SELECT ... FOR UPDATE adquiere un Row-Level Lock (TX lock) sobre las
--   filas seleccionadas. Oracle usa MVCC (Multi-Version Concurrency Control)
--   para que los lectores no bloqueen a los escritores, pero dos escritores
--   sobre la misma fila si se bloquean entre si.
--
-- Por que SELECT FOR UPDATE y no UPDATE directo:
--   El UPDATE directo tambien bloquea, pero SELECT FOR UPDATE permite leer
--   los datos actuales ANTES de modificarlos dentro de la misma transaccion,
--   asegurando que la decision de cambio se basa en datos frescos y no en
--   datos leidos antes de que otra sesion los modificara.
--
-- Resolucion del bloqueo:
--   - Si Sesion 1 hace COMMIT  -> Sesion 2 se desbloquea y ve los datos ya
--     modificados por Sesion 1, puede proceder con su propio cambio.
--   - Si Sesion 1 hace ROLLBACK -> Sesion 2 se desbloquea y ve los datos
--     originales, como si Sesion 1 nunca hubiera actuado.
--   - Con NOWAIT: si la fila esta bloqueada, lanza ORA-00054 inmediatamente
--     en lugar de esperar.
--
-- Estados de transaccion documentados:
--   Sesion 1: ACTIVA -> bloqueo adquirido -> PARCIALMENTE CONFIRMADA -> CONFIRMADA
--   Sesion 2: ACTIVA -> BLOQUEADA (esperando) -> ACTIVA (al liberarse) -> CONFIRMADA
--
-- INSTRUCCIONES DE EJECUCION:
--   1. Abrir DOS ventanas de SQL Developer (o dos pestanas SQL Worksheet)
--      conectadas como QUINDIOFLIX.
--   2. Ejecutar los bloques de SESION 1 y SESION 2 en el orden indicado.
--   3. Tomar capturas de pantalla en cada paso para documentar el escenario.
--   4. NO ejecutar este script completo con F5 — ejecutar bloque por bloque
--      en las dos sesiones por separado.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- PASO PREVIO: Verificar estado inicial del usuario de prueba
-- Ejecutar en CUALQUIERA de las dos sesiones antes de comenzar
-- =============================================================================

PROMPT ============================================================
PROMPT ESTADO INICIAL — ejecutar antes de comenzar el escenario
PROMPT ============================================================

SELECT u.id_usuario, u.nombre, u.apellido, u.email,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3;

-- Resultado esperado: Valeria Lozano, plan Basico (id_plan=1)
-- Si el plan es diferente, ajustar los scripts de sesion abajo.


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- SESION 1 — Ejecutar en la primera ventana de SQL Developer
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 1: Bloquear la fila con SELECT FOR UPDATE
-- TOMAR CAPTURA despues de ejecutar este bloque.
-- La sesion 1 tiene el lock. La sesion 2 aun no ha intentado nada.
-- Estado: ACTIVA con bloqueo adquirido
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 ==

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: ACTIVA');
    DBMS_OUTPUT.PUT_LINE('Adquiriendo bloqueo sobre usuario id=3...');
END;
/

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3
FOR UPDATE OF u.id_plan;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Lock adquirido sobre usuario id=3 (Valeria Lozano)');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: PARCIALMENTE CONFIRMADA (fila bloqueada)');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Ahora ejecutar SESION 2 PASO 1 y tomar captura del bloqueo');
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 2: Aplicar el cambio de plan (Basico -> Estandar)
-- Ejecutar DESPUES de que Sesion 2 este esperando (bloqueada).
-- TOMAR CAPTURA de Sesion 2 esperando ANTES de ejecutar esto.
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 (despues de ver que Sesion 2 espera) ==

DECLARE
    v_total_perfiles NUMBER;
    v_max_perfiles   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total_perfiles
    FROM   PERFILES WHERE id_usuario = 3;

    SELECT max_perfiles INTO v_max_perfiles
    FROM   PLANES WHERE id_plan = 2;  -- Estandar

    IF v_total_perfiles <= v_max_perfiles THEN
        UPDATE USUARIOS SET id_plan = 2 WHERE id_usuario = 3;
        DBMS_OUTPUT.PUT_LINE('SESION 1 — Plan actualizado: Basico -> Estandar');
        DBMS_OUTPUT.PUT_LINE('SESION 1 — Perfiles actuales: ' || v_total_perfiles ||
            ' / Max permitido: ' || v_max_perfiles);
    ELSE
        DBMS_OUTPUT.PUT_LINE('SESION 1 — FALLIDO: perfiles exceden limite del nuevo plan');
        ROLLBACK;
    END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 1 — PASO 3: COMMIT — libera el bloqueo
-- TOMAR CAPTURA inmediatamente despues: Sesion 2 se desbloquea.
-- Estado Sesion 1: CONFIRMADA
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 1 ==

COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 1 — ESTADO: CONFIRMADA — COMMIT ejecutado');
    DBMS_OUTPUT.PUT_LINE('SESION 1 — Bloqueo liberado. Sesion 2 puede continuar.');
END;
/
*/


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- SESION 2 — Ejecutar en la segunda ventana de SQL Developer
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 1: Intentar bloquear la misma fila
-- Ejecutar DESPUES de que Sesion 1 ya ejecuto su PASO 1.
-- TOMAR CAPTURA: Sesion 2 queda colgada esperando (spinning cursor).
-- Estado: BLOQUEADA — esperando que Sesion 1 libere
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 ==

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: ACTIVA');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Intentando bloquear usuario id=3...');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Si Sesion 1 tiene el lock, esta consulta ESPERARA');
END;
/

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_actual, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3
FOR UPDATE OF u.id_plan;   -- BLOQUEADO si Sesion 1 tiene el lock

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: ACTIVA — bloqueo adquirido (Sesion 1 hizo COMMIT)');
    DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actual del usuario (ya modificado por Sesion 1):');
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — VARIANTE CON NOWAIT (opcional — para demostrar ORA-00054)
-- En lugar de esperar indefinidamente, lanza error si la fila esta bloqueada.
-- Descomentar esta version y comentar la anterior para demostrar NOWAIT.
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 (variante NOWAIT) ==

DECLARE
    v_id     NUMBER;
    v_nombre VARCHAR2(100);
BEGIN
    SELECT u.id_usuario, u.nombre INTO v_id, v_nombre
    FROM   USUARIOS u
    WHERE  u.id_usuario = 3
    FOR UPDATE OF u.id_plan NOWAIT;

    DBMS_OUTPUT.PUT_LINE('SESION 2 — Lock adquirido con NOWAIT');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -54 THEN
            DBMS_OUTPUT.PUT_LINE('SESION 2 — ORA-00054: fila bloqueada por otra sesion');
            DBMS_OUTPUT.PUT_LINE('SESION 2 — NOWAIT: la sesion no espera, reporta el error');
        ELSE
            DBMS_OUTPUT.PUT_LINE('SESION 2 — Error: ' || SQLERRM);
        END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 2: Aplicar su propio cambio (Estandar -> Premium)
-- Ejecutar solo despues de que Sesion 1 hizo COMMIT y Sesion 2 se desbloqueo.
-- En este punto el usuario ya tiene plan Estandar (cambiado por Sesion 1).
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 (despues de desbloquearse) ==

DECLARE
    v_total_perfiles NUMBER;
    v_max_perfiles   NUMBER;
    v_plan_actual    VARCHAR2(30);
BEGIN
    SELECT pl.nombre INTO v_plan_actual
    FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
    WHERE  u.id_usuario = 3;

    DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actual (post-Sesion1): ' || v_plan_actual);

    SELECT COUNT(*) INTO v_total_perfiles FROM PERFILES WHERE id_usuario = 3;
    SELECT max_perfiles INTO v_max_perfiles FROM PLANES WHERE id_plan = 3;  -- Premium

    IF v_total_perfiles <= v_max_perfiles THEN
        UPDATE USUARIOS SET id_plan = 3 WHERE id_usuario = 3;
        DBMS_OUTPUT.PUT_LINE('SESION 2 — Plan actualizado: ' || v_plan_actual || ' -> Premium');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SESION 2 — FALLIDO: perfiles exceden limite Premium');
        ROLLBACK;
    END IF;
END;
/
*/


-- -----------------------------------------------------------------------------
-- SESION 2 — PASO 3: COMMIT
-- Estado Sesion 2: CONFIRMADA
-- -----------------------------------------------------------------------------

/*
-- == EJECUTAR EN SESION 2 ==

COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('SESION 2 — ESTADO: CONFIRMADA');
END;
/
*/


-- =============================================================================
-- PASO FINAL: Verificar estado final del usuario
-- Ejecutar en cualquier sesion despues de que ambas hicieron COMMIT
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT ESTADO FINAL — verificar despues de ambas sesiones
PROMPT ============================================================

SELECT u.id_usuario, u.nombre, u.apellido,
       pl.nombre AS plan_final, pl.id_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan = u.id_plan
WHERE  u.id_usuario = 3;

-- Resultado esperado: Valeria Lozano, plan Premium (si ambas sesiones tuvieron exito)

-- Restaurar plan original para no afectar otros scripts:
/*
UPDATE USUARIOS SET id_plan = 1 WHERE id_usuario = 3;
COMMIT;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Plan restaurado a Basico (estado original).');
END;
/
*/


-- =============================================================================
-- CONSULTA DE DIAGNOSTICO: Ver bloqueos activos en Oracle
-- Ejecutar como SYSTEM en una tercera ventana mientras el bloqueo esta activo
-- (entre Sesion 1 Paso 1 y Sesion 1 Paso 3) para documentar el lock.
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT DIAGNOSTICO DE BLOQUEOS — ejecutar como SYSTEM mientras
PROMPT Sesion 2 esta esperando (para captura de pantalla)
PROMPT ============================================================

/*
-- == EJECUTAR COMO SYSTEM ==
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.blocking_session,
    l.type         AS lock_type,
    l.lmode        AS lock_mode,    -- 6 = Exclusive (X)
    l.request      AS lock_request, -- 6 = esperando Exclusive
    l.block        AS is_blocking,  -- 1 = esta bloqueando a alguien
    o.object_name,
    o.object_type
FROM   v$session s
JOIN   v$lock    l ON l.sid = s.sid
LEFT   JOIN dba_objects o ON o.object_id = l.id1
WHERE  s.username = 'QUINDIOFLIX'
  AND  l.type IN ('TM', 'TX')
ORDER  BY s.sid;
*/


-- =============================================================================
-- RESUMEN DEL ESCENARIO DE CONCURRENCIA
-- =============================================================================
/*
  TIMELINE DEL ESCENARIO:
  ========================

  T1  Sesion 1: SELECT FOR UPDATE  -> adquiere lock sobre usuario id=3
  T2  Sesion 2: SELECT FOR UPDATE  -> BLOQUEADA, espera a Sesion 1
                (cursor girando en SQL Developer — tomar captura)
  T3  Sesion 1: UPDATE id_plan=2   -> modifica el plan a Estandar
  T4  Sesion 1: COMMIT             -> libera el lock
  T5  Sesion 2: desbloquea         -> ve plan=Estandar (ya modificado)
  T6  Sesion 2: UPDATE id_plan=3   -> modifica el plan a Premium
  T7  Sesion 2: COMMIT             -> confirma

  RESULTADO: serializable y correcto. Ninguna modificacion se pierde.
  El plan pasa de Basico -> Estandar (Sesion 1) -> Premium (Sesion 2).

  SIN SELECT FOR UPDATE (problema lost update sin lock):
  ======================================================
  T1  Sesion 1: lee plan=Basico
  T2  Sesion 2: lee plan=Basico
  T3  Sesion 1: UPDATE plan=Estandar, COMMIT
  T4  Sesion 2: UPDATE plan=Premium  (basado en lectura stale de Basico)
  T4  Sesion 2: COMMIT
  RESULTADO: ambos commits pasan pero Sesion 1 se pierde (lost update).
  Con SELECT FOR UPDATE Oracle previene este escenario.
*/