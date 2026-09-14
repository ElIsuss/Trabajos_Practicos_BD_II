-- =====================================================================
-- Consulta: Facturación por categoría y mes
-- Versión: SIN optimización
-- Problema: Seq Scan completo en detalle_pedido, pedido y producto
--           Sort y GroupAggregate se desbordan a disco (~8.5 MB por worker)
--           4 JOINs encadenados sin índices útiles
-- Tiempo registrado: ~525 ms
-- =====================================================================

EXPLAIN ANALYZE
SELECT
    c.nombre                              AS categoria,
    DATE_TRUNC('month', p.fecha_hora)     AS mes,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp  ON dp.id_pedido   = p.id_pedido
JOIN producto       pr  ON pr.id_producto = dp.id_producto
JOIN categoria      c   ON c.id_categoria = pr.id_categoria
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha_hora)
ORDER BY mes, facturacion_total DESC;
