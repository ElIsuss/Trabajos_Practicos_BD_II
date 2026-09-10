-- =====================================================================
-- CONSULTA 2 — Historial de pedidos buscando cliente por apellido
-- VERSIÓN RÁPIDA (índice de trigramas sobre apellido)
--
-- Problema identificado en la versión lenta:
--   ILIKE '%Apellido150%' no puede usar índices B-Tree porque el patrón
--   empieza con %. PostgreSQL tenía que recorrer las 20.000 filas de
--   cliente una por una para evaluar el filtro.
--
-- Solución aplicada:
--   1. Se habilita la extensión pg_trgm, que permite indexar texto
--      para búsquedas parciales con LIKE/ILIKE en cualquier posición.
--   2. Se crea un índice GIN sobre apellido usando gin_trgm_ops.
--      Con este índice, PostgreSQL puede hacer un Bitmap Index Scan
--      en lugar del Seq Scan, reduciendo drásticamente las filas leídas.
-- =====================================================================

-- Paso 1: habilitar la extensión (solo necesario una vez por base)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Paso 2: crear el índice de trigramas sobre apellido
CREATE INDEX IF NOT EXISTS idx_cliente_apellido_trgm
    ON cliente USING GIN (apellido gin_trgm_ops);

-- =====================================================================
-- Paso 3: ejecutar la consulta y medir el nuevo plan
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

-- =====================================================================
-- PLAN OBTENIDO (EXPLAIN ANALYZE - DESPUÉS DE OPTIMIZAR)
--
-- Execution Time: 31.891 ms (antes: 46.238 ms) → mejora del 31%
--
-- Cambio clave en el plan:
--   El Seq Scan on cliente que recorría 20.000 filas y descartaba
--   19.889 fue reemplazado por un Bitmap Index Scan on idx_cliente_apellido_trgm
--   que leyó solo 112 filas candidatas y descartó 1 en el recheck.
--   Los buffers de cliente bajaron de 570 a 128 (78% menos lecturas).
--   El Parallel Seq Scan on pedido se mantiene porque no hay forma
--   de evitarlo sin conocer los id_cliente de antemano, pero al
--   reducir el lado del hash build (cliente) el join es más rápido.
-- =====================================================================
