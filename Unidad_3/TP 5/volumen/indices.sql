-- =====================================================================
-- PLAN DE INDEXADO - FOOD STORE (Parte A)
-- Sentencias CREATE INDEX finalmente ACEPTADAS.
-- El detalle de mediciones y de los descartes está en
-- informe_mediciones.md y las especificaciones en specs/*.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- ÍNDICES ACEPTADOS
-- ---------------------------------------------------------------------

-- Consulta 2: Productos más vendidos (specs/optimizacion_top_productos.md)
-- Reemplaza el Parallel Seq Scan sobre detalle_pedido por un Index Scan
-- (Merge Join) en el JOIN detalle_pedido ⋈ producto.
CREATE INDEX idx_detalle_pedido_id_producto ON detalle_pedido (id_producto);

-- Consulta 4: Pedidos recientes por cliente (specs/optimizacion_busquedas_recientes.md)
-- Cubre el filtro id_cliente = ? + rango fecha_hora y elimina el Sort
-- explícito (fecha_hora DESC).
CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha_hora DESC);

-- ---------------------------------------------------------------------
-- ÍNDICES PROPUESTOS POR LA IA Y DESCARTADOS (sobreindexación)
-- NO crear. Justificación completa en informe_mediciones.md (Parte A).
-- ---------------------------------------------------------------------
--
-- 1) idx_pedido_id_cliente ON pedido (id_cliente)
--    REDUNDANTE: el esquema base ya posee idx_pedido_cliente ON pedido
--    (id_cliente) (schema_completo.sql). Misma columna y mismo tipo de
--    índice B-tree: duplica el mantenimiento de escrituras sin aportar
--    ningún acceso nuevo. DESCARTADO.
--
-- 2) idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)
--    INEFECTIVO para la Consulta 3 (Ranking de clientes por gasto):
--    medido con EXPLAIN ANALYZE, el plan sigue usando Parallel Seq Scan
--    sobre detalle_pedido y pedido; el índice no figura en el plan y no
--    cambia la estrategia de agregación global. DESCARTADO.
--
-- Propuestas originales (solo para registro del duia.md):
--   CREATE INDEX idx_pedido_id_cliente ON pedido (id_cliente);
--   CREATE INDEX idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido);