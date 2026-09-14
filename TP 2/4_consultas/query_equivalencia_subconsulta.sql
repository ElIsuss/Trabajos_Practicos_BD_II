(
    -- Versión A
    SELECT c.id_cliente, c.nombre, c.apellido, ROUND(AVG(dp.precio_unitario), 2) AS promedio_pagado
    FROM cliente c
    JOIN pedido p ON p.id_cliente = c.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    GROUP BY c.id_cliente, c.nombre, c.apellido
    HAVING AVG(dp.precio_unitario) > (SELECT AVG(precio_unitario) FROM detalle_pedido)
)
EXCEPT
(
    -- Versión B
    WITH promedio_global AS (SELECT AVG(precio_unitario) AS avg_global FROM detalle_pedido)
    SELECT c.id_cliente, c.nombre, c.apellido, ROUND(AVG(dp.precio_unitario), 2) AS promedio_pagado
    FROM cliente c
    JOIN pedido p ON p.id_cliente = c.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    CROSS JOIN promedio_global pg
    GROUP BY c.id_cliente, c.nombre, c.apellido, pg.avg_global
    HAVING AVG(dp.precio_unitario) > pg.avg_global
);