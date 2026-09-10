(
    -- Versión A
    SELECT c.id_categoria, c.nombre AS nombre_categoria, COUNT(p.id_producto) AS cantidad_productos
    FROM categoria c
    LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.activo = TRUE
    WHERE c.activo = TRUE
    GROUP BY c.id_categoria, c.nombre
)
EXCEPT
(
    -- Versión B
    SELECT c.id_categoria, c.nombre AS nombre_categoria, (
        SELECT COUNT(p.id_producto) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo = TRUE
    ) AS cantidad_productos
    FROM categoria c
    WHERE c.activo = TRUE
);