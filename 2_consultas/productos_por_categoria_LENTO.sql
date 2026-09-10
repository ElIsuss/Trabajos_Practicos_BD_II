-- =====================================================================
-- CONSULTA 1 — Productos activos en un rango de precio, ordenados por precio
-- VERSIÓN LENTA (sin índice en precio_actual)
--
-- Por qué es lenta:
--   · Filtra por rango de precio_actual sobre las 50.000 filas de producto
--   · No existe ningún índice en precio_actual, fuerza un Seq Scan completo
--   · Luego ordena todos los resultados por precio DESC (Sort costoso)
--   · El join con categoria se resuelve después de recorrer toda la tabla
-- =====================================================================

-- =====================================================================
-- PLAN OBTENIDO (EXPLAIN ANALYZE - ANTES DE OPTIMIZAR)
--
-- Execution Time: 6.429 ms
--
-- El problema está en el Seq Scan sobre producto:
--   Sin índice en precio_actual, PostgreSQL recorre las 50.000 filas
--   completas y descarta 47.567 para quedarse con 2.433 que caen
--   en el rango 4500-5000. Todo ese trabajo de lectura se hace para
--   encontrar menos del 5% de la tabla.
--   El Sort final sobre 2.433 filas es barato, pero el Seq Scan
--   inicial es el nodo dominante del plan.
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
