-- =============================================================================
-- NT2: PL/SQL Avanzado — QuindioFlix
-- Script  : NT2__nucleo2_plsql_NT2_COMPLETO.sql
-- Runner  : manual en la BD local de Oracle de cada integrante
-- Autores : Daniel Narvaez, Diego Garcia, Cristhian Osorio
-- Nucleo  : NT2 — Cursores, Stored Procedures, Funciones, Triggers,
--           Excepciones Personalizadas
--
-- NOTA DE EJECUCION:
--   Este script crea objetos PL/SQL permanentes en la BD (procedimientos,
--   funciones y triggers). Ejecutar con Run as Script (F5) en SQL Developer
--   con SERVEROUTPUT ON activo. Cada objeto se crea con CREATE OR REPLACE,
--   por lo que es seguro re-ejecutar el script sin efectos secundarios.
--
--   Los bloques anonimos (cursores y pruebas) usan ROLLBACK al final
--   para no acumular datos de prueba en la BD.
--
--   PREREQUISITO: Haber ejecutado todos los scripts Flyway (V1 a V4.1)
--   y el script de datos extra (Insercion_de_datos_extra.sql).
--
-- Estructura del script:
--   NT2-1  Cursor suscripciones vencidas        — Daniel Narvaez
--   NT2-2  Cursor popularidad (FOR UPDATE)       — Diego Garcia
--   NT2-3  SP_REGISTRAR_USUARIO                  — Cristhian Osorio
--   NT2-4  SP_CAMBIAR_PLAN                       — Daniel Narvaez
--   NT2-5  SP_REPORTE_CONSUMO                    — Diego Garcia
--   NT2-6  FN_CALCULAR_MONTO                     — Cristhian Osorio
--   NT2-7  FN_CONTENIDO_RECOMENDADO              — Diego Garcia
--   NT2-10 TRG_VALID_CUENTA (REPRODUCCIONES)     — Daniel Narvaez
--   NT2-11 TRG_MAX_PERFILES (PERFILES)            — Diego Garcia
--   NT2-12 TRG_VALID_CALIFICACION (CALIFICACIONES)— Cristhian Osorio
--   NT2-13 TRG_ACTIVAR_CUENTA (PAGOS)            — Equipo QuindioFlix
--
-- MAPA DE CODIGOS DE ERROR PERSONALIZADOS (rango Oracle -20000 a -20999):
--   SP_CAMBIAR_PLAN        : -20001 (PERFILES_EXCEDIDOS)
--                            -20002 (USUARIO_NO_EXISTE)
--                            -20003 (PLAN_NO_EXISTE)
--                            -20004 (MISMO_PLAN)
--   TRG_VALID_CUENTA       : -20010 (cuenta INACTIVA)
--                            -20011 (cuenta SUSPENDIDA)
--                            -20012 (perfil no encontrado)
--   SP_REGISTRAR_USUARIO   : -20011 (EMAIL_DUPLICADO)  [comparte rango con TRG_VALID_CUENTA]
--                            -20012 (PLAN_NO_EXISTE)
--   TRG_MAX_PERFILES       : -20021 (limite de perfiles excedido)
--                            -20022 (usuario no encontrado)
--   FN_CALCULAR_MONTO      : -20021 (USUARIO_NO_EXISTE) [comparte con TRG_MAX_PERFILES]
--   FN_CONTENIDO_RECOMENDADO: -20010 (perfil no existe)
--   TRG_VALID_CALIFICACION : -20031 (avance insuficiente)
--   Catch-all todos los SP : -20099 (error inesperado)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;


-- =============================================================================
-- NT2-1: CURSOR — USUARIOS CON SUSCRIPCION VENCIDA
-- Autor  : Daniel Narvaez
-- Tipo   : Bloque anonimo con cursor explicito OPEN/FETCH/CLOSE
-- Tema   : %ROWTYPE, cursor explicito, FETCH, calculo de mora
--
-- Recorre usuarios cuyo ultimo pago EXITOSO supera los 30 dias de
-- antiguedad, o que nunca han pagado y su fecha_vencimiento ya paso.
-- Genera un reporte de mora con dias y monto adeudado por usuario.
--
-- Logica de mora:
--   dias_mora      = TRUNC(SYSDATE) - fecha del ultimo pago EXITOSO
--                    (si nunca pago, se toma fecha_vencimiento)
--   monto_adeudado = precio_mensual * CEIL(dias_mora / 30)
--
-- Tecnicas PL/SQL demostradas:
--   %ROWTYPE  : el registro v_fila se declara con cur_mora%ROWTYPE
--   FETCH     : ciclo OPEN / FETCH / EXIT WHEN %NOTFOUND / CLOSE explicito
--   Cursor    : cur_mora definido en la seccion DECLARE con JOIN y HAVING
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-1: Cursor — Usuarios con suscripcion vencida
PROMPT ============================================================

DECLARE

    -- -------------------------------------------------------------------------
    -- Cursor principal: une USUARIOS con PLANES y PAGOS (LEFT JOIN para
    -- capturar usuarios sin ningun pago). HAVING filtra solo los morosos.
    -- -------------------------------------------------------------------------
CURSOR cur_mora IS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellido,
    u.email,
    u.fecha_vencimiento,
    u.estado_cuenta,
    pl.nombre         AS nombre_plan,
    pl.precio_mensual,
    MAX(pa.fecha_pago) AS fecha_ultimo_pago
FROM   USUARIOS u
           JOIN   PLANES   pl ON pl.id_plan    = u.id_plan
           LEFT   JOIN PAGOS pa
                       ON  pa.id_usuario  = u.id_usuario
                           AND pa.estado_pago = 'EXITOSO'
WHERE  u.estado_cuenta IN ('ACTIVO', 'INACTIVO')
GROUP  BY
    u.id_usuario, u.nombre, u.apellido, u.email,
    u.fecha_vencimiento, u.estado_cuenta,
    pl.nombre, pl.precio_mensual
HAVING
    (MAX(pa.fecha_pago) IS NOT NULL
        AND TRUNC(SYSDATE) - MAX(pa.fecha_pago) > 30)
    OR
    (MAX(pa.fecha_pago) IS NULL
        AND u.fecha_vencimiento < TRUNC(SYSDATE))
ORDER  BY
    (TRUNC(SYSDATE) - NVL(MAX(pa.fecha_pago), u.fecha_vencimiento)) DESC;

-- Registro tipado con %ROWTYPE — captura la fila completa de cur_mora
v_fila           cur_mora%ROWTYPE;

    -- Variables de calculo derivadas (no vienen directamente del cursor)
    v_dias_mora      NUMBER(6);
    v_meses_mora     NUMBER(4);
    v_monto_adeudado NUMBER(12, 2);

    -- Contadores para el resumen final
    v_total_usuarios NUMBER(6)     := 0;
    v_monto_total    NUMBER(14, 2) := 0;

    c_linea CONSTANT VARCHAR2(100) :=
        RPAD('-', 80, '-');

BEGIN

    DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE('  QUINDIOFLIX — REPORTE DE SUSCRIPCIONES VENCIDAS');
    DBMS_OUTPUT.PUT_LINE('  Fecha de corte : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NOMBRE',         30) || ' ' ||
        RPAD('PLAN',           10) || ' ' ||
        LPAD('DIAS MORA',      10) || ' ' ||
        LPAD('MONTO ADEUDADO', 16)
    );
    DBMS_OUTPUT.PUT_LINE(c_linea);

    -- Apertura explicita del cursor
OPEN cur_mora;

LOOP
FETCH cur_mora INTO v_fila;
        EXIT WHEN cur_mora%NOTFOUND;

        -- Calcular dias de mora
        v_dias_mora := TRUNC(SYSDATE)
                       - NVL(v_fila.fecha_ultimo_pago, v_fila.fecha_vencimiento);

        v_meses_mora     := CEIL(v_dias_mora / 30);
        v_monto_adeudado := v_fila.precio_mensual * v_meses_mora;

        v_total_usuarios := v_total_usuarios + 1;
        v_monto_total    := v_monto_total + v_monto_adeudado;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_fila.nombre || ' ' || v_fila.apellido, 30) || ' ' ||
            RPAD(v_fila.nombre_plan,                       10) || ' ' ||
            LPAD(v_dias_mora,                              10) || ' ' ||
            LPAD(TO_CHAR(v_monto_adeudado, 'FM$999,999,990.00'), 16)
        );
END LOOP;

    -- Cierre explicito del cursor
CLOSE cur_mora;

DBMS_OUTPUT.PUT_LINE(c_linea);
    DBMS_OUTPUT.PUT_LINE('Total usuarios en mora : ' || v_total_usuarios);
    DBMS_OUTPUT.PUT_LINE('Cartera adeudada total : ' ||
        TO_CHAR(v_monto_total, 'FM$999,999,990.00'));
    DBMS_OUTPUT.PUT_LINE(c_linea);

EXCEPTION
    WHEN OTHERS THEN
        IF cur_mora%ISOPEN THEN CLOSE cur_mora; END IF;
        DBMS_OUTPUT.PUT_LINE('ERROR NT2-1: ' || SQLERRM);
        RAISE;
END;
/


-- =============================================================================
-- NT2-2: CURSOR — ACTUALIZAR POPULARIDAD DE CONTENIDO (FOR UPDATE)
-- Autor  : Diego Garcia
-- Tipo   : Bloque anonimo con cursor FOR UPDATE / WHERE CURRENT OF
-- Tema   : Cursor de actualizacion, bloqueo a nivel de fila, NOWAIT
--
-- Recorre cada contenido del catalogo y recalcula su campo popularidad
-- basado en la proporcion de reproducciones completas (>= 90% de avance)
-- ponderadas por el promedio de estrellas de calificacion.
--
-- Formula:
--   factor_calificacion = NVL(promedio_estrellas / 5, 1)
--   popularidad = ROUND((vistas_completas / total_reprod) * 100
--                        * factor_calificacion, 2)
--
-- Tecnicas PL/SQL demostradas:
--   FOR UPDATE OF popularidad NOWAIT : bloqueo optimista por fila
--   WHERE CURRENT OF cur_contenido   : UPDATE sin busqueda adicional por PK
--   TYPE ... IS RECORD               : tipo registro personalizado
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-2: Cursor — Actualizar popularidad de contenido
PROMPT ============================================================

DECLARE
TYPE t_contenido_rec IS RECORD (
        id_contenido       CONTENIDO.id_contenido%TYPE,
        titulo             CONTENIDO.titulo%TYPE,
        popularidad_actual CONTENIDO.popularidad%TYPE
    );

    v_total_reproducciones    NUMBER := 0;
    v_vistas_completas        NUMBER := 0;
    v_promedio_estrellas      NUMBER := 0;
    v_nueva_popularidad       NUMBER := 0;
    v_factor_calificacion     NUMBER := 1;
    v_contenidos_actualizados NUMBER := 0;

CURSOR cur_contenido IS
SELECT id_contenido, titulo, popularidad
FROM   CONTENIDO
ORDER  BY id_contenido
    FOR UPDATE OF popularidad NOWAIT;

v_rec t_contenido_rec;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Inicio: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

OPEN cur_contenido;
LOOP
FETCH cur_contenido INTO v_rec.id_contenido, v_rec.titulo, v_rec.popularidad_actual;
        EXIT WHEN cur_contenido%NOTFOUND;

        -- Total de reproducciones y vistas completas para este contenido
SELECT COUNT(*),
       SUM(CASE WHEN porcentaje_avance >= 90 THEN 1 ELSE 0 END)
INTO   v_total_reproducciones, v_vistas_completas
FROM   REPRODUCCIONES
WHERE  id_contenido = v_rec.id_contenido;

-- Promedio de estrellas (0 si no tiene calificaciones)
SELECT NVL(AVG(estrellas), 0)
INTO   v_promedio_estrellas
FROM   CALIFICACIONES
WHERE  id_contenido = v_rec.id_contenido;

-- Factor de calificacion
IF v_promedio_estrellas = 0 THEN
            v_factor_calificacion := 1;
ELSE
            v_factor_calificacion := v_promedio_estrellas / 5;
END IF;

        -- Popularidad nueva
        IF v_total_reproducciones = 0 THEN
            v_nueva_popularidad := 0;
ELSE
            v_nueva_popularidad := ROUND(
                (v_vistas_completas / v_total_reproducciones) * 100
                * v_factor_calificacion, 2
            );
END IF;

        -- UPDATE usando WHERE CURRENT OF (apunta a la fila bloqueada)
UPDATE CONTENIDO
SET    popularidad = v_nueva_popularidad
WHERE  CURRENT OF cur_contenido;

DBMS_OUTPUT.PUT_LINE(
            'ID: ' || LPAD(v_rec.id_contenido, 3) ||
            ' | Reprod: '    || LPAD(v_total_reproducciones, 3) ||
            ' | Completas: ' || LPAD(v_vistas_completas, 3) ||
            ' | Pop: '       || LPAD(v_nueva_popularidad, 6) ||
            ' | ' || SUBSTR(v_rec.titulo, 1, 35)
        );

        v_contenidos_actualizados := v_contenidos_actualizados + 1;
END LOOP;
CLOSE cur_contenido;

COMMIT;
DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    DBMS_OUTPUT.PUT_LINE('Contenidos actualizados: ' || v_contenidos_actualizados);
    DBMS_OUTPUT.PUT_LINE('Fin: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR NT2-2: ' || SQLERRM);
        RAISE;
END;
/

-- Verificacion: top 10 por popularidad actualizada
SELECT id_contenido, titulo, popularidad
FROM   CONTENIDO
ORDER  BY popularidad DESC
    FETCH  FIRST 10 ROWS ONLY;


-- =============================================================================
-- NT2-3: SP_REGISTRAR_USUARIO
-- Autor  : Cristhian Osorio
-- Tipo   : Stored Procedure con parametros IN/OUT
-- Tema   : Transacciones atomicas, excepciones personalizadas, RETURNING INTO
--
-- Registra un nuevo usuario en la plataforma de forma atomica:
-- valida email unico y plan existente, crea usuario + perfil + primer pago.
-- Si cualquier paso falla hace ROLLBACK completo.
--
-- Parametros de entrada:
--   p_nombre, p_apellido, p_email, p_contrasena_hash — datos del usuario
--   p_ciudad      — ciudad de residencia (NULL permitido)
--   p_id_plan     — plan elegido (1=Basico, 2=Estandar, 3=Premium)
--   p_metodo_pago — metodo del primer pago (default PSE)
--   p_id_referidor— id del usuario que lo refirio (NULL permitido)
-- Parametro de salida:
--   p_id_usuario  — id del usuario recien creado
--
-- Excepciones personalizadas:
--   EMAIL_DUPLICADO (-20011) — el email ya existe en USUARIOS
--   PLAN_NO_EXISTE  (-20012) — el id_plan no existe en PLANES
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-3: Creando SP_REGISTRAR_USUARIO
PROMPT ============================================================

CREATE OR REPLACE PROCEDURE SP_REGISTRAR_USUARIO (
    p_nombre           IN  VARCHAR2,
    p_apellido         IN  VARCHAR2,
    p_email            IN  VARCHAR2,
    p_contrasena_hash  IN  VARCHAR2,
    p_ciudad           IN  VARCHAR2 DEFAULT NULL,
    p_id_plan          IN  NUMBER,
    p_metodo_pago      IN  VARCHAR2 DEFAULT 'PSE',
    p_id_referidor     IN  NUMBER   DEFAULT NULL,
    p_id_usuario       OUT NUMBER
)
IS
    EMAIL_DUPLICADO EXCEPTION;
    PLAN_NO_EXISTE  EXCEPTION;
    PRAGMA EXCEPTION_INIT(EMAIL_DUPLICADO, -20011);
    PRAGMA EXCEPTION_INIT(PLAN_NO_EXISTE,  -20012);

    v_plan        PLANES%ROWTYPE;
    v_count_email NUMBER(3) := 0;
    v_id_nuevo    NUMBER(8);

BEGIN
    -- PASO 1: Validar plan
BEGIN
SELECT * INTO v_plan FROM PLANES WHERE id_plan = p_id_plan;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012,
                'PLAN_NO_EXISTE: No se encontro el plan con id = ' || p_id_plan ||
                '. Planes validos: 1 (Basico), 2 (Estandar), 3 (Premium).');
END;

    -- PASO 2: Validar email unico
SELECT COUNT(*) INTO v_count_email
FROM   USUARIOS WHERE email = LOWER(TRIM(p_email));

IF v_count_email > 0 THEN
        RAISE_APPLICATION_ERROR(-20011,
            'EMAIL_DUPLICADO: El email "' || LOWER(TRIM(p_email)) ||
            '" ya esta registrado. Use otro correo o recupere su contrasena.');
END IF;

    -- PASO 3: Crear usuario
INSERT INTO USUARIOS (
    nombre, apellido, email, contrasena_hash,
    fecha_registro, fecha_vencimiento,
    estado_cuenta, es_moderador,
    ciudad_residencia, id_plan, id_referidor
) VALUES (
             TRIM(p_nombre), TRIM(p_apellido),
             LOWER(TRIM(p_email)), p_contrasena_hash,
             SYSDATE, SYSDATE + 30,
             'ACTIVO', 'N',
             TRIM(p_ciudad), p_id_plan, p_id_referidor
         ) RETURNING id_usuario INTO v_id_nuevo;

-- PASO 4: Crear perfil predeterminado
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario)
VALUES ('Principal', 'ADULTO', v_id_nuevo);

-- PASO 5: Registrar primer pago (EXITOSO activa TRG_ACTIVAR_CUENTA)
INSERT INTO PAGOS (fecha_pago, monto, metodo_pago, estado_pago, descuento_aplicado, id_usuario)
VALUES (SYSDATE, v_plan.precio_mensual, p_metodo_pago, 'EXITOSO', 0, v_id_nuevo);

COMMIT;

p_id_usuario := v_id_nuevo;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  SP_REGISTRAR_USUARIO — Registro exitoso');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('  ID usuario  : ' || v_id_nuevo);
    DBMS_OUTPUT.PUT_LINE('  Nombre      : ' || TRIM(p_nombre) || ' ' || TRIM(p_apellido));
    DBMS_OUTPUT.PUT_LINE('  Email       : ' || LOWER(TRIM(p_email)));
    DBMS_OUTPUT.PUT_LINE('  Plan        : ' || v_plan.nombre || ' ($' || v_plan.precio_mensual || '/mes)');
    DBMS_OUTPUT.PUT_LINE('  Vencimiento : ' || TO_CHAR(SYSDATE + 30, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('  Pago        : $' || v_plan.precio_mensual || ' via ' || p_metodo_pago || ' — EXITOSO');
    DBMS_OUTPUT.PUT_LINE('  Referidor   : ' || NVL(TO_CHAR(p_id_referidor), 'ninguno'));
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

EXCEPTION
    WHEN EMAIL_DUPLICADO OR PLAN_NO_EXISTE THEN
        ROLLBACK; RAISE;
WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'SP_REGISTRAR_USUARIO — Error: ' || SQLERRM);
END SP_REGISTRAR_USUARIO;
/

PROMPT NT2-3: SP_REGISTRAR_USUARIO creado. Ejecutando pruebas...

-- Prueba 1: Registro exitoso — plan Basico via PSE
DECLARE v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO('Laura','Montoya','laura.montoya.nt2@test.com',
        'hash_t1','Manizales',1,'PSE',NULL,v_id);
    DBMS_OUTPUT.PUT_LINE('P1 OK: id=' || v_id);
END;
/
DECLARE v_id NUMBER;
BEGIN
SELECT id_usuario INTO v_id FROM USUARIOS WHERE email='laura.montoya.nt2@test.com';
DELETE FROM PAGOS    WHERE id_usuario = v_id;
DELETE FROM PERFILES WHERE id_usuario = v_id;
DELETE FROM USUARIOS WHERE id_usuario = v_id;
COMMIT;
DBMS_OUTPUT.PUT_LINE('P1 revertida.');
END;
/

-- Prueba 2: EMAIL_DUPLICADO
DECLARE v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO('Test','Dup','sofia.perea@quindioflix.com','h','Armenia',1,'PSE',NULL,v_id);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('P2 OK — EMAIL_DUPLICADO: ' || SQLERRM);
END;
/

-- Prueba 3: PLAN_NO_EXISTE
DECLARE v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO('Test','Plan','plan.nt2@test.com','h','Pereira',99,'PSE',NULL,v_id);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('P3 OK — PLAN_NO_EXISTE: ' || SQLERRM);
END;
/


-- =============================================================================
-- NT2-4: SP_CAMBIAR_PLAN
-- Autor  : Daniel Narvaez
-- Tipo   : Stored Procedure
-- Tema   : Validaciones encadenadas, excepciones personalizadas multiples
--
-- Cambia el plan de suscripcion de un usuario previa validacion:
-- el nuevo plan debe soportar la cantidad de perfiles que el usuario ya tiene.
--
-- Excepciones personalizadas:
--   PERFILES_EXCEDIDOS (-20001) — perfiles actuales > max del nuevo plan
--   USUARIO_NO_EXISTE  (-20002) — id_usuario no existe
--   PLAN_NO_EXISTE     (-20003) — id_plan_nuevo no existe
--   MISMO_PLAN         (-20004) — usuario ya tiene ese plan
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-4: Creando SP_CAMBIAR_PLAN
PROMPT ============================================================

CREATE OR REPLACE PROCEDURE SP_CAMBIAR_PLAN (
    p_id_usuario    IN NUMBER,
    p_id_plan_nuevo IN NUMBER
)
IS
    PERFILES_EXCEDIDOS EXCEPTION;
    USUARIO_NO_EXISTE  EXCEPTION;
    PLAN_NO_EXISTE     EXCEPTION;
    MISMO_PLAN         EXCEPTION;
    PRAGMA EXCEPTION_INIT(PERFILES_EXCEDIDOS, -20001);
    PRAGMA EXCEPTION_INIT(USUARIO_NO_EXISTE,  -20002);
    PRAGMA EXCEPTION_INIT(PLAN_NO_EXISTE,     -20003);
    PRAGMA EXCEPTION_INIT(MISMO_PLAN,         -20004);

    v_usuario        USUARIOS%ROWTYPE;
    v_plan_actual    PLANES%ROWTYPE;
    v_plan_nuevo     PLANES%ROWTYPE;
    v_total_perfiles NUMBER(3) := 0;

BEGIN
    -- PASO 1: Validar usuario
BEGIN
SELECT * INTO v_usuario FROM USUARIOS WHERE id_usuario = p_id_usuario;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002,
                'USUARIO_NO_EXISTE: No se encontro el usuario con id = ' || p_id_usuario);
END;

    -- PASO 2: Validar nuevo plan
BEGIN
SELECT * INTO v_plan_nuevo FROM PLANES WHERE id_plan = p_id_plan_nuevo;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'PLAN_NO_EXISTE: No se encontro el plan con id = ' || p_id_plan_nuevo);
END;

    -- PASO 3: Plan actual para el resumen
SELECT * INTO v_plan_actual FROM PLANES WHERE id_plan = v_usuario.id_plan;

-- PASO 4: Mismo plan
IF v_usuario.id_plan = p_id_plan_nuevo THEN
        RAISE_APPLICATION_ERROR(-20004,
            'MISMO_PLAN: El usuario ya tiene el plan "' || v_plan_nuevo.nombre || '".');
END IF;

    -- PASO 5: Contar perfiles
SELECT COUNT(*) INTO v_total_perfiles FROM PERFILES WHERE id_usuario = p_id_usuario;

-- PASO 6: Validar limite de perfiles del nuevo plan
IF v_total_perfiles > v_plan_nuevo.max_perfiles THEN
        RAISE_APPLICATION_ERROR(-20001,
            'PERFILES_EXCEDIDOS: El usuario tiene ' || v_total_perfiles ||
            ' perfil(es) pero el plan "' || v_plan_nuevo.nombre ||
            '" permite maximo ' || v_plan_nuevo.max_perfiles || '.');
END IF;

    -- PASO 7: Aplicar cambio
UPDATE USUARIOS SET id_plan = p_id_plan_nuevo WHERE id_usuario = p_id_usuario;
COMMIT;

DBMS_OUTPUT.PUT_LINE('SP_CAMBIAR_PLAN OK: ' || v_usuario.nombre || ' ' || v_usuario.apellido ||
        ' | ' || v_plan_actual.nombre || ' -> ' || v_plan_nuevo.nombre);

EXCEPTION
    WHEN PERFILES_EXCEDIDOS OR USUARIO_NO_EXISTE OR PLAN_NO_EXISTE OR MISMO_PLAN THEN
        ROLLBACK; RAISE;
WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'SP_CAMBIAR_PLAN — Error: ' || SQLERRM);
END SP_CAMBIAR_PLAN;
/

PROMPT NT2-4: SP_CAMBIAR_PLAN creado. Ejecutando pruebas...

-- Prueba 1: Upgrade exitoso Basico -> Estandar (usuario 3, 1 perfil)
BEGIN SP_CAMBIAR_PLAN(3, 2); END;
/
UPDATE USUARIOS SET id_plan = 1 WHERE id_usuario = 3; COMMIT;

-- Prueba 2: PERFILES_EXCEDIDOS
BEGIN SP_CAMBIAR_PLAN(15, 1);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P2 OK: ' || SQLERRM); END;
/

-- Prueba 3: USUARIO_NO_EXISTE
BEGIN SP_CAMBIAR_PLAN(99999, 2);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P3 OK: ' || SQLERRM); END;
/

-- Prueba 4: MISMO_PLAN
BEGIN SP_CAMBIAR_PLAN(3, 1);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P4 OK: ' || SQLERRM); END;
/


-- =============================================================================
-- NT2-5: SP_REPORTE_CONSUMO
-- Autor  : Diego Garcia
-- Tipo   : Stored Procedure con cursores anidados
-- Tema   : Cursores parametrizados, FETCH explicito anidado, INTERVAL
--
-- Genera un reporte de consumo por perfil y categoria para un usuario
-- en un rango de fechas. Usa cursor parametrizado de categorias anidado
-- dentro del cursor de perfiles.
--
-- Parametros: p_id_usuario, p_fecha_inicio, p_fecha_fin
-- Minutos calculados con EXTRACT sobre INTERVAL DAY TO SECOND
-- (evita ORA-00932 de resta directa entre TIMESTAMP).
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-5: Creando SP_REPORTE_CONSUMO
PROMPT ============================================================

CREATE OR REPLACE PROCEDURE SP_REPORTE_CONSUMO (
    p_id_usuario   IN NUMBER,
    p_fecha_inicio IN DATE,
    p_fecha_fin    IN DATE
) AS
    v_nombre_usuario        VARCHAR2(160);
    v_email_usuario         VARCHAR2(120);
    v_plan_usuario          VARCHAR2(30);
    v_total_perfiles        NUMBER := 0;
    v_total_reprod_usuario  NUMBER := 0;
    v_total_minutos_usuario NUMBER := 0;
    v_total_reprod_perfil   NUMBER := 0;
    v_total_minutos_perfil  NUMBER := 0;
    v_categoria             VARCHAR2(50);
    v_cantidad_reprod       NUMBER := 0;
    v_reprod_completas      NUMBER := 0;
    v_minutos_categoria     NUMBER := 0;
    v_promedio_avance       NUMBER := 0;

CURSOR cur_perfiles IS
SELECT id_perfil, nombre, tipo_perfil FROM PERFILES
WHERE  id_usuario = p_id_usuario ORDER BY id_perfil;

CURSOR cur_categorias (p_id_perfil NUMBER) IS
SELECT
    cat.nombre,
    COUNT(r.id_reproduccion),
    SUM(CASE WHEN r.porcentaje_avance >= 90 THEN 1 ELSE 0 END),
    ROUND(SUM(
                  EXTRACT(DAY    FROM (NVL(r.fecha_hora_fin,SYSTIMESTAMP)-r.fecha_hora_inicio))*1440 +
                  EXTRACT(HOUR   FROM (NVL(r.fecha_hora_fin,SYSTIMESTAMP)-r.fecha_hora_inicio))*60   +
                  EXTRACT(MINUTE FROM (NVL(r.fecha_hora_fin,SYSTIMESTAMP)-r.fecha_hora_inicio))      +
                  EXTRACT(SECOND FROM (NVL(r.fecha_hora_fin,SYSTIMESTAMP)-r.fecha_hora_inicio))/60
          ), 1),
    ROUND(AVG(r.porcentaje_avance), 1)
FROM  REPRODUCCIONES r
          JOIN  CONTENIDO  c   ON c.id_contenido  = r.id_contenido
          JOIN  CATEGORIAS cat ON cat.id_categoria = c.id_categoria
WHERE r.id_perfil = p_id_perfil
  AND CAST(r.fecha_hora_inicio AS DATE) >= p_fecha_inicio
  AND CAST(r.fecha_hora_inicio AS DATE) <= p_fecha_fin
GROUP BY cat.nombre ORDER BY 4 DESC;

BEGIN
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Rango invalido: fecha_inicio > fecha_fin.');
END IF;

BEGIN
SELECT u.nombre||' '||u.apellido, u.email, pl.nombre
INTO   v_nombre_usuario, v_email_usuario, v_plan_usuario
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan=u.id_plan
WHERE  u.id_usuario = p_id_usuario;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Usuario ID '||p_id_usuario||' no existe.');
END;

SELECT COUNT(*) INTO v_total_perfiles FROM PERFILES WHERE id_usuario = p_id_usuario;
IF v_total_perfiles = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'El usuario '||v_nombre_usuario||' no tiene perfiles.');
END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('         REPORTE DE CONSUMO - QUINDIOFLIX');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('Usuario : '||v_nombre_usuario);
    DBMS_OUTPUT.PUT_LINE('Plan    : '||v_plan_usuario);
    DBMS_OUTPUT.PUT_LINE('Periodo : '||TO_CHAR(p_fecha_inicio,'DD/MM/YYYY')||
        ' al '||TO_CHAR(p_fecha_fin,'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('=======================================================');

FOR v_perfil IN cur_perfiles LOOP
        v_total_reprod_perfil  := 0;
        v_total_minutos_perfil := 0;

        DBMS_OUTPUT.PUT_LINE('  Perfil: '||v_perfil.nombre||' ['||v_perfil.tipo_perfil||']');
        DBMS_OUTPUT.PUT_LINE('  '||RPAD('-',65,'-'));

OPEN cur_categorias(v_perfil.id_perfil);
LOOP
FETCH cur_categorias INTO
                v_categoria, v_cantidad_reprod, v_reprod_completas,
                v_minutos_categoria, v_promedio_avance;
            EXIT WHEN cur_categorias%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE('  '||
                RPAD(v_categoria,20)||RPAD(v_cantidad_reprod,12)||
                RPAD(v_reprod_completas,10)||NVL(TO_CHAR(v_minutos_categoria),'0')||' min');

            v_total_reprod_perfil  := v_total_reprod_perfil  + v_cantidad_reprod;
            v_total_minutos_perfil := v_total_minutos_perfil + NVL(v_minutos_categoria,0);
END LOOP;
CLOSE cur_categorias;

DBMS_OUTPUT.PUT_LINE('  Subtotal: '||v_total_reprod_perfil||
            ' reprod | '||ROUND(v_total_minutos_perfil,1)||' min');

        v_total_reprod_usuario  := v_total_reprod_usuario  + v_total_reprod_perfil;
        v_total_minutos_usuario := v_total_minutos_usuario + v_total_minutos_perfil;
END LOOP;

    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('TOTAL: '||v_total_reprod_usuario||
        ' reproducciones | '||ROUND(v_total_minutos_usuario,1)||' min');
    DBMS_OUTPUT.PUT_LINE('=======================================================');

EXCEPTION
    WHEN OTHERS THEN
        IF cur_categorias%ISOPEN THEN CLOSE cur_categorias; END IF;
        DBMS_OUTPUT.PUT_LINE('ERROR NT2-5: ' || SQLERRM);
        RAISE;
END SP_REPORTE_CONSUMO;
/

PROMPT NT2-5: SP_REPORTE_CONSUMO creado. Ejecutando pruebas...

-- Prueba 1: usuario 1 en 2024
BEGIN SP_REPORTE_CONSUMO(1, DATE '2024-01-01', DATE '2024-12-31'); END;
/
-- Prueba 2: rango invalido
BEGIN SP_REPORTE_CONSUMO(1, DATE '2024-12-31', DATE '2024-01-01');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P2 OK: ' || SQLERRM); END;
/
-- Prueba 3: usuario inexistente
BEGIN SP_REPORTE_CONSUMO(9999, DATE '2024-01-01', DATE '2024-12-31');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P3 OK: ' || SQLERRM); END;
/


-- =============================================================================
-- NT2-6: FN_CALCULAR_MONTO
-- Autor  : Cristhian Osorio
-- Tipo   : Funcion almacenada
-- Tema   : Funciones con logica de negocio, descuentos por antiguedad
--
-- Recibe el id de un usuario y retorna el monto a cobrar para el
-- proximo mes aplicando descuentos por antiguedad:
--   > 24 meses  : 15% descuento
--   > 12 meses  : 10% descuento
--   <= 12 meses :  0% descuento
--
-- Excepcion: USUARIO_NO_EXISTE (-20021)
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-6: Creando FN_CALCULAR_MONTO
PROMPT ============================================================

CREATE OR REPLACE FUNCTION FN_CALCULAR_MONTO (
    p_id_usuario IN NUMBER
)
RETURN NUMBER
IS
    USUARIO_NO_EXISTE EXCEPTION;
    PRAGMA EXCEPTION_INIT(USUARIO_NO_EXISTE, -20021);

    v_usuario   USUARIOS%ROWTYPE;
    v_plan      PLANES%ROWTYPE;
    v_meses     NUMBER(6,2) := 0;
    v_descuento NUMBER(5,2) := 0;
    v_monto     NUMBER(10,2);

BEGIN
BEGIN
SELECT * INTO v_usuario FROM USUARIOS WHERE id_usuario = p_id_usuario;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20021,
                'USUARIO_NO_EXISTE: No se encontro el usuario con id = ' || p_id_usuario);
END;

SELECT * INTO v_plan FROM PLANES WHERE id_plan = v_usuario.id_plan;

v_meses := MONTHS_BETWEEN(SYSDATE, v_usuario.fecha_registro);

    IF    v_meses > 24 THEN v_descuento := 15;
    ELSIF v_meses > 12 THEN v_descuento := 10;
ELSE                    v_descuento := 0;
END IF;

    v_monto := ROUND(v_plan.precio_mensual * (1 - v_descuento / 100), 2);

    DBMS_OUTPUT.PUT_LINE('FN_CALCULAR_MONTO | '||v_usuario.nombre||' '||v_usuario.apellido||
        ' | '||ROUND(v_meses,1)||' meses | '||v_descuento||'% desc | $'||v_monto);

RETURN v_monto;

EXCEPTION
    WHEN USUARIO_NO_EXISTE THEN RAISE;
WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'FN_CALCULAR_MONTO — Error: ' || SQLERRM);
END FN_CALCULAR_MONTO;
/

PROMPT NT2-6: FN_CALCULAR_MONTO creada. Ejecutando pruebas...

-- Prueba 1: >24 meses (Sofia Perea, Basico $14900 - 15% = $12665)
DECLARE v_m NUMBER; v_id NUMBER;
BEGIN
SELECT id_usuario INTO v_id FROM USUARIOS WHERE email='sofia.perea@quindioflix.com';
v_m := FN_CALCULAR_MONTO(v_id);
    DBMS_OUTPUT.PUT_LINE('P1 esperado $12,665.00 — resultado: $'||v_m);
END;
/

-- Prueba 2: usuario inexistente
DECLARE v_m NUMBER;
BEGIN
    v_m := FN_CALCULAR_MONTO(99999);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P2 OK: '||SQLERRM);
END;
/

-- Verificacion: todos los usuarios activos con monto calculado
SELECT u.nombre||' '||u.apellido AS usuario, pl.nombre AS plan,
       ROUND(MONTHS_BETWEEN(SYSDATE,u.fecha_registro),1) AS meses,
       FN_CALCULAR_MONTO(u.id_usuario) AS monto_proximo
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan=u.id_plan
WHERE  u.estado_cuenta='ACTIVO'
ORDER  BY meses DESC FETCH FIRST 10 ROWS ONLY;


-- =============================================================================
-- NT2-7: FN_CONTENIDO_RECOMENDADO
-- Autor  : Diego Garcia
-- Tipo   : Funcion almacenada
-- Tema   : Logica de recomendacion, subconsultas complejas, fallback
--
-- Recibe el id de un perfil y retorna el titulo del contenido mas afin
-- basado en los generos mas reproducidos ponderados por porcentaje_avance.
-- Si no hay historial retorna el mas popular como fallback.
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-7: Creando FN_CONTENIDO_RECOMENDADO
PROMPT ============================================================

CREATE OR REPLACE FUNCTION FN_CONTENIDO_RECOMENDADO (
    p_id_perfil IN NUMBER
) RETURN VARCHAR2
AS
    v_titulo               VARCHAR2(200);
    v_total_reproducciones NUMBER := 0;
    v_perfil_existe        NUMBER := 0;

BEGIN
SELECT COUNT(*) INTO v_perfil_existe FROM PERFILES WHERE id_perfil = p_id_perfil;
IF v_perfil_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Perfil ID '||p_id_perfil||' no existe.');
END IF;

SELECT COUNT(*) INTO v_total_reproducciones
FROM   REPRODUCCIONES WHERE id_perfil = p_id_perfil;

-- Sin historial: retornar el mas popular
IF v_total_reproducciones = 0 THEN
SELECT titulo INTO v_titulo FROM (
                                     SELECT titulo FROM CONTENIDO WHERE estado='ACTIVO' ORDER BY popularidad DESC
                                 ) WHERE ROWNUM=1;
RETURN '[SIN HISTORIAL] '||v_titulo;
END IF;

    -- Con historial: score por afinidad de generos
BEGIN
SELECT titulo INTO v_titulo FROM (
                                     SELECT c.titulo,
                                            SUM(gp.peso_genero)*(c.popularidad/100) AS score
                                     FROM   CONTENIDO c
                                                JOIN   CONTENIDO_GENEROS cg ON cg.id_contenido=c.id_contenido
                                                JOIN   (
                                         SELECT cg2.id_genero, AVG(r.porcentaje_avance) AS peso_genero
                                         FROM   REPRODUCCIONES r
                                                    JOIN   CONTENIDO c2 ON c2.id_contenido=r.id_contenido
                                                    JOIN   CONTENIDO_GENEROS cg2 ON cg2.id_contenido=c2.id_contenido
                                         WHERE  r.id_perfil=p_id_perfil
                                         GROUP  BY cg2.id_genero
                                     ) gp ON gp.id_genero=cg.id_genero
                                     WHERE  c.estado='ACTIVO'
                                       AND  c.id_contenido NOT IN (
                                         SELECT DISTINCT id_contenido FROM REPRODUCCIONES WHERE id_perfil=p_id_perfil
                                     )
                                     GROUP  BY c.id_contenido, c.titulo, c.popularidad
                                     ORDER  BY score DESC
                                 ) WHERE ROWNUM=1;
EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Ya vio todo: recomendar el mas disfrutado
SELECT c.titulo INTO v_titulo
FROM   CONTENIDO c
WHERE  c.id_contenido = (
    SELECT id_contenido FROM REPRODUCCIONES WHERE id_perfil=p_id_perfil
    GROUP  BY id_contenido ORDER BY AVG(porcentaje_avance) DESC
        FETCH  FIRST 1 ROWS ONLY
);
RETURN '[YA VISTO TODO] '||v_titulo;
END;

RETURN v_titulo;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Error en FN_CONTENIDO_RECOMENDADO para perfil '||p_id_perfil||': '||SQLERRM);
END FN_CONTENIDO_RECOMENDADO;
/

PROMPT NT2-7: FN_CONTENIDO_RECOMENDADO creada. Ejecutando pruebas...

-- Top 10 perfiles con recomendacion personalizada
SELECT p.id_perfil, p.nombre AS perfil,
       u.nombre||' '||u.apellido AS usuario,
       FN_CONTENIDO_RECOMENDADO(p.id_perfil) AS recomendacion
FROM   PERFILES p JOIN USUARIOS u ON u.id_usuario=p.id_usuario
WHERE  p.id_perfil <= 10 ORDER BY p.id_perfil;

-- Prueba perfil inexistente
BEGIN
    DBMS_OUTPUT.PUT_LINE(FN_CONTENIDO_RECOMENDADO(9999));
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P-inexistente OK: '||SQLERRM);
END;
/


-- =============================================================================
-- NT2-10: TRG_VALID_CUENTA
-- Autor  : Daniel Narvaez
-- Tipo   : BEFORE INSERT FOR EACH ROW sobre REPRODUCCIONES
-- Tema   : Trigger de validacion, navegacion de tablas, RAISE_APPLICATION_ERROR
--
-- Verifica que el usuario propietario del perfil tenga estado_cuenta = 'ACTIVO'
-- antes de permitir insertar una nueva reproduccion. Si la cuenta esta
-- INACTIVA o SUSPENDIDA rechaza el INSERT con mensaje descriptivo.
--
-- Navegacion: REPRODUCCIONES.id_perfil -> PERFILES.id_usuario -> USUARIOS.estado_cuenta
-- Codigos: -20010 (INACTIVA), -20011 (SUSPENDIDA), -20012 (perfil no encontrado)
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-10: Creando TRG_VALID_CUENTA
PROMPT ============================================================

CREATE OR REPLACE TRIGGER TRG_VALID_CUENTA
BEFORE INSERT ON REPRODUCCIONES
FOR EACH ROW
DECLARE
v_estado_cuenta  USUARIOS.estado_cuenta%TYPE;
    v_nombre_usuario VARCHAR2(160);
    v_id_usuario     USUARIOS.id_usuario%TYPE;
BEGIN
SELECT u.id_usuario, u.nombre||' '||u.apellido, u.estado_cuenta
INTO   v_id_usuario, v_nombre_usuario, v_estado_cuenta
FROM   PERFILES pe JOIN USUARIOS u ON u.id_usuario=pe.id_usuario
WHERE  pe.id_perfil = :NEW.id_perfil;

IF v_estado_cuenta = 'INACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20010,
            'TRG_VALID_CUENTA: Cuenta de "'||v_nombre_usuario||'" INACTIVA. Realice el pago.');
    ELSIF v_estado_cuenta = 'SUSPENDIDO' THEN
        RAISE_APPLICATION_ERROR(-20011,
            'TRG_VALID_CUENTA: Cuenta de "'||v_nombre_usuario||'" SUSPENDIDA. Contacte soporte.');
END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20012,
            'TRG_VALID_CUENTA: Perfil id='||:NEW.id_perfil||' no encontrado.');
END TRG_VALID_CUENTA;
/

PROMPT NT2-10: TRG_VALID_CUENTA creado. Ejecutando pruebas...

-- Prueba 1: usuario ACTIVO — debe insertar (se revierte)
BEGIN
    INSERT INTO REPRODUCCIONES (fecha_hora_inicio,fecha_hora_fin,dispositivo,
        porcentaje_avance,id_perfil,id_contenido,id_episodio)
SELECT TIMESTAMP '2026-05-01 20:00:00', TIMESTAMP '2026-05-01 21:30:00',
       'TV', 100, pe.id_perfil, 1, NULL
FROM   PERFILES pe JOIN USUARIOS u ON u.id_usuario=pe.id_usuario
WHERE  u.id_usuario=3 AND ROWNUM=1;
DBMS_OUTPUT.PUT_LINE('P1 OK: INSERT permitido para usuario ACTIVO.');
ROLLBACK;
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('P1 ERROR: '||SQLERRM);
END;
/

-- Prueba 2: usuario INACTIVO (id=14 Cristian Salazar)
BEGIN
INSERT INTO REPRODUCCIONES (fecha_hora_inicio,dispositivo,porcentaje_avance,
                            id_perfil,id_contenido,id_episodio)
SELECT TIMESTAMP '2026-05-01 20:00:00','CELULAR',0,pe.id_perfil,1,NULL
FROM   PERFILES pe JOIN USUARIOS u ON u.id_usuario=pe.id_usuario
WHERE  u.id_usuario=14 AND ROWNUM=1;
DBMS_OUTPUT.PUT_LINE('P2 ERROR: debia ser bloqueado.');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P2 OK — bloqueado: '||SQLERRM);
END;
/

-- Prueba 3: usuario SUSPENDIDO (id=30 Samuel Ocampo)
BEGIN
INSERT INTO REPRODUCCIONES (fecha_hora_inicio,dispositivo,porcentaje_avance,
                            id_perfil,id_contenido,id_episodio)
SELECT TIMESTAMP '2026-05-01 20:00:00','TABLET',0,pe.id_perfil,1,NULL
FROM   PERFILES pe JOIN USUARIOS u ON u.id_usuario=pe.id_usuario
WHERE  u.id_usuario=30 AND ROWNUM=1;
DBMS_OUTPUT.PUT_LINE('P3 ERROR: debia ser bloqueado.');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('P3 OK — bloqueado: '||SQLERRM);
END;
/


-- =============================================================================
-- NT2-11: TRG_MAX_PERFILES
-- Autor  : Diego Garcia
-- Tipo   : BEFORE INSERT FOR EACH ROW sobre PERFILES
-- Tema   : Trigger de validacion de negocio, limites por plan
--
-- Verifica que el usuario no supere el maximo de perfiles permitido
-- por su plan antes de crear uno nuevo:
--   Basico=2, Estandar=3, Premium=5
--
-- Codigos: -20021 (limite excedido), -20022 (usuario no encontrado)
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-11: Creando TRG_MAX_PERFILES
PROMPT ============================================================

CREATE OR REPLACE TRIGGER TRG_MAX_PERFILES
BEFORE INSERT ON PERFILES
FOR EACH ROW
DECLARE
v_max_perfiles      NUMBER(1);
    v_perfiles_actuales NUMBER(3);
    v_nombre_plan       VARCHAR2(30);
BEGIN
SELECT pl.max_perfiles, pl.nombre
INTO   v_max_perfiles, v_nombre_plan
FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan=u.id_plan
WHERE  u.id_usuario = :NEW.id_usuario;

SELECT COUNT(*) INTO v_perfiles_actuales
FROM   PERFILES WHERE id_usuario = :NEW.id_usuario;

IF v_perfiles_actuales >= v_max_perfiles THEN
        RAISE_APPLICATION_ERROR(-20021,
            'TRG_MAX_PERFILES: Usuario '||:NEW.id_usuario||' ya tiene '||
            v_perfiles_actuales||' perfiles. Plan "'||v_nombre_plan||
            '" permite maximo '||v_max_perfiles||'.');
END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20022,
            'TRG_MAX_PERFILES: No se encontro el usuario ID '||:NEW.id_usuario);
END TRG_MAX_PERFILES;
/

PROMPT NT2-11: TRG_MAX_PERFILES creado. Ejecutando pruebas...

-- Prueba 1: usuario que ya tiene el maximo (usuario 1, plan Basico max=2)
BEGIN
    INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario) VALUES ('Extra','ADULTO',1);
    DBMS_OUTPUT.PUT_LINE('P1 ERROR: debia ser bloqueado.');
ROLLBACK;
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('P1 OK — bloqueado: '||SQLERRM);
END;
/

-- Prueba 2: usuario Premium con espacio disponible
DECLARE v_id NUMBER;
BEGIN
SELECT id_usuario INTO v_id FROM (
                                     SELECT u.id_usuario, COUNT(p.id_perfil) ct, pl.max_perfiles mx
                                     FROM   USUARIOS u JOIN PLANES pl ON pl.id_plan=u.id_plan
                                                       LEFT   JOIN PERFILES p ON p.id_usuario=u.id_usuario
                                     WHERE  pl.nombre='Premium' GROUP BY u.id_usuario,pl.max_perfiles
                                     HAVING COUNT(p.id_perfil) < pl.max_perfiles
                                 ) WHERE ROWNUM=1;
INSERT INTO PERFILES (nombre, tipo_perfil, id_usuario) VALUES ('Test Premium','ADULTO',v_id);
DBMS_OUTPUT.PUT_LINE('P2 OK: perfil insertado para usuario Premium '||v_id);
ROLLBACK;
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('P2 ERROR: '||SQLERRM);
END;
/


-- =============================================================================
-- NT2-12: TRG_VALID_CALIFICACION
-- Autor  : Cristhian Osorio
-- Tipo   : BEFORE INSERT FOR EACH ROW sobre CALIFICACIONES
-- Tema   : Trigger con validacion de precondicion de negocio
--
-- Verifica que el perfil haya visto al menos el 50% del contenido
-- que intenta calificar. Si no hay reproducciones o el avance es
-- insuficiente rechaza el INSERT con -20031.
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-12: Creando TRG_VALID_CALIFICACION
PROMPT ============================================================

CREATE OR REPLACE TRIGGER TRG_VALID_CALIFICACION
BEFORE INSERT ON CALIFICACIONES
FOR EACH ROW
DECLARE
v_max_avance NUMBER(5,2);
BEGIN
SELECT MAX(porcentaje_avance) INTO v_max_avance
FROM   REPRODUCCIONES
WHERE  id_perfil    = :NEW.id_perfil
  AND  id_contenido = :NEW.id_contenido;

IF v_max_avance IS NULL THEN
        RAISE_APPLICATION_ERROR(-20031,
            'TRG_VALID_CALIFICACION: Perfil '||:NEW.id_perfil||
            ' nunca ha reproducido el contenido '||:NEW.id_contenido||
            '. Debe ver al menos el 50%.');
END IF;

    IF v_max_avance < 50 THEN
        RAISE_APPLICATION_ERROR(-20031,
            'TRG_VALID_CALIFICACION: Perfil '||:NEW.id_perfil||
            ' solo ha visto el '||v_max_avance||'% del contenido '||
            :NEW.id_contenido||'. Se requiere minimo 50%.');
END IF;
END TRG_VALID_CALIFICACION;
/

PROMPT NT2-12: TRG_VALID_CALIFICACION creado. Ejecutando pruebas...

-- Prueba 1: par valido con avance >= 50%
DECLARE
    v_id_perfil NUMBER; v_id_contenido NUMBER; v_avance NUMBER;
BEGIN
SELECT id_perfil, id_contenido, max_avance INTO v_id_perfil, v_id_contenido, v_avance
FROM (
         SELECT r.id_perfil, r.id_contenido, MAX(r.porcentaje_avance) max_avance
         FROM   REPRODUCCIONES r
         WHERE  NOT EXISTS (SELECT 1 FROM CALIFICACIONES c
                            WHERE c.id_perfil=r.id_perfil AND c.id_contenido=r.id_contenido)
         GROUP  BY r.id_perfil, r.id_contenido HAVING MAX(r.porcentaje_avance)>=50
         ORDER  BY MAX(r.porcentaje_avance) DESC
     ) WHERE ROWNUM=1;

INSERT INTO CALIFICACIONES (estrellas,resena,id_perfil,id_contenido)
VALUES (5,'Prueba NT2-12',v_id_perfil,v_id_contenido);
DBMS_OUTPUT.PUT_LINE('P1 OK: INSERT permitido (avance='||v_avance||'%).');
ROLLBACK;
EXCEPTION
    WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('P1 AVISO: no hay pares sin calificar con avance>=50%.');
WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('P1 ERROR: '||SQLERRM);
END;
/

-- Prueba 2: sin ninguna reproduccion — debe ser rechazado
DECLARE v_id_perfil NUMBER; v_id_contenido NUMBER;
BEGIN
SELECT p.id_perfil, c.id_contenido INTO v_id_perfil, v_id_contenido
FROM   PERFILES p CROSS JOIN CONTENIDO c
WHERE  NOT EXISTS (SELECT 1 FROM REPRODUCCIONES r
                   WHERE r.id_perfil=p.id_perfil AND r.id_contenido=c.id_contenido)
  AND  NOT EXISTS (SELECT 1 FROM CALIFICACIONES ca
                   WHERE ca.id_perfil=p.id_perfil AND ca.id_contenido=c.id_contenido)
  AND  ROWNUM=1;

INSERT INTO CALIFICACIONES (estrellas,id_perfil,id_contenido) VALUES(4,v_id_perfil,v_id_contenido);
DBMS_OUTPUT.PUT_LINE('P2 ERROR: debia ser bloqueado.');
ROLLBACK;
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('P2 OK — bloqueado: '||SQLERRM);
END;
/


-- =============================================================================
-- NT2-13: TRG_ACTIVAR_CUENTA
-- Autor  : Equipo QuindioFlix
-- Tipo   : AFTER INSERT FOR EACH ROW sobre PAGOS
-- Tema   : Trigger de actualizacion reactiva, integracion con SP
--
-- Cuando se inserta un pago con estado_pago = 'EXITOSO', activa
-- automaticamente el estado_cuenta del usuario ('ACTIVO') y renueva
-- su fecha_vencimiento = fecha_pago + 30 dias.
--
-- Nota sobre fecha_ultimo_pago: la columna no existe en el DDL.
-- fecha_vencimiento cumple el mismo rol semantico en este modelo.
--
-- Nota sobre nivel de disparo: se usa FOR EACH ROW en lugar de nivel
-- de sentencia porque :NEW solo esta disponible a nivel de fila.
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT NT2-13: Creando TRG_ACTIVAR_CUENTA
PROMPT ============================================================

CREATE OR REPLACE TRIGGER TRG_ACTIVAR_CUENTA
AFTER INSERT ON PAGOS
FOR EACH ROW
BEGIN
    IF :NEW.estado_pago = 'EXITOSO' THEN
UPDATE USUARIOS
SET    estado_cuenta     = 'ACTIVO',
       fecha_vencimiento = :NEW.fecha_pago + 30
WHERE  id_usuario = :NEW.id_usuario;
END IF;
END TRG_ACTIVAR_CUENTA;
/

PROMPT NT2-13: TRG_ACTIVAR_CUENTA creado. Ejecutando pruebas...

-- Prueba 1: pago EXITOSO activa cuenta INACTIVA
DECLARE
    v_id NUMBER; v_venc_pre DATE; v_estado_post VARCHAR2(10); v_venc_post DATE;
    v_fp DATE := SYSDATE;
BEGIN
SELECT id_usuario, fecha_vencimiento INTO v_id, v_venc_pre
FROM   USUARIOS WHERE estado_cuenta='ACTIVO' AND ROWNUM=1;
UPDATE USUARIOS SET estado_cuenta='INACTIVO' WHERE id_usuario=v_id;

INSERT INTO PAGOS (fecha_pago,monto,metodo_pago,estado_pago,descuento_aplicado,id_usuario)
VALUES (v_fp, 14900, 'PSE', 'EXITOSO', 0, v_id);

SELECT estado_cuenta, fecha_vencimiento INTO v_estado_post, v_venc_post
FROM   USUARIOS WHERE id_usuario=v_id;

IF v_estado_post='ACTIVO' AND v_venc_post=v_fp+30 THEN
        DBMS_OUTPUT.PUT_LINE('P1 OK: cuenta activada, venc='||TO_CHAR(v_venc_post,'DD/MM/YYYY'));
ELSE
        DBMS_OUTPUT.PUT_LINE('P1 FALLO: estado='||v_estado_post);
END IF;
ROLLBACK;
END;
/

-- Prueba 2: pago FALLIDO NO activa la cuenta
DECLARE v_id NUMBER; v_estado_post VARCHAR2(10);
BEGIN
SELECT id_usuario INTO v_id FROM USUARIOS WHERE estado_cuenta='ACTIVO' AND ROWNUM=1;
UPDATE USUARIOS SET estado_cuenta='INACTIVO' WHERE id_usuario=v_id;
INSERT INTO PAGOS (fecha_pago,monto,metodo_pago,estado_pago,descuento_aplicado,id_usuario)
VALUES (SYSDATE, 14900, 'TARJETA_CREDITO', 'FALLIDO', 0, v_id);
SELECT estado_cuenta INTO v_estado_post FROM USUARIOS WHERE id_usuario=v_id;
IF v_estado_post='INACTIVO' THEN
        DBMS_OUTPUT.PUT_LINE('P2 OK: pago FALLIDO no activo la cuenta.');
ELSE
        DBMS_OUTPUT.PUT_LINE('P2 FALLO: estado cambio a '||v_estado_post);
END IF;
ROLLBACK;
END;
/

-- Prueba 3: integracion SP_REGISTRAR_USUARIO + TRG_ACTIVAR_CUENTA
DECLARE v_id NUMBER; v_estado VARCHAR2(10);
BEGIN
    SP_REGISTRAR_USUARIO('Integracion','NT2-13','int.nt13@test.com','hash',
        'Armenia',1,'PSE',NULL,v_id);
SELECT estado_cuenta INTO v_estado FROM USUARIOS WHERE id_usuario=v_id;
IF v_estado='ACTIVO' THEN
        DBMS_OUTPUT.PUT_LINE('P3 OK: trigger activo cuenta tras SP_REGISTRAR_USUARIO.');
END IF;
DELETE FROM PAGOS    WHERE id_usuario=v_id;
DELETE FROM PERFILES WHERE id_usuario=v_id;
DELETE FROM USUARIOS WHERE id_usuario=v_id;
COMMIT;
END;
/


-- =============================================================================
-- VERIFICACION FINAL — Estado de todos los objetos NT2
-- =============================================================================

PROMPT
PROMPT ============================================================
PROMPT VERIFICACION FINAL: Estado de objetos PL/SQL NT2
PROMPT ============================================================

SELECT object_name, object_type, status, last_ddl_time
FROM   user_objects
WHERE  object_name IN (
                       'SP_REGISTRAR_USUARIO', 'SP_CAMBIAR_PLAN', 'SP_REPORTE_CONSUMO',
                       'FN_CALCULAR_MONTO', 'FN_CONTENIDO_RECOMENDADO',
                       'TRG_VALID_CUENTA', 'TRG_MAX_PERFILES',
                       'TRG_VALID_CALIFICACION', 'TRG_ACTIVAR_CUENTA'
    )
ORDER  BY object_type, object_name;

PROMPT
PROMPT ============================================================
PROMPT MAPA DE CODIGOS DE ERROR PERSONALIZADOS NT2
PROMPT ============================================================

SELECT '-20001' codigo, 'SP_CAMBIAR_PLAN'        objeto, 'PERFILES_EXCEDIDOS'  descripcion FROM DUAL UNION ALL
SELECT '-20002',        'SP_CAMBIAR_PLAN',               'USUARIO_NO_EXISTE'               FROM DUAL UNION ALL
SELECT '-20003',        'SP_CAMBIAR_PLAN',               'PLAN_NO_EXISTE'                   FROM DUAL UNION ALL
SELECT '-20004',        'SP_CAMBIAR_PLAN',               'MISMO_PLAN'                       FROM DUAL UNION ALL
SELECT '-20010',        'TRG_VALID_CUENTA',              'Cuenta INACTIVA'                  FROM DUAL UNION ALL
SELECT '-20011',        'TRG_VALID_CUENTA / SP_REG_USR', 'SUSPENDIDA / EMAIL_DUPLICADO'     FROM DUAL UNION ALL
SELECT '-20012',        'TRG_VALID_CUENTA / SP_REG_USR', 'Perfil no hallado / PLAN_NO_EXISTE' FROM DUAL UNION ALL
SELECT '-20021',        'TRG_MAX_PERFILES / FN_CALC',   'Limite perfiles / USUARIO_NO_EXISTE' FROM DUAL UNION ALL
SELECT '-20022',        'TRG_MAX_PERFILES',              'Usuario no hallado'                FROM DUAL UNION ALL
SELECT '-20031',        'TRG_VALID_CALIFICACION',        'Avance insuficiente'               FROM DUAL UNION ALL
SELECT '-20099',        'Todos los SP',                  'Error inesperado (catch-all)'      FROM DUAL
ORDER  BY 1;

PROMPT
PROMPT ============================================================
PROMPT FIN DEL SCRIPT NT2__nucleo2_plsql_NT2_COMPLETO.sql
PROMPT Verificaciones rapidas post-ejecucion:
PROMPT   SELECT object_name, status FROM user_objects
                                             PROMPT   WHERE object_type IN ('PROCEDURE','FUNCTION','TRIGGER')
             PROMPT   AND status != 'VALID';   -- debe retornar 0 filas
PROMPT ============================================================