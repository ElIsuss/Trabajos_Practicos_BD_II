-- =====================================================================
-- Consulta: Productos más vendidos (por cantidad)
-- Versión: SIN optimización
-- Problema: Seq Scan completo en detalle_pedido y producto
--           Sort y HashAggregate se desbordan a disco
-- Tiempo registrado: ~347 ms
-- =====================================================================

EXPLAIN ANALYZE
SELECT
    pr.nombre                             AS producto,
    SUM(dp.cantidad)                      AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario) AS ingreso_generado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY total_vendido DESC
LIMIT 20;
