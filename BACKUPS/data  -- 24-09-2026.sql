-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: bd_isa_carga.sql
-- Motor: PostgreSQL
-- Propósito: Carga masiva de datos de prueba
--   · 10 categorías
--   · 50.000 productos
--   · 20.000 clientes
--   · 200.000 pedidos con sus detalles
--
-- IMPORTANTE: Ejecutar SIEMPRE sobre una copia/base de prueba,
-- nunca sobre la base de producción.
-- Se recomienda ejecutar dentro de una transacción (ver al final).
-- =====================================================================

-- =====================================================================
-- 1. CATEGORÍAS (10)
-- =====================================================================
INSERT INTO categoria (nombre, descripcion, activo)
VALUES
    ('Frutas y Verduras',  'Productos frescos de huerta y granja',          TRUE),
    ('Lácteos',            'Leches, quesos, yogures y derivados',           TRUE),
    ('Carnes',             'Carnes rojas, blancas y embutidos',             TRUE),
    ('Panadería',          'Panes, facturas y productos de bollería',       TRUE),
    ('Bebidas',            'Agua, gaseosas, jugos y bebidas alcohólicas',   TRUE),
    ('Limpieza',           'Artículos de limpieza del hogar',               TRUE),
    ('Higiene Personal',   'Cuidado personal y cosméticos',                 TRUE),
    ('Congelados',         'Alimentos congelados y precocidos',             TRUE),
    ('Snacks',             'Galletitas, alfajores, golosinas y chips',      TRUE),
    ('Varios',             'Productos sin categoría específica',            TRUE);

-- =====================================================================
-- 2. CLIENTES (20.000)
--    · correo único:  usuario_<n>@foodstore.com
--    · nombre/apellido no vacíos (satisface chk_cliente_nombre_apellido_no_vacios)
--    · formato de correo válido (satisface chk_cliente_correo_formato)
-- =====================================================================
INSERT INTO cliente (nombre, apellido, correo_electronico, telefono)
SELECT
    'Nombre'   || n::TEXT                          AS nombre,
    'Apellido' || n::TEXT                          AS apellido,
    'usuario_' || n::TEXT || '@foodstore.com'      AS correo_electronico,
    '+54900' || LPAD(n::TEXT, 7, '0')              AS telefono
FROM generate_series(1, 20000) AS n;

-- =====================================================================
-- 3. PRODUCTOS (50.000)
--    · distribuidos en forma rotativa entre las 10 categorías
--    · precio entre 10.00 y 9999.00  (satisface chk_producto_precio_no_negativo)
--    · stock entre 0 y 500           (satisface chk_producto_stock_no_negativo)
--    · nombre no vacío               (satisface chk_producto_nombre_no_vacio)
--    · id_categoria NOT NULL con FK  (satisface fk_producto_categoria)
-- =====================================================================
INSERT INTO producto (nombre, descripcion, precio_actual, stock, activo, id_categoria)
SELECT
    'Producto ' || n::TEXT                                              AS nombre,
    'Descripción del producto número ' || n::TEXT                      AS descripcion,
    -- precio: entre 10.00 y 9999.00 con 2 decimales
    ROUND( (random() * 9989 + 10)::NUMERIC, 2 )                        AS precio_actual,
    -- stock: entre 0 y 500
    (random() * 500)::INT                                               AS stock,
    -- 95 % de los productos activos
    (random() > 0.05)                                                   AS activo,
    -- categoría rotativa: 1..10
    (((n - 1) % 10) + 1)                                               AS id_categoria
FROM generate_series(1, 50000) AS n;

-- =====================================================================
-- 4. PEDIDOS (200.000)
--    · asignados a clientes existentes (id_cliente entre 1 y 20.000)
--    · fecha_hora distribuida en los últimos 2 años
--    · forma de pago rotativa entre los 3 valores del enum
-- =====================================================================
INSERT INTO pedido (fecha_hora, forma_pago, id_cliente)
SELECT
    -- fecha distribuida entre hace 2 años y hoy
    now() - (random() * INTERVAL '730 days')                            AS fecha_hora,
    -- rotación: 1→EFECTIVO, 2→TARJETA, 3→TRANSFERENCIA
    CASE (n % 3)
        WHEN 0 THEN 'EFECTIVO'::forma_pago_enum
        WHEN 1 THEN 'TARJETA'::forma_pago_enum
        ELSE        'TRANSFERENCIA'::forma_pago_enum
    END                                                                  AS forma_pago,
    -- cliente entre 1 y 20.000
    (floor(random() * 20000) + 1)::BIGINT                               AS id_cliente
FROM generate_series(1, 200000) AS n;

-- =====================================================================
-- 5. DETALLE_PEDIDO
--    Estrategia: cada pedido recibe entre 1 y 5 líneas de detalle.
--    Se genera una tabla de combinaciones pedido×posición y se
--    asigna un producto aleatorio distinto por posición dentro del
--    mismo pedido (satisface unq_pedido_producto via DISTINCT ON).
--
--    · cantidad entre 1 y 20      (satisface chk_detalle_cantidad_positiva)
--    · precio_unitario ≥ 0        (satisface chk_detalle_precio_no_negativo)
--    · FK a pedido y producto
-- =====================================================================

-- Tabla temporal para construir los detalles sin colisionar el UNIQUE
CREATE TEMP TABLE tmp_detalle AS
WITH
-- Para cada pedido generamos entre 1 y 5 líneas
lineas AS (
    SELECT
        p.id_pedido,
        -- cantidad de líneas para este pedido: 1..5
        (floor(random() * 5) + 1)::INT AS num_lineas
    FROM pedido p
),
-- Expandimos: una fila por cada línea de cada pedido
posiciones AS (
    SELECT
        l.id_pedido,
        pos.pos
    FROM lineas l
    CROSS JOIN LATERAL generate_series(1, l.num_lineas) AS pos(pos)
),
-- Asignamos un producto aleatorio a cada posición
candidatos AS (
    SELECT
        pos.id_pedido,
        pos.pos,
        -- producto aleatorio entre 1 y 50.000
        (floor(random() * 50000) + 1)::BIGINT AS id_producto,
        -- cantidad entre 1 y 20
        (floor(random() * 20) + 1)::INT        AS cantidad
    FROM posiciones pos
),
-- Eliminamos duplicados id_pedido+id_producto que violarían el UNIQUE
deduplicados AS (
    SELECT DISTINCT ON (id_pedido, id_producto)
        id_pedido,
        id_producto,
        cantidad
    FROM candidatos
    ORDER BY id_pedido, id_producto, pos
)
SELECT
    d.id_pedido,
    d.id_producto,
    d.cantidad,
    -- precio histórico tomado del producto al momento de la carga
    pr.precio_actual AS precio_unitario
FROM deduplicados d
JOIN producto pr ON pr.id_producto = d.id_producto;

-- Insertamos desde la tabla temporal
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM tmp_detalle;

DROP TABLE tmp_detalle;

-- =====================================================================
-- 6. ANALYZE — actualiza estadísticas del optimizador
-- =====================================================================
ANALYZE categoria;
ANALYZE cliente;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- =====================================================================
-- Verificación rápida post-carga
-- =====================================================================
SELECT 'categoria'     AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL
SELECT 'cliente',               COUNT(*)            FROM cliente
UNION ALL
SELECT 'producto',              COUNT(*)            FROM producto
UNION ALL
SELECT 'pedido',                COUNT(*)            FROM pedido
UNION ALL
SELECT 'detalle_pedido',        COUNT(*)            FROM detalle_pedido;
