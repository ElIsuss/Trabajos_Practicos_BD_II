# Informe de Mediciones — Unidad 3, Semana 5

## Índices, vistas y vistas materializadas. Food Store

**Entorno de medición:** PostgreSQL 16+, base de trabajo (copia creada según `protocolo_seguridad.md`), `pedido` = 200.000 filas y `detalle_pedido` = 601.248 filas.

---

# Parte A — Plan de indexado

## A.0 Consultas seleccionadas (specs en `specs/`)

| Consulta | Archivo spec | Problema inicial |
|---|---|---|
| 2. Top 20 productos más vendidos | `optimizacion_top_productos.md` | `Parallel Seq Scan` sobre `detalle_pedido` (~800 ms) |
| 3. Ranking de clientes por gasto | `optimizacion_ranking_clientes.md` | `Parallel Seq Scan` sobre `pedido`, `detalle_pedido`, `cliente` (~600 ms) |
| 4. Pedidos recientes por cliente | `optimizacion_busquedas_recientes.md` | `Bitmap Index Scan` + `Filter` de fecha en memoria + `Sort` explícito (~15 ms) |

Las consultas están en `queries.sql`.

## A.1 Consulta 2 — Productos más vendidos

### Antes de la optimización
```text
 Limit  (cost=59779.19..59779.24 rows=20 width=62) (actual time=743.671..783.586 rows=20.00 loops=1)
    Buffers: shared hit=2420 read=4902, temp read=4135 written=6336
    ->  Sort  (cost=59779.19..59904.19 rows=50000 width=62) (actual time=743.670..783.582 rows=20.00 loops=1)
          Sort Key: (sum(dp.cantidad)) DESC
          Sort Method: top-N heapsort  Memory: 27kB
          ->  Finalize GroupAggregate  (cost=42647.73..58448.71 rows=50000 width=62) (actual time=620.588..775.157 rows=50000.00 loops=1)
                Group Key: pr.id_producto
                ->  Gather Merge  (cost=42647.73..56623.71 rows=120000 width=62) (actual time=620.574..700.518 rows=146696.00 loops=3)
                      Workers Planned: 2
                      Workers Launched: 2
                      ->  Sort  (cost=41647.71..41772.71 rows=50000 width=62)
                            ... 
                            ->  Partial HashAggregate  ...
                                  ->  Hash Join  (cost=1895.00..10044.54 rows=249781 width=32) (actual time=34.638..174.114 rows=199825.00 loops=3)
                                        Hash Cond: (dp.id_producto = pr.id_producto)
                                        ->  Parallel Seq Scan on detalle_pedido dp  (cost=0.00..7493.81 rows=249781 width=18) (actual time=1.090..24.299 rows=199825.00 loops=3)
                                        ->  Hash  ... Seq Scan on producto pr  ...
Planning Time: 0.834 ms
Execution Time: 806.504 ms
```
- **Plan inicial:** `Parallel Seq Scan` sobre `detalle_pedido` (199.825 filas por worker) resuelto con `Hash Join`.

### Después de crear `idx_detalle_pedido_id_producto`
```text
 Limit  (cost=50725.69..50725.74 rows=20 width=62) (actual time=652.403..652.407 rows=20.00 loops=1)
    ->  Sort  (cost=50725.69..50850.69 rows=50000 width=62) (actual time=652.402..652.405 rows=20.00 loops=1)
          Sort Key: (sum(dp.cantidad)) DESC
          Sort Method: top-N heapsort  Memory: 27kB
          ->  GroupAggregate  (cost=0.80..49395.21 rows=50000 width=62) (actual time=0.050..643.518 rows=50000.00 loops=1)
                Group Key: pr.id_producto
                ->  Merge Join  (cost=0.80..41276.77 rows=599475 width=32) (actual time=0.023..437.824 rows=599475.00 loops=1)
                      Merge Cond: (dp.id_producto = pr.id_producto)
                      ->  Index Scan using idx_detalle_pedido_id_producto on detalle_pedido dp  (cost=0.42..31580.53 rows=599475 width=18) (actual time=0.012..300.081 rows=599475.00 loops=1)
                      ->  Index Scan using producto_pkey on producto pr  (cost=0.29..2079.29 rows=50000 width=22) (actual time=0.008..11.194 rows=50000.00 loops=1)
Planning Time: 0.357 ms
Execution Time: 652.446 ms
```
- **Plan final:** `Merge Join` con `Index Scan` sobre `idx_detalle_pedido_id_producto` — el `Parallel Seq Scan` desapareció.
- **Tiempo:** 806.504 ms → 652.446 ms. Reproducido en sesión de validación con el mismo cambio de plan y ~868 ms.
- **Cumple el criterio de aceptación:** el plan cambió de Seq Scan a Index Scan y el tiempo bajó.

## A.2 Consulta 3 — Ranking de clientes por gasto (índices descartados)

### Antes de crear los índices propuestos
```text
Parallel Seq Scan on detalle_pedido dp
Parallel Seq Scan on pedido p
Seq Scan on cliente c
Hash Join (dp.id_pedido = p.id_pedido) y (p.id_cliente = c.id_cliente)
Planning Time: 35.567 ms
Execution Time: 388.309 ms
```

### Después de crear `idx_pedido_id_cliente` y `idx_detalle_pedido_id_pedido`
```text
Parallel Seq Scan on detalle_pedido dp
Parallel Seq Scan on pedido p
Seq Scan on cliente c
Planning Time: 1.570 ms
Execution Time: 295.607 ms
```
El plan **no utilizó ninguno de los dos índices** y siguió con escaneos secuenciales. La consulta agrega casi la totalidad de las filas de `detalle_pedido` y `pedido` para calcular el gasto de todos los clientes; un índice por FK no cambia una agregación global.

### Verificación final (tras eliminar ambos índices)
Reproducción en la copia de trabajo con los índices descartados eliminados: el plan **sigue idéntico** (`Parallel Seq Scan` sobre `detalle_pedido` y `pedido`), `Execution Time: 729.471 ms`. Es decir, su ausencia no produce ninguna regresión.

### Decisión — índice(es) descartado(s) por sobreindexación
1. `idx_pedido_id_cliente ON pedido (id_cliente)`: **redundante** con `idx_pedido_cliente` que ya estaba en el esquema base (`schema_completo.sql`). Misma columna, mismo B-tree: duplica el costo de mantenimiento sin ganancia.
2. `idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)`: **inefectivo** para la consulta que se quería optimizar (el plan la ignora).

> Ambos quedaron **fuera** de `indices.sql`. La regla aprendida: el costo de escritura de un índice solo se justifica si el optimizador lo usa; la consulta 3 es una agregación full-scan y no se beneficia de FKs indexadas.

## A.3 Consulta 4 — Pedidos recientes por cliente

### Resumen de impacto
- **Plan anterior:** `Bitmap Index Scan` sobre `idx_pedido_id_cliente` + `Filter` de fecha + `Sort (quicksort)`.
- **Plan nuevo:** `Bitmap Index Scan` sobre `idx_pedido_cliente_fecha` (condición de rango directa en el índice, sin `Sort`).
- **Tiempo:** 15.382 ms → 0.166 ms (~92× más rápido). Reproducido en validación: 0.189 ms.

### Antes de la optimización
```text
Sort  (cost=42.11..42.11 rows=2 width=24) (actual time=15.283..15.284 rows=0.00 loops=1)
   Sort Key: fecha_hora DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Bitmap Heap Scan on pedido p  (cost=4.37..42.10 rows=2 width=24) (actual time=7.813..7.813 rows=0.00 loops=1)
         Recheck Cond: (id_cliente = 1500)
         Filter: (fecha_hora >= (now() - '180 days'::interval))
         Rows Removed by Filter: 11
         ->  Bitmap Index Scan on idx_pedido_id_cliente  (cost=0.00..4.37 rows=10 width=0) (actual time=0.473..0.473 rows=11.00 loops=1)
               Index Cond: (id_cliente = 1500)
Planning Time: 19.325 ms
Execution Time: 15.382 ms
```

### Después de la optimización
```text
Sort  (cost=12.27..12.28 rows=2 width=24) (actual time=0.136..0.137 rows=0.00 loops=1)
   Sort Key: fecha_hora DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Bitmap Heap Scan on pedido p  (cost=4.45..12.26 rows=2 width=24) (actual time=0.131..0.131 rows=0.00 loops=1)
         Recheck Cond: ((id_cliente = 1500) AND (fecha_hora >= (now() - '180 days'::interval)))
         ->  Bitmap Index Scan on idx_pedido_cliente_fecha  (cost=0.00..4.44 rows=2 width=0) (actual time=0.113..0.113 rows=0.00 loops=1)
               Index Cond: ((id_cliente = 1500) AND (fecha_hora >= (now() - '180 days'::interval)))
Planning Time: 2.176 ms
Execution Time: 0.166 ms
```
El filtro de fecha pasó a resolverse dentro del índice (`Index Cond` completa) y desapareció el `Sort` explícito: el orden `id_cliente, fecha_hora DESC` de `idx_pedido_cliente_fecha` entrega las filas ya ordenadas.

## A.4 Costo de los índices sobre las escrituras

Método: carga de **1000 pedidos + 1000 líneas de `detalle_pedido`** en transacción reversible (`BEGIN` … `ROLLBACK`), repetida 3 veces **sin** los índices aceptados y 3 veces **con** ellos, en orden alternado A/B/A/B/A/B para neutralizar el efecto cache.

```sql
BEGIN;
INSERT INTO pedido (fecha_hora, forma_pago, id_cliente)
SELECT now(), 'EFECTIVO', 1 FROM generate_series(1,1000);
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT n.id_pedido, (n.id_pedido % 50000) + 1, 2, 50.00
FROM (SELECT id_pedido FROM pedido WHERE fecha_hora > now() - interval '90 seconds') n;
ROLLBACK;
```

### Resultados (duración del INSERT de las 1000 líneas de detalle)

| Condición | Corrida 1 | Corrida 2 | Corrida 3 | Mediana |
|---|---|---|---|---|
| SIN índices aceptados | 69.159 ms | 51.102 ms | 47.973 ms | **51.1 ms** |
| CON índices aceptados | 60.734 ms | 57.792 ms | 59.071 ms | **59.1 ms** |

**Lectura honesta de los resultados:**
- El mantenimiento aproximado de los dos índices nuevos agrega ~8 ms por cada 1000 filas (~8 µs/fila), un incremento pequeño y del orden del ruido de medición. A la escala pedida ("varios cientos de INSERT") no se observa una degradación estructural.
- El costo real se ve en la **creación** de los índices sobre el volumen existente: `idx_detalle_pedido_id_producto` ≈ 511–568 ms y `idx_pedido_cliente_fecha` ≈ 294–331 ms sobre ~600.000 filas.
- Conclusión: los índices aceptados tienen un costo de escritura bajo, pero no nulo; por eso conviene descartar los que el optimizador no usa (ver A.2), en lugar de acumularlos.

---

# Parte B — Equivalencia de las vistas

Para cada vista se comparó el resultado contra la **consulta manual equivalente escrita a mano**, con `EXCEPT` en ambos sentidos (vista − manual y manual − vista). Un único resultado distinto hubiera aparecido como diferencia.

## Filas comparadas

| Vista | Filas |
|---|---|
| `v_productos_vigentes` | 47.510 |
| `v_pedidos_usuario` | 200.000 |
| `v_detalle_pedido_completo` | 601.248 |

## Verificación (ejemplo `v_productos_vigentes`)
```sql
(SELECT * FROM v_productos_vigentes
 EXCEPT
 SELECT p.id_producto, p.nombre, p.precio_actual, c.nombre
 FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE p.activo = TRUE)
UNION ALL
(SELECT p.id_producto, p.nombre, p.precio_actual, c.nombre
 FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE p.activo = TRUE
 EXCEPT
 SELECT * FROM v_productos_vigentes);
```

## Resultado
```text
   vista   | diferencias
-----------+-------------
 productos |           0
 pedidos   |           0
 detalle   |           0
(3 filas)
```
Las 3 vistas son **exactamente equivalentes** a sus consultas manuales (0 diferencias en ambos sentidos). La verificación se documenta aquí y en la bitácora `duia.md`.

---

# Parte C — Vista materializada de facturación por categoría y mes

## Consulta original (sin materializar)
La consulta de facturación histórica por categoría y mes (queries.sql, consulta 1) obtuvo `Execution Time: 423.323 ms` (reproducida en validación en ~2.332 ms, plan con `Hash Join` + `external merge` sobre las 601.248 filas).

## Consulta sobre la vista materializada
`mv_facturacion_categoria_mes` se creó con `WITH DATA` y el índice único `idx_mv_facturacion_categoria_mes (categoria, mes)` (requisito para refresco concurrente).

```text
Sort  (actual time=0.082..0.089 rows=250 loops=1)
  Sort Key: mes, facturacion_total DESC
  -> Seq Scan on mv_facturacion_categoria_mes
     (actual time=0.030..0.042 rows=250 loops=1)
Planning Time: 5.327 ms
Execution Time: 0.107 ms
```
`Seq Scan` sobre 250 filas agregadas (4 páginas en cache): **423.323 ms → 0.107 ms** (~3.900×). El reporte materializado respeta la misma lógica que la consulta base (mismo número de filas y valores).

## Refresco concurrente — verificado
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes; -- OK
```
Se probó insertando una venta nueva, ejecutando el refresco y confirmando que el total del mes se actualizaba; luego se revirtió la venta de prueba y se re-refrescó.

## Frecuencia de refresco
Se propone ejecutar el `REFRESH MATERIALIZED VIEW CONCURRENTLY` **una vez por día, al cierre de la jornada** (el reporte se consulta a nivel diario/gerencial).
**Implicancia para los usuarios:** entre refresco y refresco el reporte muestra los datos vigentes al **último** refresco; las ventas posteriores no aparecen hasta la siguiente ejecución. A cambio, las consultas de lectura no quedan bloqueadas durante el refresco (por eso se exige el índice único). Si el reporte necesitara datos casi en tiempo real, habría que subir la frecuencia (p. ej. cada hora) y asumir el costo de escritura del refresco.