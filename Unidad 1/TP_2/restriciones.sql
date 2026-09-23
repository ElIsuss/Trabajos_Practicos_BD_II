-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: restricciones.sql
-- Motor: PostgreSQL
-- =====================================================================

-- Categoría obligatoria para cada producto
ALTER TABLE producto
    ALTER COLUMN id_categoria SET NOT NULL,
    ADD CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT;

-- Correo electrónico con formato válido básico
ALTER TABLE cliente
    ADD CONSTRAINT chk_cliente_correo_formato
        CHECK (correo_electronico ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$');

-- Nombre de producto no vacío
ALTER TABLE producto
    ADD CONSTRAINT chk_producto_nombre_no_vacio
        CHECK (btrim(nombre) <> '');

-- Nombre y apellido no vacíos
ALTER TABLE cliente
    ADD CONSTRAINT chk_cliente_nombre_apellido_no_vacios
        CHECK (
            btrim(nombre) <> ''
            AND btrim(apellido) <> ''
        );
