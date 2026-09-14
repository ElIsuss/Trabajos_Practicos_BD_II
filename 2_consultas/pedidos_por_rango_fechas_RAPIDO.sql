-- Paso 1: crear el índice sobre fecha_hora
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_hora
    ON pedido (fecha_hora);

-- =====================================================================
-- Paso 2: ejecutar la consulta y medir el nuevo plan
-- =====================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    cl.nombre || ' ' || cl.apellido      AS cliente,
    pr.nombre                            AS producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.cantidad * dp.precio_unitario     AS subtotal
FROM pedido p
JOIN cliente cl        ON cl.id_cliente  = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido   = p.id_pedido
JOIN producto pr       ON pr.id_producto = dp.id_producto
WHERE p.fecha_hora BETWEEN '2026-08-01' AND '2026-09-09'
ORDER BY p.fecha_hora DESC;


