-- =====================================================================
-- SEGURIDAD / TABLA USUARIO - FOOD STORE
-- Motor: PostgreSQL 16+
-- Aplicar sobre la base DESPUÉS de schema_completo.sql y data.sql.
-- Revisado contra el esquema real: la sentencia original fallaba porque
-- el tipo "rol" no existía; además pedido no tenía columna "estado".
-- =====================================================================

-- ---------------------------------------------------------------
-- 1. Tipo enum 'rol' (obligatorio antes de crear la tabla usuario)
-- ---------------------------------------------------------------
CREATE TYPE rol AS ENUM ('ADMINISTRADOR', 'USUARIO');

-- ---------------------------------------------------------------
-- 2. Tabla usuario (credenciales de acceso)
-- Correcciones sobre la sentencia original:
--    · se creó el enum 'rol' que la tabla referenciaba y no existía
--    · se agrega id_cliente FK UNIQUE para vincular 1:1 con cliente
--      (los pedidos referencian a cliente por id_cliente)
--    · la columna exponible mail es UNIQUE (usuario correo electrónico)
-- ---------------------------------------------------------------
CREATE TABLE usuario (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(80)  NOT NULL,
    apellido   VARCHAR(80)  NOT NULL,
    mail       VARCHAR(120) NOT NULL UNIQUE,
    celular    VARCHAR(30),
    contrasena VARCHAR(255) NOT NULL,
    rol        rol          NOT NULL DEFAULT 'USUARIO',
    eliminado  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    id_cliente BIGINT       NOT NULL UNIQUE REFERENCES cliente(id_cliente)
);

-- ---------------------------------------------------------------
-- 3. Estado del pedido (lo exige la spec en v_pedidos_usuario y
--    pedido no lo poseía). Los pedidos previos quedan 'PENDIENTE'.
-- ---------------------------------------------------------------
CREATE TYPE estado_pedido_enum AS ENUM ('PENDIENTE', 'PAGADO', 'ENVIADO', 'ENTREGADO', 'CANCELADO');

ALTER TABLE pedido
    ADD COLUMN estado estado_pedido_enum NOT NULL DEFAULT 'PENDIENTE';

-- ---------------------------------------------------------------
-- 4. Poblado 1:1 de usuario a partir de cliente
--    (un usuario por cliente, en producción guardar hash bcrypt real)
-- ---------------------------------------------------------------
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, id_cliente)
SELECT
    c.nombre,
    c.apellido,
    c.correo_electronico,
    c.telefono,
    'bcrypt$hash-testeo-no-utilizable',
    'USUARIO'::rol,
    c.id_cliente
FROM cliente c;