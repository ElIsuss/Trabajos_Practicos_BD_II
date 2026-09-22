-- =====================================================================
-- PLAN DE INDEXADO - FOOD STORE (Parte A)
-- =====================================================================

-- Consulta 2: Productos más vendidos
-- Reemplaza Parallel Seq Scan sobre detalle_pedido por Index Scan / Merge Join
CREATE INDEX idx_detalle_pedido_id_producto ON detalle_pedido (id_producto);

-- Consulta 3: Ranking de clientes por gasto
-- Reemplaza Parallel Seq Scan sobre pedido en el JOIN por Index Scan / Hash Join eficiente
CREATE INDEX idx_pedido_id_cliente ON pedido (id_cliente);
