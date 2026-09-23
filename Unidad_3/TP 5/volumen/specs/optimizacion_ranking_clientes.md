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
- `pedido.id_cliente`: Clave foránea utilizada en la condición de JOIN con `cliente`.
- `detalle_pedido.id_pedido`: Clave foránea utilizada en la condición de JOIN con `pedido`.

## Criterio de Aceptación
- Proponer un índice que optimice las operaciones de acoplamiento (JOIN).
- Reducir los escaneos secuenciales masivos y el tiempo de ejecución medido con `EXPLAIN ANALYZE`.
