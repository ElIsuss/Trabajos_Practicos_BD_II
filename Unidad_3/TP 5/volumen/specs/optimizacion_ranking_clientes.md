# Spec: optimizacion_ranking_clientes

## Objetivo
Acelerar la consulta analítica "Ranking de clientes por gasto", la cual ejecuta `Parallel Seq Scan` sobre `pedido`, `detalle_pedido` y `cliente`, demorando más de 600 ms.

## Consulta Afectada
```sql
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido         AS cliente,
    SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
    DENSE_RANK() OVER (
        ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC
    )                                     AS puesto
FROM cliente c
JOIN pedido p          ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON p.id_pedido  = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY puesto;
```

## Columnas Candidatas
- `pedido.id_cliente`: clave foránea en el JOIN con `cliente`.
- `detalle_pedido.id_pedido`: clave foránea en el JOIN con `pedido`.

## Criterio de Aceptación
- Los índices propuestos deben aparecer en el plan de EXPLAIN ANALYZE.
- El plan debe dejar de usar Parallel Seq Scan sobre las tablas afectadas.
- El tiempo de ejecución debe reducirse de forma observable.

## Resultado de la Evaluación — ÍNDICES DESCARTADOS

OpenCode propuso:
- `CREATE INDEX idx_pedido_id_cliente ON pedido (id_cliente)`
- `CREATE INDEX idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)`

Ambos fueron creados y medidos con EXPLAIN ANALYZE. El plan no utilizó ninguno de los dos:
la consulta agrega la totalidad de las filas de las dos tablas, por lo que el optimizador
prefiere Parallel Seq Scan sobre un acceso indexado.

Motivos del descarte:
1. `idx_pedido_id_cliente` es redundante con `idx_pedido_cliente` ya presente en
   `schema_completo.sql` (misma columna, mismo tipo B-tree): duplica el costo de
   mantenimiento sin aportar ningún acceso nuevo.
2. `idx_detalle_pedido_id_pedido` no modifica la estrategia de una agregación global:
   el optimizador lo ignora y sigue con Seq Scan.

Ninguno quedó en `indices.sql`. Detalle completo en `informe_mediciones.md` (sección A.2).
