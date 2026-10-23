-- ==========================================================
-- PARTE A — Paso 1: creación de roles
-- Ejecutar conectado como postgres.
-- ==========================================================

-- Roles de grupo: no pueden iniciar sesión.
CREATE ROLE rol_app_lectura
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS;

CREATE ROLE rol_app_escritura
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS;

CREATE ROLE rol_soporte
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS;

CREATE ROLE rol_reportes
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS;

-- Roles con inicio de sesión.
-- PASSWORD NULL evita guardar una contraseña en Git.
CREATE ROLE app_web
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS
    PASSWORD NULL;

CREATE ROLE admin_datos
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS
    PASSWORD NULL;

-- ==========================================================
-- PARTE A — Paso 2: membresías de roles
-- ==========================================================

GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;

-- ==========================================================
-- PARTE A — Paso 3: permisos de lectura de catálogo
-- ==========================================================

GRANT USAGE ON SCHEMA public TO rol_app_lectura;

GRANT SELECT ON TABLE categoria, producto
TO rol_app_lectura;

-- ==========================================================
-- PARTE A — Paso 4: permisos para registrar pedidos
-- ==========================================================

GRANT USAGE ON SCHEMA public TO rol_app_escritura;

GRANT SELECT ON TABLE categoria, producto
TO rol_app_escritura;

GRANT INSERT ON TABLE pedido, detalle_pedido
TO rol_app_escritura;

GRANT USAGE ON SEQUENCE
    public.pedido_id_pedido_seq,
    public.detalle_pedido_id_detalle_pedido_seq
TO rol_app_escritura;

-- ==========================================================
-- PARTE A — Paso 5: permisos para reportes
-- ==========================================================

GRANT USAGE ON SCHEMA public TO rol_reportes;

GRANT SELECT ON TABLE
    categoria,
    producto,
    pedido,
    detalle_pedido
TO rol_reportes;

-- ==========================================================
-- PARTE A — Paso 6: permisos limitados para soporte
-- ==========================================================

GRANT USAGE ON SCHEMA public TO rol_soporte;

GRANT SELECT (
    id,
    nombre,
    apellido,
    mail,
    celular,
    rol,
    eliminado,
    created_at,
    id_cliente
) ON TABLE usuario
TO rol_soporte;

GRANT UPDATE (
    mail,
    celular,
    eliminado
) ON TABLE usuario
TO rol_soporte;

-- ==========================================================
-- PARTE A — Paso 7: membresías de admin_datos
-- ==========================================================

GRANT rol_app_lectura TO admin_datos;
GRANT rol_app_escritura TO admin_datos;
GRANT rol_soporte TO admin_datos;
GRANT rol_reportes TO admin_datos;

-- ==========================================================
-- PARTE A — Paso 8: retirar privilegios generales
-- ==========================================================

REVOKE ALL ON SCHEMA public FROM PUBLIC;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
FROM PUBLIC;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
FROM PUBLIC;

-- ==========================================================
-- PARTE A — Paso 9: política para objetos futuros
-- ==========================================================

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE ALL ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE ALL ON SEQUENCES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
