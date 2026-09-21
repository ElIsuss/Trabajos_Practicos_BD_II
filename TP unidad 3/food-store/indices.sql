-- Consulta 2: Top 20 Productos más vendidos
-- Reemplaza Parallel Seq Scan sobre detalle_pedido por Index Scan / Merge Join
CREATE INDEX idx_detalle_pedido_id_producto ON detalle_pedido (id_producto);