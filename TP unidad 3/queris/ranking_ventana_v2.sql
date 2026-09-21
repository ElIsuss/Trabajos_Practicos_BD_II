-- ============================================================
-- RANKING DE CLIENTES POR TOTAL GASTADO — v2
-- Estrategia: CTE con totales precalculados + DENSE_RANK()
-- ============================================================
WITH totales AS (
    SELECT
        c.id_cliente,
        c.nombre || ' ' || c.apellido         AS cliente,
        SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente c
    JOIN pedido p
        ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido dp
        ON p.id_pedido = dp.id_pedido
    GROUP BY
        c.id_cliente,
        c.nombre,
        c.apellido
)
SELECT
    id_cliente,
    cliente,
    total_gastado,
    DENSE_RANK() OVER (ORDER BY total_gastado DESC) AS puesto
FROM totales
ORDER BY puesto;
