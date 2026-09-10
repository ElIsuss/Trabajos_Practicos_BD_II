-- Paso 1: crear el índice parcial sobre precio_actual para productos activos
CREATE INDEX IF NOT EXISTS idx_producto_precio_activo
    ON producto (precio_actual DESC)
    WHERE activo = TRUE;

-- =====================================================================
-- Paso 2: ejecutar la consulta y medir el nuevo plan
-- =====================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_producto,
    p.nombre,
    p.precio_actual,
    p.stock,
    c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.precio_actual BETWEEN 4500 AND 5000
  AND p.activo = TRUE
ORDER BY p.precio_actual DESC;
