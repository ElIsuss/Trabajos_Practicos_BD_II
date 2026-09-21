-- ============================================================
-- RANKING DE CLIENTES POR TOTAL GASTADO — v1
-- Estrategia: JOIN directo + GROUP BY + DENSE_RANK()
-- ============================================================
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido                                   AS cliente,
    SUM(dp.cantidad * dp.precio_unitario)                           AS total_gastado,
    DENSE_RANK() OVER (
        ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC
    )                                                               AS puesto
FROM cliente c
JOIN pedido p
    ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp
    ON p.id_pedido = dp.id_pedido
GROUP BY
    c.id_cliente,
    c.nombre,
    c.apellido
ORDER BY puesto;
