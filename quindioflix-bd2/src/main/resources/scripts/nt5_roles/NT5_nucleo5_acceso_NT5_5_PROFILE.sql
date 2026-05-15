-- =============================================================================
-- NT5-5: Crear PROFILE de recursos Oracle
-- Archivo : NT5_nucleo5_acceso_NT5_5_PROFILE.sql
-- Autor   : Diego Garcia
-- Sprint  : 5
-- =============================================================================
-- Crea el perfil de recursos PERFIL_QUINDIOFLIX y lo asigna a los 4
-- usuarios Oracle de la plataforma.
--
-- JUSTIFICACION DE CADA LIMITE:
--
--   SESSIONS_PER_USER 3
--     Un empleado de QuindioFlix no deberia necesitar mas de 3 sesiones
--     simultaneas (ej: SQL Developer + una sesion de reporte + una de
--     emergencia). Limitar a 3 previene que credenciales comprometidas
--     abran decenas de sesiones paralelas para exfiltrar datos.
--
--   IDLE_TIME 30
--     Sesiones inactivas por mas de 30 minutos se cierran automaticamente.
--     Reduce el riesgo de que un empleado deje su sesion abierta sin
--     supervision (ej: equipo desbloqueado en pausa de almuerzo).
--     30 minutos es suficiente para consultas largas pero razonable
--     para seguridad operativa.
--
--   FAILED_LOGIN_ATTEMPTS 5
--     Despues de 5 intentos fallidos la cuenta se bloquea automaticamente.
--     Mitiga ataques de fuerza bruta sobre las credenciales Oracle.
--     5 intentos es estandar de industria — suficiente para errores
--     tipograficos legitimos sin permitir ataques automatizados.
--
--   PASSWORD_LOCK_TIME 1/24
--     La cuenta bloqueada se desbloquea automaticamente despues de 1 hora
--     (1/24 de dia = 1 hora). Evita que un ataque de fuerza bruta
--     bloquee permanentemente al usuario real. Si el bloqueo fue
--     malicioso, el administrador puede desbloquearlo manualmente antes.
--
-- PREREQUISITO: NT5-2 ejecutado (usuarios ya existentes).
-- EJECUCION   : Run as Script (F5) como SYS en XEPDB1.
-- =============================================================================

-- Cambiar al PDB correcto
ALTER SESSION SET CONTAINER = XEPDB1;

-- =============================================================================
-- NT5-5.0: DROP defensivo
-- =============================================================================
BEGIN
EXECUTE IMMEDIATE 'DROP PROFILE PERFIL_QUINDIOFLIX CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2380 THEN RAISE; END IF; -- ORA-02380: profile does not exist
END;
/

-- =============================================================================
-- NT5-5.1: Crear el perfil con los limites justificados
-- =============================================================================
CREATE PROFILE PERFIL_QUINDIOFLIX LIMIT
    -- Limites de sesion
    SESSIONS_PER_USER       3       -- max 3 sesiones simultaneas por usuario
    IDLE_TIME               30      -- cierra sesion inactiva despues de 30 min
    CONNECT_TIME            480     -- max 8 horas de sesion continua (jornada laboral)
    -- Limites de seguridad de contrasena
    FAILED_LOGIN_ATTEMPTS   5       -- bloquea cuenta despues de 5 intentos fallidos
    PASSWORD_LOCK_TIME      1/24    -- desbloqueo automatico despues de 1 hora
    PASSWORD_LIFE_TIME      180     -- contrasena expira cada 180 dias (6 meses)
    PASSWORD_REUSE_TIME     365     -- no puede reusar contrasena por 1 anno
    PASSWORD_REUSE_MAX      5;      -- no puede reusar ninguna de las ultimas 5

-- =============================================================================
-- NT5-5.2: Asignar el perfil a los 4 usuarios Oracle de QuindioFlix
-- =============================================================================
ALTER USER admin_qflix      PROFILE PERFIL_QUINDIOFLIX;
ALTER USER analista_qflix   PROFILE PERFIL_QUINDIOFLIX;
ALTER USER soporte_qflix    PROFILE PERFIL_QUINDIOFLIX;
ALTER USER contenido_qflix  PROFILE PERFIL_QUINDIOFLIX;

-- =============================================================================
-- NT5-5.3: Verificacion — perfil creado con sus limites
-- =============================================================================
SELECT
    resource_name,
    limit
FROM dba_profiles
WHERE profile = 'PERFIL_QUINDIOFLIX'
ORDER BY resource_name;

-- =============================================================================
-- NT5-5.4: Verificacion — usuarios con el perfil asignado
-- =============================================================================
SELECT
    username,
    profile,
    account_status
FROM dba_users
WHERE username IN (
                   'ADMIN_QFLIX', 'ANALISTA_QFLIX',
                   'SOPORTE_QFLIX', 'CONTENIDO_QFLIX'
    )
ORDER BY username;