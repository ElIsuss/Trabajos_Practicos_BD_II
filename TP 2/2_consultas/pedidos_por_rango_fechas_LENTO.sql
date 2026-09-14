-- =====================================================================
-- CONSULTA 3 — Pedidos en un rango de fechas con detalle de productos
-- VERSIÓN LENTA (sin índice en fecha_hora)
--
-- Por qué es lenta:
--   · Filtra por fecha_hora sobre 200.000 filas sin índice en esa columna
--   · Fuerza un Seq Scan completo sobre pedido para evaluar cada fila
--   · Luego hace joins con detalle_pedido (~500.000 filas) y producto
--   · El rango de 1 mes devuelve muchas filas → Sort final muy costoso
-- =====================================================================

-- =====================================================================
-- PLAN OBTENIDO (EXPLAIN ANALYZE - ANTES DE OPTIMIZAR)
--
-- Execution Time: 162.459 ms
--
-- El problema principal está en el Seq Scan sobre pedido:
--   Sin índice en fecha_hora, PostgreSQL recorre las 200.000 filas
--   completas y descarta 189.171 para quedarse con ~10.829 del rango.
--   Además arrastra ese costo a todos los joins siguientes:
--   detalle_pedido se escanea completo (~600.000 filas en paralelo),
--   y cliente y producto también se leen enteros para construir
--   las tablas hash del join.
--   El Sort final sobre 32.449 filas usa 2.5 MB de memoria.
--   Todo el trabajo paralelo (2 workers) es consecuencia directa
--   de no poder acotar el dataset desde el principio con un índice.
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
