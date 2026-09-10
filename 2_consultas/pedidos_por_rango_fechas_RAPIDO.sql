-- =====================================================================
-- CONSULTA 3 — Pedidos en un rango de fechas con detalle de productos
-- VERSIÓN RÁPIDA (índice B-Tree sobre fecha_hora)
--
-- Problema identificado en la versión lenta:
--   Sin índice en fecha_hora, PostgreSQL recorría las 200.000 filas
--   de pedido completas y descartaba 189.171 para encontrar ~10.829.
--   Eso arrastraba Seq Scans en cadena sobre detalle_pedido, cliente
--   y producto, con 2 workers paralelos y 162 ms de ejecución.
--
-- Solución aplicada:
--   Un índice B-Tree sobre fecha_hora permite a PostgreSQL hacer un
--   Index Scan directo al rango solicitado, saltando las filas fuera
--   del intervalo sin leerlas. Con el dataset acotado desde el inicio,
--   los joins siguientes trabajan sobre muchas menos filas.
-- =====================================================================

-- Paso 1: crear el índice sobre fecha_hora
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_hora
    ON pedido (fecha_hora);

-- =====================================================================
-- Paso 2: ejecutar la consulta y medir el nuevo plan
-- =====================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    cl.nombre || ' ' || cl.apellido      AS cliente,
    pr.nombre                            AS producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.cantidad * dp.precio_unitario     AS subtotal
FROM pedido p
JOIN cliente cl        ON cl.id_cliente  = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido   = p.id_pedido
JOIN producto pr       ON pr.id_producto = dp.id_producto
WHERE p.fecha_hora BETWEEN '2026-08-01' AND '2026-09-09'
ORDER BY p.fecha_hora DESC;

-- =====================================================================
-- PLAN OBTENIDO (EXPLAIN ANALYZE - DESPUÉS DE OPTIMIZAR)
--
-- Execution Time: 87.433 ms (antes: 162.459 ms) → mejora del 46%
--
-- Cambio clave en el plan:
--   El Parallel Seq Scan on pedido que recorría 200.000 filas y
--   descartaba 189.171 fue reemplazado por un Bitmap Index Scan on
--   idx_pedido_fecha_hora que leyó solo 10.829 filas del rango.
--   Los buffers de pedido bajaron de 1471 (solo hit) a 1473 hit+30 read,
--   siendo los 30 read el costo de leer el índice desde disco por
--   primera vez — algo que desaparece en ejecuciones siguientes.
--   Los joins con detalle_pedido, cliente y producto se mantienen
--   con Seq Scan porque esas tablas no tienen filtros selectivos,
--   pero al acotar pedido desde el inicio el plan general es más rápido.
-- =====================================================================
