# Spec: materializada_facturacion_categoria_mes

## Objetivo

Acelerar el reporte historico de facturacion por categoria y mes mediante una vista materializada.

## Consulta base

```sql
SELECT
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha_hora) AS mes,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha_hora)
ORDER BY mes, facturacion_total DESC;
```

## Resultado esperado

La vista debe contener una fila por cada combinacion de categoria y mes, con el importe total facturado en ese periodo.

## Requisitos tecnicos

- Crear la vista materializada con `WITH DATA`.
- Crear un indice unico sobre `(categoria, mes)` para permitir futuros `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- Mantener la misma logica y los mismos resultados que la consulta base.

## Criterios de aceptacion

- La consulta sobre la vista materializada debe devolver los mismos resultados que la consulta base.
- Se debe medir con `EXPLAIN (ANALYZE, BUFFERS)` el tiempo de la consulta base y de la vista materializada.
- El tiempo de referencia de la consulta base es `423.323 ms`.
- Se debe documentar una frecuencia de refresco y el impacto de que el reporte no se actualice en tiempo real.
