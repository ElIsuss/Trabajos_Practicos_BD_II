WITH promedio_global AS (
    SELECT AVG(precio_unitario) AS avg_global
    FROM detalle_pedido
)
SELECT
    c.id_cliente,
    c.nombre,
    c.apellido,
    ROUND(AVG(dp.precio_unitario), 2) AS promedio_pagado
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
CROSS JOIN promedio_global pg
GROUP BY
    c.id_cliente,
    c.nombre,
    c.apellido,
    pg.avg_global
HAVING AVG(dp.precio_unitario) > pg.avg_global
ORDER BY
    promedio_pagado DESC;