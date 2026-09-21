-- ============================================================
-- TOTAL GASTADO POR CLIENTE — subconsulta correlacionada
-- Estrategia: subconsulta en SELECT + EXISTS en WHERE
-- Solo incluye clientes con al menos un pedido registrado.
-- ============================================================
SELECT
    c.id_cliente,
    c.nombre,
    c.apellido,
    (
        SELECT COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        WHERE p.id_cliente = c.id_cliente
    ) AS total_gastado
FROM cliente c
WHERE EXISTS (
    SELECT 1
    FROM pedido p
    WHERE p.id_cliente = c.id_cliente
)
ORDER BY total_gastado DESC;
