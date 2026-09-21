-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: bd_isa_base.sql
-- Motor: PostgreSQL
-- =====================================================================

-- 1. Tipo enumerado para los dominios cerrados (Forma de pago)
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- 2. Tabla Categoría
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL UNIQUE,
    descripcion  TEXT,
    activo       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Tabla Cliente
CREATE TABLE cliente (
    id_cliente          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              VARCHAR(60)  NOT NULL,
    apellido            VARCHAR(60)  NOT NULL,
    correo_electronico  VARCHAR(100) NOT NULL UNIQUE,
    telefono            VARCHAR(30),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Nombre y apellido no vacíos
    CONSTRAINT chk_cliente_nombre_apellido_no_vacios
        CHECK (btrim(nombre) <> '' AND btrim(apellido) <> ''),

    -- Formato básico de correo electrónico
    CONSTRAINT chk_cliente_correo_formato
        CHECK (correo_electronico ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
);

-- 4. Tabla Producto
CREATE TABLE producto (
    id_producto  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(100)   NOT NULL,
    descripcion  TEXT,
    precio_actual NUMERIC(10,2) NOT NULL,
    stock        INT            NOT NULL,
    activo       BOOLEAN        NOT NULL DEFAULT TRUE,
    id_categoria BIGINT         NOT NULL,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),

    -- Precio y stock no negativos (Regla R5)
    CONSTRAINT chk_producto_precio_no_negativo  CHECK (precio_actual >= 0),
    CONSTRAINT chk_producto_stock_no_negativo   CHECK (stock >= 0),

    -- Nombre no vacío
    CONSTRAINT chk_producto_nombre_no_vacio     CHECK (btrim(nombre) <> ''),

    -- Categoría obligatoria (FK)
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT
);

-- 5. Tabla Pedido
CREATE TABLE pedido (
    id_pedido  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora TIMESTAMPTZ      NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum  NOT NULL,
    id_cliente BIGINT           NOT NULL,

    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
        ON DELETE RESTRICT
);

-- 6. Tabla Intermedia: DetallePedido (Relación N:M entre Pedido y Producto)
CREATE TABLE detalle_pedido (
    id_detalle_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido         BIGINT         NOT NULL,
    id_producto       BIGINT         NOT NULL,
    cantidad          INT            NOT NULL,
    precio_unitario   NUMERIC(10,2)  NOT NULL,

    -- Evita duplicar el mismo producto en un mismo pedido
    CONSTRAINT unq_pedido_producto
        UNIQUE (id_pedido, id_producto),

    -- Cantidad mayor a cero y precio no negativo
    CONSTRAINT chk_detalle_cantidad_positiva    CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_no_negativo   CHECK (precio_unitario >= 0),

    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedido(id_pedido)
        ON DELETE RESTRICT,

    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
        ON DELETE RESTRICT
);

-- =====================================================================
-- ÍNDICES (Para optimizar consultas frecuentes)
-- =====================================================================

-- Pedidos por cliente
CREATE INDEX idx_pedido_cliente
    ON pedido(id_cliente);

-- Productos activos por categoría
CREATE INDEX idx_producto_categoria_activo
    ON producto(id_categoria)
    WHERE activo = TRUE;