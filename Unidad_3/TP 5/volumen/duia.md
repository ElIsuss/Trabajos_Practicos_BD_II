# duia - Unidad 3

## Registro de decisiones con herramientas IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|-------------|-----------------|-------------------------|-----------------------------------|
| OpenCode | Índice para optimizar el JOIN de "Top 20 productos más vendidos" (specs/optimizacion_top_productos.md) | "Propone el comando CREATE INDEX necesario para optimizar el JOIN entre detalle_pedido y producto." | Aceptado. Índice B-tree `idx_detalle_pedido_id_producto ON detalle_pedido (id_producto)` sobre la FK que participa en el JOIN (`dp.id_producto = pr.id_producto`). Se ofreció como mejora un índice de cobertura con `INCLUDE (cantidad, precio_unitario)` para habilitar Index Only Scan. |
| OpenCode | Índices para los JOINs de "Ranking de clientes por gasto" (specs/optimizacion_ranking_clientes.md) | "Propone la sentencia CREATE INDEX necesaria para optimizar los JOINs de esta consulta." | **Descartado (sobreindexación).** Propuso `idx_pedido_id_cliente ON pedido (id_cliente)` y `idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)`. Medidos con EXPLAIN ANALYZE, el plan siguió con `Parallel Seq Scan` y ninguno apareció en el plan. El primero además **duplica** a `idx_pedido_cliente` ya existente en el esquema base y el segundo es inefectivo en una agregación full-scan. Ninguno quedó en `indices.sql`. |
| OpenCode | Revisión de la decisión de descarte (analista de bases de datos) | "Los dos índices no aparecen en el plan de la Consulta 3 y uno replica un índice existente. ¿Cuál es la decisión correcta?" | Aceptado el criterio: **descartar ambos por sobreindexación**. Se eliminaron de `indices.sql` y se dejó la justificación comentada en ese archivo y en `informe_mediciones.md` (A.2). Reproducción posterior confirmó que su ausencia no cambia el plan (sin regresión, ver informe). |
| OpenCode | Generación de vistas de reportes (specs/vistas_reportes.md) | "Genera las sentencias CREATE OR REPLACE VIEW para views.sql y explica cada vista para duia.md." | Aceptado con adaptaciones en una 1.ª iteración: se mapearon los nombres del esquema real (`precio_actual` → `precio_unitario`, `correo_electronico` → `email`) y se omitió `estado` porque el esquema no lo poseía. |
| OpenCode | Revisión del criterio de seguridad y adecuación al esquema (specs/vistas_reportes.md) | "Prefiero hacerlo como en el spec; si hace falta crear la fila de password, hacelo con CREATE TABLE usuario..., corrigiendo los errores." | Aceptado con correcciones. Reemplaza la iteración anterior: (1) se creó el enum `rol` que faltaba; (2) se agregó `usuario.id_cliente` FK UNIQUE a `cliente` para vincular credenciales con los pedidos; (3) se agregó `pedido.estado` (`estado_pedido_enum`, DEFAULT 'PENDIENTE') exigido por la spec; (4) `v_pedidos_usuario` ahora incluye `estado` y cumple la regla de seguridad (omite `contrasena`). |
| OpenCode | Vista materializada para facturacion por categoria y mes (specs/materializada_facturacion_categoria_mes.md) | "Crear una vista materializada para el reporte historico de facturacion por categoria y mes, con WITH DATA e indice unico para REFRESH CONCURRENTLY." | Aceptado. Se creo `mv_facturacion_categoria_mes` y el indice unico `(categoria, mes)`. La consulta bajo de `423.323 ms` a `0.107 ms`. Se definio refresco diario; el reporte puede no incluir ventas posteriores al ultimo refresco. |

## 1. Optimización de consultas (índices)

### 1.1 Consulta "Top 20 productos más vendidos"
```sql
CREATE INDEX idx_detalle_pedido_id_producto
ON detalle_pedido (id_producto);
```
- Optimiza el JOIN `detalle_pedido ⋈ producto` por la FK `id_producto`.
- Reemplaza el `Parallel Seq Scan` sobre `detalle_pedido` por `Index Scan` (Merge Join), como se registra en `informe_mediciones.md` (806 ms → 652 ms).

Mejora opcional (índice de cobertura, evita heap fetches en el plan normal):
```sql
CREATE INDEX idx_detalle_pedido_id_producto_cov
ON detalle_pedido (id_producto)
INCLUDE (cantidad, precio_unitario);
```

### 1.2 Consulta "Ranking de clientes por gasto" — DESCARTADA

Propuesta original de OpenCode (no quedó en `indices.sql`):
```sql
-- DESCARTADO: redundante con idx_pedido_cliente (schema base)
CREATE INDEX idx_pedido_id_cliente ON pedido (id_cliente);
-- DESCARTADO: inefectivo, el plan no lo utiliza en la agregación global
CREATE INDEX idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido);
```
- `EXPLAIN ANALYZE` antes/después: el plan siguió con `Parallel Seq Scan` sobre `pedido` y `detalle_pedido` (388.309 ms → 295.607 ms, la baja es por caché, no por el índice).
- `idx_pedido_id_cliente` replica el índice base `idx_pedido_cliente` (misma columna, mismo B-tree) → duplicación de mantenimiento sin ganancia.
- `idx_detalle_pedido_id_pedido` no modifica la estrategia de una agregación full-scan.
- Reproducción final con ambos eliminados: plan idéntico, `Execution Time: 729.471 ms` (sin regresión). Ver `informe_mediciones.md` A.2.

## 2. Vistas de reportes (specs/vistas_reportes.md)

### `seguridad_usuario.sql` (nuevo, ejecutar tras schema_completo.sql + data.sql)
- **`CREATE TYPE rol AS ENUM ('ADMINISTRADOR','USUARIO')`**: la sentencia original de la consigna referenciaba el tipo `rol` inexistente; se creó previamente.
- **`CREATE TABLE usuario (...)`**: columnas `id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at` + `id_cliente` FK UNIQUE → `cliente` (relación 1:1). `contrasena VARCHAR(255)` pensada para almacenar hash.
- **`estado_pedido_enum` + `ALTER TABLE pedido ADD COLUMN estado`**: la spec exige `estado` en la vista y `pedido` no lo tenía; se agregó con DEFAULT 'PENDIENTE' (los datos existentes quedan PENDIENTE).
- **Poblado 1:1**: un `usuario` por cada `cliente` (misma identidad, contraseña placeholder de testeo).

### `views.sql` (CREATE OR REPLACE VIEW)
1. `v_productos_vigentes` — catálogo vigente con categoría.
2. `v_pedidos_usuario` — pedidos por usuario (criterio de seguridad).
3. `v_detalle_pedido_completo` — líneas de detalle con producto y subtotal.

## 3. Explicación técnica por vista (para la defensa oral)

### 1. `v_productos_vigentes`
JOIN `producto` ⋈ `categoria` por PK/FK `id_categoria`, filtro `activo = TRUE` (misma regla del índice parcial `idx_producto_categoria_activo`). `precio_actual` se expone con alias `precio_unitario` (nombre de la spec). Oculta columnas internas (`stock`, `created_at`, `id_categoria`).

### 2. `v_pedidos_usuario` (Criterio de Seguridad)
- **JOINs:** `pedido` ⋈ `cliente` (`id_cliente`) ⋈ `usuario` (`id_cliente`) ⋈ `detalle_pedido` (LEFT, para el total sin perder pedidos).
- **Columnas expuestas:** `id_pedido, fecha_hora, total, estado, id_cliente, nombre, apellido, email`. `total` = `COALESCE(SUM(cantidad*precio_unitario),0)`; `email` = `cliente.correo_electronico`.
- **Regla de seguridad aplicada:** la vista JOINea la tabla de credenciales (`usuario`, que almacena `contrasena`) pero proyecta una **lista blanca explícita**: `usuario.contrasena` NUNCA se selecciona. Cualquier columna sensible que se agregue en el futuro queda excluida por diseño (defensa en profundidad).
- **Complemento recomendado:** `REVOKE` sobre las tablas base + `GRANT SELECT ON v_pedidos_usuario TO <rol>` para restringir el acceso por capa.

### 3. `v_detalle_pedido_completo`
JOIN `detalle_pedido` ⋈ `producto` (`id_producto`). `subtotal` = `cantidad * precio_unitario` usando el precio de la venta (snapshot), no el precio actual del catálogo.

## Validación de equivalencia (realizada y verificada)

Se comparó cada vista contra su consulta manual con `EXCEPT` en **ambos sentidos** (vista − manual y manual − vista) sobre la copia de trabajo:

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

Salida obtenida (ejemplo; las 3 vistas se verificaron igual):

```text
   vista   | diferencias
-----------+-------------
 productos |           0
 pedidos   |           0
 detalle   |           0
(3 filas)
```

Filas comparadas por vista: `v_productos_vigentes` = 47.510, `v_pedidos_usuario` = 200.000, `v_detalle_pedido_completo` = 601.248 → **equivalencia exacta** (0 diferencias). El detalle completo está en `informe_mediciones.md` (Parte B).

## 4. Vista materializada: facturacion por categoria y mes

- **Spec utilizada:** `specs/materializada_facturacion_categoria_mes.md`.
- **Propuesta aceptada:** crear `mv_facturacion_categoria_mes` con `WITH DATA` a partir de la consulta de facturacion por categoria y mes.
- **Indice aceptado:** indice unico sobre `(categoria, mes)`, necesario para poder ejecutar `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- **Medicion:** la consulta original tardo `423.323 ms`; la consulta sobre la vista materializada tardo `0.107 ms` y leyo 250 filas agregadas.
- **Decision de refresco:** una vez por dia al cierre de la jornada. La consecuencia es que el reporte muestra los datos vigentes al ultimo refresco, no necesariamente las ventas mas recientes.

## Orden de ejecución recomendado
`schema_completo.sql` → `data.sql` → `seguridad_usuario.sql` → `views.sql` → `indices.sql`
