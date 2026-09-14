-- =====================================================================
-- CONSULTA 2 — Historial de pedidos buscando cliente por apellido
-- VERSIÓN LENTA (búsqueda por texto parcial con ILIKE)
--
-- Por qué es lenta:
--   · ILIKE '%Apellido150%' no puede usar ningún índice (B-Tree)
--   · Fuerza un Seq Scan completo sobre las 20.000 filas de cliente
--   · Luego hace join con pedido (200.000 filas) y detalle_pedido (~500.000)
--   · El patrón con % al inicio impide cualquier optimización de índice
-- =====================================================================

-- =====================================================================
-- PLAN OBTENIDO (EXPLAIN ANALYZE - ANTES DE OPTIMIZAR)
--
-- Execution Time: 46.238 ms
--
-- El problema principal está en dos Seq Scans:
--   1. cliente: recorre las 20.000 filas completas para filtrar por
--      apellido con ILIKE '%Apellido150%', descartando 19.889 filas.
--      Un índice B-Tree normal no sirve cuando el patrón empieza con %.
--   2. pedido: recorre las 200.000 filas en paralelo para hacer el join
--      con los clientes encontrados.
-- El resto del plan (join con detalle_pedido, agrupación y sort) es
-- costoso pero secundario — el cuello de botella real es el Seq Scan
-- sobre cliente que no puede evitarse sin un índice de trigramas.
-- =====================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    cl.nombre || ' ' || cl.apellido        AS cliente,
    COUNT(dp.id_detalle_pedido)            AS cantidad_items,
    SUM(dp.cantidad * dp.precio_unitario)  AS total_pedido
FROM pedido p
JOIN cliente cl        ON cl.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido  = p.id_pedido
WHERE cl.apellido ILIKE '%Apellido150%'
GROUP BY p.id_pedido, p.fecha_hora, p.forma_pago, cl.nombre, cl.apellido
ORDER BY p.fecha_hora DESC;
