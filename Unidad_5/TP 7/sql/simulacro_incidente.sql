-- =====================================================================
-- PARTE C — Simulacro de incidente de acceso indebido
-- Archivo: simulacro_incidente.sql
-- Motor: PostgreSQL 18 — base foodstore
-- Ejecutar: psql -d foodstore -f simulacro_incidente.sql
-- =====================================================================
-- PREREQUISITO: fn_autenticar no existía y se reconstruye aquí
-- como paso previo (ver BITACORA.md).
-- =====================================================================

-- =====================================================================
-- FASE 0 — SETUP: crear fn_autenticar y setear contraseña de app_web
-- =====================================================================
-- Ejecutar como postgres (conexión inicial)

\echo '========================================================'
\echo 'FASE 0 — SETUP'
\echo '========================================================'

-- Reconstrucción de fn_autenticar (prerrequisito de la Clase 1/2)
CREATE OR REPLACE FUNCTION fn_autenticar(p_mail VARCHAR, p_contrasena VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_autenticado BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM usuario
        WHERE mail = p_mail
          AND contrasena = p_contrasena
          AND eliminado = FALSE
    ) INTO v_autenticado;

    RETURN v_autenticado;
END;
$$;

-- Setear contraseña de app_web para poder conectar en la Fase 3
ALTER ROLE app_web PASSWORD 'app_web_pass_2026';

\echo 'Setup completo: fn_autenticar creada, contraseña de app_web seteada.'

-- =====================================================================
-- FASE 1 — FUERZA BRUTA: 3 intentos fallidos contra fn_autenticar
-- =====================================================================
-- Estas llamadas son SELECTs: con log_statement = 'mod' NO se registran
-- en el log. Esta es una limitación que se explota en el contraste.

\echo '========================================================'
\echo 'FASE 1 — FUERZA BRUTA (3 intentos fallidos)'
\echo '========================================================'

SELECT fn_autenticar('usuario_1@foodstore.com', 'password_erronea_1') AS intento_1;
SELECT fn_autenticar('usuario_1@foodstore.com', 'password_erronea_2') AS intento_2;
SELECT fn_autenticar('usuario_1@foodstore.com', 'password_erronea_3') AS intento_3;

\echo 'Fase 1 completa: 3 intentos fallidos (no se registran en log con mod).'

-- =====================================================================
-- FASE 2 — LOGIN EXITOSO contra fn_autenticar
-- =====================================================================
\echo '========================================================'
\echo 'FASE 2 — LOGIN EXITOSO'
\echo '========================================================'

SELECT fn_autenticar('usuario_1@foodstore.com', 'bcrypt$hash-testeo-no-utilizable') AS intento_exitoso;

\echo 'Fase 2 completa: autenticación exitosa (tampoco se registra en log con mod).'

-- =====================================================================
-- FASE 3 — CONEXIÓN como app_web (atacante usa cuenta comprometida)
-- =====================================================================
-- Esta conexión SÍ se registra en el log (log_connections = on)

\echo '========================================================'
\echo 'FASE 3 — CONEXIÓN como app_web (cuenta comprometida)'
\echo '========================================================'

\connect "host=localhost user=app_web dbname=foodstore password=app_web_pass_2026"

\echo 'Conectado como app_web (registrado en log por log_connections).'

-- =====================================================================
-- FASE 4 — EXFILTRACIÓN: lectura masiva de la tabla usuario
-- =====================================================================
-- app_web NO tiene SELECT sobre usuario → debe fallar con
-- "permission denied for table usuario"

\echo '========================================================'
\echo 'FASE 4 — INTENTO DE LECTURA MASIVA DE usuario'
\echo '========================================================'

SELECT * FROM usuario LIMIT 1000;

\echo 'Fase 4: el intento de lectura debe haber fallado (permission denied).'

-- =====================================================================
-- FASE 5 — ESCALAMIENTO: intentar otorgar admin_datos a app_web
-- =====================================================================
-- app_web NO tiene CREATEROLE ni ADMIN OPTION → debe fallar con
-- "permission denied for role admin_datos"

\echo '========================================================'
\echo 'FASE 5 — INTENTO DE ESCALAMIENTO DE PRIVILEGIOS'
\echo '========================================================'

GRANT admin_datos TO app_web;

\echo 'Fase 5: el intento de escalamiento debe haber fallado (permission denied).'

-- =====================================================================
-- FASE 6 — RECONEXIÓN como postgres
-- =====================================================================

\echo '========================================================'
\echo 'FASE 6 — RECONEXIÓN como postgres'
\echo '========================================================'

\connect foodstore

\echo 'Simulacro completo. Extraer el fragmento de log correspondiente.'
