-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: tp_desnormalizacion_top_categorias.sql
-- Unidad 4 — Parte 2: Desnormalización controlada
-- Motor: PostgreSQL 17 — base foodstore_trabajo
-- =====================================================================

-- =====================================================================
-- NOTA DE ADAPTACIÓN AL SCHEMA REAL
-- La consulta del enunciado utiliza nombres de columna que difieren
-- del schema original del proyecto. Se aplicaron los siguientes ajustes:
--
--   pr.id          → pr.id_producto
--   c.id           → c.id_categoria
--   ped.id         → ped.id_pedido
--   dp.producto_id → dp.id_producto
--   dp.pedido_id   → dp.id_pedido
--   dp.subtotal    → dp.cantidad * dp.precio_unitario
--   ped.fecha      → ped.fecha_hora::date  (la columna es TIMESTAMPTZ)
--
-- Las columnas dp.eliminado y ped.eliminado fueron agregadas al schema
-- mediante ALTER TABLE (ver backup_2026-10-08_1800.sql) para representar
-- el borrado lógico requerido por el enunciado.
-- La lógica de negocio es idéntica a la descripta en el enunciado.
-- =====================================================================


-- =====================================================================
-- PUNTO (a) — Consulta original con EXPLAIN ANALYZE
-- =====================================================================

EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr  ON pr.id_producto = dp.id_producto
JOIN categoria c  ON c.id_categoria = pr.id_categoria
JOIN pedido ped   ON ped.id_pedido  = dp.id_pedido
WHERE ped.fecha_hora::date = CURRENT_DATE
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;


-- =====================================================================
-- PUNTO (c) — Implementación de la vista materializada
-- =====================================================================

-- Estructura desnormalizada: precalcula el total vendido por
-- categoría y día, evitando los cuatro JOINs en cada lectura.
-- El filtro de borrado lógico se aplica al momento del precálculo.
CREATE MATERIALIZED VIEW mv_top_categorias_dia AS
SELECT
    c.nombre                                    AS categoria,
    ped.fecha_hora::date                        AS fecha,
    SUM(dp.cantidad * dp.precio_unitario)       AS total_vendido
FROM detalle_pedido dp
JOIN producto pr  ON pr.id_producto = dp.id_producto
JOIN categoria c  ON c.id_categoria = pr.id_categoria
JOIN pedido ped   ON ped.id_pedido  = dp.id_pedido
WHERE dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha_hora::date
WITH DATA;

-- Índice único sobre (fecha, categoria):
--   · permite REFRESH MATERIALIZED VIEW CONCURRENTLY sin bloquear lecturas
--   · acelera las consultas filtradas por fecha
CREATE UNIQUE INDEX idx_mv_top_categorias_dia
    ON mv_top_categorias_dia (fecha, categoria);

-- Mecanismo de sincronización:
-- Ejecutar al comienzo de cada día (vía pg_cron o llamada explícita)
-- para regenerar el dato desde las tablas fuente sin bloquear lecturas.
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_categorias_dia;


-- =====================================================================
-- PUNTO (d) — Consulta sobre la estructura desnormalizada
-- =====================================================================

EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_top_categorias_dia
WHERE fecha = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;


-- =====================================================================
-- PUNTO (e) — Script de auditoría
-- Detecta si el dato redundante se desincronizó de su fuente de verdad.
-- El resultado debe ser vacío sobre una vista recién refrescada.
-- =====================================================================

SELECT
    fuente.categoria,
    fuente.fecha,
    fuente.total_vendido                        AS total_fuente,
    mv.total_vendido                            AS total_mv,
    fuente.total_vendido - mv.total_vendido     AS diferencia
FROM (
    SELECT
        c.nombre                              AS categoria,
        ped.fecha_hora::date                  AS fecha,
        SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.id_producto
    JOIN categoria c  ON c.id_categoria = pr.id_categoria
    JOIN pedido ped   ON ped.id_pedido   = dp.id_pedido
    WHERE dp.eliminado  = FALSE
      AND ped.eliminado = FALSE
    GROUP BY c.nombre, ped.fecha_hora::date
) AS fuente
JOIN mv_top_categorias_dia mv
    ON mv.categoria = fuente.categoria
    AND mv.fecha    = fuente.fecha
WHERE fuente.total_vendido <> mv.total_vendido;
