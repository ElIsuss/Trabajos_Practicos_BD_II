#Bloque EXPLAIN ANALYZE Consulta 2 antes de la optmización:
                                                                                   QUERY PLAN

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------
 Limit  (cost=59779.19..59779.24 rows=20 width=62) (actual time=743.671..783.586 rows=20.00 loops=1)
   Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
   ->  Sort  (cost=59779.19..59904.19 rows=50000 width=62) (actual time=743.670..783.582 rows=20.00 loops=1)
         Sort Key: (sum(dp.cantidad)) DESC
         Sort Method: top-N heapsort  Memory: 27kB
         Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
         ->  Finalize GroupAggregate  (cost=42647.73..58448.71 rows=50000 width=62) (actual time=620.588..775.157 rows=50000.00 loops=1)
               Group Key: pr.id_producto
               Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
               ->  Gather Merge  (cost=42647.73..56623.71 rows=120000 width=62) (actual time=620.574..700.518 rows=146696.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
                     ->  Sort  (cost=41647.71..41772.71 rows=50000 width=62) (actual time=528.748..537.696 rows=48898.67 loops=3)
                           Sort Key: pr.id_producto
                           Sort Method: external merge  Disk: 5288kB
                           Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
                           Worker 0:  Sort Method: external merge  Disk: 5152kB
                           Worker 1:  Sort Method: external merge  Disk: 5192kB
                           ->  Partial HashAggregate  (cost=31822.32..35862.30 rows=50000 width=62) (actual time=352.792..475.213 rows=48898.67 loops=3)
                                 Group Key: pr.id_producto
                                 Planned Partitions: 4  Batches: 5  Memory Usage: 8241kB  Disk Usage: 7752kB
                                 Buffers: shared hit=2404 read=4902, temp read=2181 written=4379
                                 Worker 0:  Batches: 5  Memory Usage: 8241kB  Disk Usage: 7144kB
                                 Worker 1:  Batches: 5  Memory Usage: 8241kB  Disk Usage: 7264kB
                                 ->  Hash Join  (cost=1895.00..10044.54 rows=249781 width=32) (actual time=34.638..174.114 rows=199825.00 loops=3)
                                       Hash Cond: (dp.id_producto = pr.id_producto)
                                       Buffers: shared hit=2404 read=4902
                                       ->  Parallel Seq Scan on detalle_pedido dp  (cost=0.00..7493.81 rows=249781 width=18) (actual time=1.090..24.299 rows=199825.
00 loops=3)
                                             Buffers: shared hit=94 read=4902
                                       ->  Hash  (cost=1270.00..1270.00 rows=50000 width=22) (actual time=33.170..33.171 rows=50000.00 loops=3)
                                             Buckets: 65536  Batches: 1  Memory Usage: 3187kB
                                             Buffers: shared hit=2310
                                             ->  Seq Scan on producto pr  (cost=0.00..1270.00 rows=50000 width=22) (actual time=0.748..15.712 rows=50000.00 loops=3)
                                                   Buffers: shared hit=2310
 Planning:
   Buffers: shared hit=18 read=1
 Planning Time: 0.834 ms
 Execution Time: 806.504 ms
(39 rows)


# Después de la optimización:
   QUERY PLAN

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------
 Limit  (cost=50725.69..50725.74 rows=20 width=62) (actual time=652.403..652.407 rows=20.00 loops=1)
   Buffers: shared hit=600306
   ->  Sort  (cost=50725.69..50850.69 rows=50000 width=62) (actual time=652.402..652.405 rows=20.00 loops=1)
         Sort Key: (sum(dp.cantidad)) DESC
         Sort Method: top-N heapsort  Memory: 27kB
         Buffers: shared hit=600306
         ->  GroupAggregate  (cost=0.80..49395.21 rows=50000 width=62) (actual time=0.050..643.518 rows=50000.00 loops=1)
               Group Key: pr.id_producto
               Buffers: shared hit=600306
               ->  Merge Join  (cost=0.80..41276.77 rows=599475 width=32) (actual time=0.023..437.824 rows=599475.00 loops=1)
                     Merge Cond: (dp.id_producto = pr.id_producto)
                     Buffers: shared hit=600306
                     ->  Index Scan using idx_detalle_pedido_id_producto on detalle_pedido dp  (cost=0.42..31580.53 rows=599475 width=18) (actual time=0.012..300.08
1 rows=599475.00 loops=1)
                           Index Searches: 1
                           Buffers: shared hit=599398
                     ->  Index Scan using producto_pkey on producto pr  (cost=0.29..2079.29 rows=50000 width=22) (actual time=0.008..11.194 rows=50000.00 loops=1)
                           Index Searches: 1
                           Buffers: shared hit=908
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.357 ms
 Execution Time: 652.446 ms
(22 rows)


## Consulta 3: Ranking de clientes por gasto

### Antes de crear `idx_detalle_pedido_id_pedido`

El plan realizaba escaneos secuenciales sobre las tablas involucradas:

```text
Parallel Seq Scan on detalle_pedido dp
Parallel Seq Scan on pedido p
Seq Scan on cliente c
Planning Time: 35.567 ms
Execution Time: 388.309 ms
```

Los JOIN se resolvieron mediante `Parallel Hash Join` y `Hash Join`. La consulta procesa gran parte de las filas de `detalle_pedido` y `pedido` para calcular el gasto acumulado de todos los clientes.

### Después de crear `idx_detalle_pedido_id_pedido`

Índice evaluado:

```sql
CREATE INDEX idx_detalle_pedido_id_pedido
ON detalle_pedido (id_pedido);
```

El plan posterior continuó usando escaneos secuenciales:

```text
Parallel Seq Scan on detalle_pedido dp
Parallel Seq Scan on pedido p
Seq Scan on cliente c
Planning Time: 1.570 ms
Execution Time: 295.607 ms
```

### Resultado de la medición

El tiempo de ejecución bajó de `388.309 ms` a `295.607 ms`, pero el plan no pasó a `Index Scan` ni a `Bitmap Heap Scan` y no utilizó `idx_detalle_pedido_id_pedido`. Por lo tanto, la reducción de tiempo no puede atribuirse al índice: la segunda ejecución tuvo más páginas en caché (`shared hit`) y menos lecturas de disco.

Este resultado muestra que, para una consulta agregada que necesita recorrer casi todas las filas, un índice sobre `detalle_pedido(id_pedido)` no resulta conveniente según el plan elegido por PostgreSQL.

## Consulta: Histórico de Pedidos Recientes por Cliente

### Resumen de Impacto
- **Plan Anterior:** `Bitmap Index Scan` sobre `idx_pedido_id_cliente` + `Filter` + `Sort (quicksort)`
- **Plan Nuevo:** `Bitmap Index Scan` sobre `idx_pedido_cliente_fecha`
- **Tiempo de Ejecución:** Reducción de **15.38 ms** a **0.17 ms** (~92.6× más rápido)
- **Índice Creado:** `CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha_hora DESC);`

---

### 1. EXPLAIN ANALYZE — Antes de la Optimización
```sql
Sort  (cost=42.11..42.11 rows=2 width=24) (actual time=15.283..15.284 rows=0.00 loops=1)
   Sort Key: fecha_hora DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=6 read=12
   ->  Bitmap Heap Scan on pedido p  (cost=4.37..42.10 rows=2 width=24) (actual time=7.813..7.813 rows=0.00 loops=1)
         Recheck Cond: (id_cliente = 1500)
         Filter: (fecha_hora >= (now() - '180 days'::interval))
         Rows Removed by Filter: 11
         Heap Blocks: exact=10
         Buffers: shared hit=3 read=12
         ->  Bitmap Index Scan on idx_pedido_id_cliente  (cost=0.00..4.37 rows=10 width=0) (actual time=0.473..0.473 rows=11.00 loops=1)
               Index Cond: (id_cliente = 1500)
               Index Searches: 1
               Buffers: shared hit=3 read=2
Planning Time: 19.325 ms
Execution Time: 15.382 ms
2. EXPLAIN ANALYZE — Después de la Optimización (idx_pedido_cliente_fecha)

Sort  (cost=12.27..12.28 rows=2 width=24) (actual time=0.136..0.137 rows=0.00 loops=1)
   Sort Key: fecha_hora DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared read=3
   ->  Bitmap Heap Scan on pedido p  (cost=4.45..12.26 rows=2 width=24) (actual time=0.131..0.131 rows=0.00 loops=1)
         Recheck Cond: ((id_cliente = 1500) AND (fecha_hora >= (now() - '180 days'::interval)))
         Buffers: shared read=3
         ->  Bitmap Index Scan on idx_pedido_cliente_fecha  (cost=0.00..4.44 rows=2 width=0) (actual time=0.113..0.113 rows=0.00 loops=1)
               Index Cond: ((id_cliente = 1500) AND (fecha_hora >= (now() - '180 days'::interval)))
               Index Searches: 1
               Buffers: shared read=3
Planning Time: 2.176 ms
Execution Time: 0.166 ms

## Parte C: Vista materializada de facturacion por categoria y mes

### Consulta original

La consulta original de facturacion historica por categoria y mes obtuvo un tiempo de ejecucion de `423.323 ms`.

### Consulta sobre la vista materializada

Se creo `mv_facturacion_categoria_mes` con `WITH DATA` y el indice unico `idx_mv_facturacion_categoria_mes (categoria, mes)`, que permite futuros refrescos concurrentes.

```text
Sort  (actual time=0.082..0.089 rows=250 loops=1)
  Sort Key: mes, facturacion_total DESC
  -> Seq Scan on mv_facturacion_categoria_mes
     (actual time=0.030..0.042 rows=250 loops=1)
Planning Time: 5.327 ms
Execution Time: 0.107 ms
```

El `Seq Scan` sobre la vista materializada es adecuado: solo contiene 250 filas agregadas y utiliza 4 paginas en cache. Consultar la vista materializada redujo el tiempo de `423.323 ms` a `0.107 ms`.

### Frecuencia de refresco

Se propone ejecutar `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes` una vez por dia, al cierre de la jornada. El reporte no mostrara ventas incorporadas despues del ultimo refresco hasta que se ejecute el siguiente; a cambio, las consultas de lectura no quedan bloqueadas durante el refresco.
=======


