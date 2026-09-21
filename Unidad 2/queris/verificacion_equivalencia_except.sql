-- ============================================================
-- VERIFICACIÓN DE EQUIVALENCIA — Parte 3
-- Para cada par (v1/v2) las dos sentencias EXCEPT deben
-- devolver 0 filas si las consultas son equivalentes.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- (a) RANKING — v1 EXCEPT v2   (debe dar 0 filas)
-- ────────────────────────────────────────────────────────────
(
    -- v1: JOIN + GROUP BY + DENSE_RANK
    SELECT
        c.id_cliente,
        c.nombre || ' ' || c.apellido                        AS cliente,
        SUM(dp.cantidad * dp.precio_unitario)                AS total_gastado,
        DENSE_RANK() OVER (
            ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC,
                     c.id_cliente ASC
        )                                                    AS puesto
    FROM cliente c
    JOIN pedido p          ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
    GROUP BY c.id_cliente, c.nombre, c.apellido
)
EXCEPT
(
    -- v2: subconsulta correlacionada en CTE + DENSE_RANK
    WITH totales AS (
        SELECT
            c.id_cliente,
            c.nombre || ' ' || c.apellido AS cliente,
            (SELECT SUM(dp.cantidad * dp.precio_unitario)
             FROM pedido p
             JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
             WHERE p.id_cliente = c.id_cliente) AS total_gastado
        FROM cliente c
        WHERE EXISTS (
            SELECT 1
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
            WHERE p.id_cliente = c.id_cliente
        )
    )
    SELECT
        id_cliente,
        cliente,
        total_gastado,
        DENSE_RANK() OVER (ORDER BY total_gastado DESC, id_cliente ASC) AS puesto
    FROM totales
);

-- ────────────────────────────────────────────────────────────
-- (a) RANKING — v2 EXCEPT v1   (debe dar 0 filas)
-- ────────────────────────────────────────────────────────────
(
    WITH totales AS (
        SELECT
            c.id_cliente,
            c.nombre || ' ' || c.apellido AS cliente,
            (SELECT SUM(dp.cantidad * dp.precio_unitario)
             FROM pedido p
             JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
             WHERE p.id_cliente = c.id_cliente) AS total_gastado
        FROM cliente c
        WHERE EXISTS (
            SELECT 1
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
            WHERE p.id_cliente = c.id_cliente
        )
    )
    SELECT
        id_cliente,
        cliente,
        total_gastado,
        DENSE_RANK() OVER (ORDER BY total_gastado DESC, id_cliente ASC) AS puesto
    FROM totales
)
EXCEPT
(
    SELECT
        c.id_cliente,
        c.nombre || ' ' || c.apellido                        AS cliente,
        SUM(dp.cantidad * dp.precio_unitario)                AS total_gastado,
        DENSE_RANK() OVER (
            ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC,
                     c.id_cliente ASC
        )                                                    AS puesto
    FROM cliente c
    JOIN pedido p          ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
    GROUP BY c.id_cliente, c.nombre, c.apellido
);

-- ────────────────────────────────────────────────────────────
-- (b) SUBCONSULTA — v1 EXCEPT v2   (debe dar 0 filas)
-- ────────────────────────────────────────────────────────────
(
    -- v1: subconsultas correlacionadas (SELECT y WHERE)
    SELECT
        c.id_cliente,
        c.nombre,
        c.apellido,
        (SELECT SUM(dp.cantidad * dp.precio_unitario)
         FROM pedido p
         JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
         WHERE p.id_cliente = c.id_cliente) AS total_gastado
    FROM cliente c
    WHERE
        (SELECT SUM(dp.cantidad * dp.precio_unitario)
         FROM pedido p
         JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
         WHERE p.id_cliente = c.id_cliente)
        >
        (SELECT AVG(total_gastado)
         FROM (
            SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
            GROUP BY p.id_cliente
         ) AS por_cliente)
)
EXCEPT
(
    -- v2: JOIN + GROUP BY + HAVING
    SELECT
        c.id_cliente,
        c.nombre,
        c.apellido,
        SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente c
    JOIN pedido p          ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
    GROUP BY c.id_cliente, c.nombre, c.apellido
    HAVING SUM(dp.cantidad * dp.precio_unitario) >
           (SELECT AVG(total_gastado)
            FROM (
                SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
                FROM pedido p
                JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                GROUP BY p.id_cliente
            ) AS por_cliente)
);

-- ────────────────────────────────────────────────────────────
-- (b) SUBCONSULTA — v2 EXCEPT v1   (debe dar 0 filas)
-- ────────────────────────────────────────────────────────────
(
    SELECT
        c.id_cliente,
        c.nombre,
        c.apellido,
        SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente c
    JOIN pedido p          ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
    GROUP BY c.id_cliente, c.nombre, c.apellido
    HAVING SUM(dp.cantidad * dp.precio_unitario) >
           (SELECT AVG(total_gastado)
            FROM (
                SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
                FROM pedido p
                JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                GROUP BY p.id_cliente
            ) AS por_cliente)
)
EXCEPT
(
    SELECT
        c.id_cliente,
        c.nombre,
        c.apellido,
        (SELECT SUM(dp.cantidad * dp.precio_unitario)
         FROM pedido p
         JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
         WHERE p.id_cliente = c.id_cliente) AS total_gastado
    FROM cliente c
    WHERE
        (SELECT SUM(dp.cantidad * dp.precio_unitario)
         FROM pedido p
         JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
         WHERE p.id_cliente = c.id_cliente)
        >
        (SELECT AVG(total_gastado)
         FROM (
            SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
            GROUP BY p.id_cliente
         ) AS por_cliente)
);

-- ────────────────────────────────────────────────────────────
-- CONTROL ADICIONAL: conteos de cada versión
-- (todos los conteos pares deben coincidir)
-- ────────────────────────────────────────────────────────────
SELECT
    (SELECT COUNT(*) FROM (SELECT c.id_cliente
                           FROM cliente c
                           JOIN pedido p          ON c.id_cliente = p.id_cliente
                           JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                           GROUP BY c.id_cliente) x)   AS ranking_a1_v1,
    (SELECT COUNT(*) FROM (WITH totales AS (
                               SELECT c.id_cliente
                               FROM cliente c
                               WHERE EXISTS (
                                   SELECT 1
                                   FROM pedido p
                                   JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                                   WHERE p.id_cliente = c.id_cliente)
                           ) SELECT id_cliente FROM totales) x) AS ranking_a2_v2,
    (SELECT COUNT(*) FROM (SELECT c.id_cliente
                           FROM cliente c
                           JOIN pedido p          ON c.id_cliente = p.id_cliente
                           JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                           GROUP BY c.id_cliente
                           HAVING SUM(dp.cantidad * dp.precio_unitario) >
                                  (SELECT AVG(total_gastado)
                                   FROM (
                                       SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
                                       FROM pedido p
                                       JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                                       GROUP BY p.id_cliente
                                   ) AS por_cliente)) x)       AS subcons_b1,
    (SELECT COUNT(*) FROM (SELECT c.id_cliente
                           FROM cliente c
                           WHERE
                               (SELECT SUM(dp.cantidad * dp.precio_unitario)
                                FROM pedido p
                                JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                                WHERE p.id_cliente = c.id_cliente)
                               >
                               (SELECT AVG(total_gastado)
                                FROM (
                                    SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
                                    FROM pedido p
                                    JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
                                    GROUP BY p.id_cliente
                                ) AS por_cliente)) x)          AS subcons_b2;