-- =====================================================================
-- CONSULTAS BASE DE NEGOCIO Y ANALÍTICAS - FOOD STORE
-- =====================================================================

-- 1. Facturación por categoría y mes
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

-- 2. Productos más vendidos
SELECT
    pr.id_producto,
    pr.nombre                             AS producto,
    SUM(dp.cantidad)                      AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario) AS ingreso_generado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY total_vendido DESC
LIMIT 20;

-- 3. Ranking de clientes por gasto
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido         AS cliente,
    SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
    DENSE_RANK() OVER (
        ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC
    )                                     AS puesto
FROM cliente c
JOIN pedido p          ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY puesto;


-- 4. Búsqueda de pedidos recientes por cliente
SELECT p.id_pedido, p.fecha_hora, p.forma_pago, p.estado
FROM pedido p
WHERE p.id_cliente = 1500
  AND p.fecha_hora >= NOW() - INTERVAL '180 days'
ORDER BY p.fecha_hora DESC; 