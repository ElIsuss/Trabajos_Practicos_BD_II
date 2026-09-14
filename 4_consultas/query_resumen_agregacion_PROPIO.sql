SELECT
    c.id_categoria,
    c.nombre AS nombre_categoria,
    (
        SELECT COUNT(p.id_producto)
        FROM producto p
        WHERE p.id_categoria = c.id_categoria
          AND p.activo = TRUE
    ) AS cantidad_productos
FROM categoria c
WHERE c.activo = TRUE
ORDER BY
    cantidad_productos DESC,
    c.nombre ASC;