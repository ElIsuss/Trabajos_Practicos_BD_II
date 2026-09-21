-- =====================================================================
-- Consulta: Productos más vendidos (por cantidad)
-- Versión: CON optimización (índice + vista materializada)
-- Tiempo registrado: ~0.023 ms
-- =====================================================================

-- 1. Índice para acelerar el JOIN por id_producto
CREATE INDEX idx_detalle_producto ON detalle_pedido(id_producto);

-- 2. Vista materializada con el resultado precalculado
CREATE MATERIALIZED VIEW mv_productos_mas_vendidos AS
SELECT
    pr.id_producto,
    pr.nombre                             AS producto,
    SUM(dp.cantidad)                      AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario) AS ingreso_generado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY total_vendido DESC;

-- 3. Índice sobre la vista para acelerar ORDER BY + LIMIT
CREATE INDEX idx_mv_productos_vendidos ON mv_productos_mas_vendidos(total_vendido DESC);

-- 4. Consulta optimizada sobre la vista
EXPLAIN ANALYZE
SELECT * FROM mv_productos_mas_vendidos
LIMIT 20;
