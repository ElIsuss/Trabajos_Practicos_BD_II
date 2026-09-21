-- =====================================================================
-- Consulta: Facturación por categoría y mes
-- Versión: CON optimización (índice + vista materializada)
-- Tiempo registrado: ~0.034 ms
-- =====================================================================

-- 1. Índice para acelerar el JOIN pedido → detalle_pedido
CREATE INDEX idx_detalle_pedido ON detalle_pedido(id_pedido);

-- 2. Vista materializada con el resultado precalculado
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.nombre                              AS categoria,
    DATE_TRUNC('month', p.fecha_hora)     AS mes,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido   = p.id_pedido
JOIN producto       pr ON pr.id_producto = dp.id_producto
JOIN categoria      c  ON c.id_categoria = pr.id_categoria
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha_hora)
ORDER BY mes, facturacion_total DESC;

-- 3. Índice sobre la vista para acelerar el ORDER BY
CREATE INDEX idx_mv_facturacion_mes ON mv_facturacion_categoria_mes(mes, facturacion_total DESC);

-- 4. Consulta optimizada sobre la vista
EXPLAIN ANALYZE
SELECT * FROM mv_facturacion_categoria_mes;
