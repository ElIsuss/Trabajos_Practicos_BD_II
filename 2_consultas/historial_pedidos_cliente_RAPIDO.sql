-- Paso 1: habilitar la extensión (solo necesario una vez por base)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Paso 2: crear el índice de trigramas sobre apellido
CREATE INDEX IF NOT EXISTS idx_cliente_apellido_trgm
    ON cliente USING GIN (apellido gin_trgm_ops);

-- =====================================================================
-- Paso 3: ejecutar la consulta y medir el nuevo plan
-- =====================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    cl.nombre || ' ' || cl.apellido        AS cliente,
    COUNT(dp.id_detalle_pedido)            AS cantidad_items,
    SUM(dp.cantidad * dp.precio_unitario)  AS total_pedido
FROM pedido p
JOIN cliente cl        ON cl.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido  = p.id_pedido
WHERE cl.apellido ILIKE '%Apellido150%'
GROUP BY p.id_pedido, p.fecha_hora, p.forma_pago, cl.nombre, cl.apellido
ORDER BY p.fecha_hora DESC;