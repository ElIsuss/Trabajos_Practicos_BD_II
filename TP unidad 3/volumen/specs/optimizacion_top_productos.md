# Spec: optimizacion_top_productos

## Objetivo
Acelerar la consulta analítica "Top 20 productos más vendidos", la cual actualmente ejecuta un `Parallel Seq Scan` sobre la tabla `detalle_pedido` demorando más de 800 ms.

## Consulta Afectada
```sql
SELECT
    pr.id_producto,
    pr.nombre                             AS producto,
    SUM(dp.cantidad)                      AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario) AS ingreso_generado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY total_vendido DESC
LIMIT 20;
```

## Columnas Candidatas
- `detalle_pedido.id_producto`: Clave foránea utilizada en la condición de JOIN con la tabla `producto`.

## Criterio de Aceptación
- Proponer un índice que optimice el acoplamiento (JOIN) entre `detalle_pedido` y `producto`.
- El plan de ejecución debe reemplazar el `Parallel Seq Scan` sobre `detalle_pedido` por un acceso indexado (`Index Scan` o `Bitmap Heap Scan`).
- Reducir el tiempo de ejecución medido con `EXPLAIN ANALYZE`.
