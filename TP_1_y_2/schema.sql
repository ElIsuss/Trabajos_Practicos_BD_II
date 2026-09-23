-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: schema.sql
-- Motor: PostgreSQL
-- =====================================================================

-- 1. Tipo enumerado para los dominios cerrados (Forma de pago)
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- 2. Tabla Categoría
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Tabla Cliente
CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL,
    apellido VARCHAR(60) NOT NULL,
    correo_electronico VARCHAR(100) NOT NULL UNIQUE, -- Restricción UNIQUE exigida por regla R6
    telefono VARCHAR(30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Tabla Producto
CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio_actual NUMERIC(10, 2) NOT NULL,
    stock INT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- Marca de baja lógica (Regla R7)
    id_categoria BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) 
        REFERENCES categoria(id_categoria) ON DELETE RESTRICT,
    -- Restricciones CHECK para evitar valores negativos (Regla R5)
    CONSTRAINT chk_producto_precio_no_negativo CHECK (precio_actual >= 0),
    CONSTRAINT chk_producto_stock_no_negativo CHECK (stock >= 0)
);

-- 5. Tabla Pedido
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    id_cliente BIGINT NOT NULL,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) 
        REFERENCES cliente(id_cliente) ON DELETE RESTRICT
);

-- 6. Tabla Intermedia: DetallePedido (Relación N:M entre Pedido y Producto)
CREATE TABLE detalle_pedido (
    id_detalle_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL, -- Preserva el precio histórico (Regla R4)
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido) 
        REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) 
        REFERENCES producto(id_producto) ON DELETE RESTRICT,
    -- Evita que se repita el mismo producto en una misma línea de pedido
    CONSTRAINT unq_pedido_producto UNIQUE (id_pedido, id_producto),
    -- Restricción CHECK para que la cantidad pedida sea mayor a cero
    CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_no_negativo CHECK (precio_unitario >= 0)
);

-- =====================================================================
-- ÍNDICES (Para optimizar consultas frecuentes)
-- =====================================================================

-- Índice para acelerar la búsqueda de pedidos realizados por un cliente específico
CREATE INDEX idx_pedido_cliente ON pedido(id_cliente);

-- Índice para listar rápidamente los productos activos que pertenecen a una categoría
CREATE INDEX idx_producto_categoria_activo ON producto(id_categoria) WHERE activo = TRUE;