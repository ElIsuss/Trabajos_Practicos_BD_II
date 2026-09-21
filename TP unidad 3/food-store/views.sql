-- =====================================================================
-- VISTAS DE REPORTES - FOOD STORE
-- Motor: PostgreSQL 16+
-- Documentación: specs/vistas_reportes.md
-- Dependencia: requiere seguridad_usuario.sql (tabla usuario,
-- columna pedido.estado).
-- =====================================================================

-- ---------------------------------------------------------------
-- 1. v_productos_vigentes
-- Productos vigentes (activo = TRUE) con su categoría.
-- El esquema real usa producto.precio_actual como precio vigente;
-- se expone con el alias precio_unitario requerido por la spec.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT
    p.id_producto,
    p.nombre         AS nombre_producto,
    p.precio_actual  AS precio_unitario,
    c.nombre         AS nombre_categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE;

-- ---------------------------------------------------------------
-- 2. v_pedidos_usuario (Criterio de Seguridad)
-- Pedidos de cada usuario con su total y estado.
-- REGLA DE SEGURIDAD: se une con la tabla usuario (que posee la
-- credencial) pero la proyección es una LISTA BLANCA explícita:
-- NUNCA se selecciona usuario.contrasena ni columnas internas.
-- total = SUM(cantidad * precio_unitario); LEFT JOIN + COALESCE
-- evita perder pedidos sin detalle.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_usuario AS
SELECT
    pe.id_pedido,
    pe.fecha_hora,
    COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0) AS total,
    pe.estado,
    cl.id_cliente,
    cl.nombre,
    cl.apellido,
    cl.correo_electronico AS email
FROM pedido pe
JOIN cliente cl              ON cl.id_cliente  = pe.id_cliente
JOIN usuario us              ON us.id_cliente  = cl.id_cliente
LEFT JOIN detalle_pedido dp  ON dp.id_pedido   = pe.id_pedido
GROUP BY
    pe.id_pedido, pe.fecha_hora, pe.estado,
    cl.id_cliente, cl.nombre, cl.apellido, cl.correo_electronico;

-- ---------------------------------------------------------------
-- 3. v_detalle_pedido_completo
-- Líneas de detalle con el nombre del producto y subtotal calculado.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedido_completo AS
SELECT
    dp.id_pedido,
    dp.id_producto,
    pr.nombre                       AS nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto;