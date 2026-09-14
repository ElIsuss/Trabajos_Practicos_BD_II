-- =====================================================================
-- CONSULTA 1 — Productos activos en un rango de precio, ordenados por precio
-- VERSIÓN RÁPIDA (índice B-Tree sobre precio_actual)
--
-- Problema identificado en la versión lenta:
--   Sin índice en precio_actual, PostgreSQL recorría las 50.000 filas
--   completas de producto descartando 48.130 (96% de la tabla) para
--   encontrar solo 1.870 filas en el rango 100-500.
--
-- Solución aplicada:
--   Un índice B-Tree sobre precio_actual permite a PostgreSQL hacer
--   un Index Scan directo al rango solicitado sin leer filas fuera
--   del intervalo. Se agrega el filtro activo = TRUE en el índice
--   (índice parcial) para que también descarte productos inactivos
--   sin costo extra en la búsqueda.
-- =====================================================================

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