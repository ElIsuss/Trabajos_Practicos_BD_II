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