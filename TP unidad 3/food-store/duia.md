# duia - Unidad 3

## Registro de decisiones con herramientas IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|-------------|-----------------|-------------------------|-----------------------------------|
| OpenCode | Índice para optimizar el JOIN de "Top 20 productos más vendidos" (specs/optimizacion_top_productos.md) | "Propone el comando CREATE INDEX necesario para optimizar el JOIN entre detalle_pedido y producto." | Aceptado. Índice B-tree `idx_detalle_pedido_id_producto ON detalle_pedido (id_producto)` sobre la FK que participa en el JOIN (`dp.id_producto = pr.id_producto`). Se ofreció como mejora un índice de cobertura con `INCLUDE (cantidad, precio_unitario)` para habilitar Index Only Scan. |
| OpenCode | Índices para los JOINs de "Ranking de clientes por gasto" (specs/optimizacion_ranking_clientes.md) | "Propone la sentencia CREATE INDEX necesaria para optimizar los JOINs de esta consulta." | Aceptado. Dos índices B-tree sobre las FKs de los JOINs: `idx_pedido_id_cliente ON pedido (id_cliente)` y `idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)`. `cliente` no necesita índice (tabla de origen del recorrido). |
| OpenCode | Generación de vistas de reportes (specs/vistas_reportes.md) | "Genera las sentencias CREATE OR REPLACE VIEW para views.sql y explica cada vista para duia.md." | Aceptado con adaptaciones en una 1.ª iteración: se mapearon los nombres del esquema real (`precio_actual` → `precio_unitario`, `correo_electronico` → `email`) y se omitió `estado` porque el esquema no lo poseía. |
| OpenCode | Revisión del criterio de seguridad y adecuación al esquema (specs/vistas_reportes.md) | "Prefiero hacerlo como en el spec; si hace falta crear la fila de password, hacelo con CREATE TABLE usuario..., corrigiendo los errores." | Aceptado con correcciones. Reemplaza la iteración anterior: (1) se creó el enum `rol` que faltaba; (2) se agregó `usuario.id_cliente` FK UNIQUE a `cliente` para vincular credenciales con los pedidos; (3) se agregó `pedido.estado` (`estado_pedido_enum`, DEFAULT 'PENDIENTE') exigido por la spec; (4) `v_pedidos_usuario` ahora incluye `estado` y cumple la regla de seguridad (omite `contrasena`). |

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

### 1.2 Consulta "Ranking de clientes por gasto"
```sql
CREATE INDEX idx_pedido_id_cliente
ON pedido (id_cliente);

CREATE INDEX idx_detalle_pedido_id_pedido
ON detalle_pedido (id_pedido);
```
- `pedido (id_cliente)` acelera el JOIN `cliente ⋈ pedido`.
- `detalle_pedido (id_pedido)` acelera el JOIN `pedido ⋈ detalle_pedido`.

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

## Validación de equivalencia
Comparar cada vista contra su consulta sin vista con `EXCEPT` (mismo número de filas y valores):
```sql
(SELECT * FROM v_productos_vigentes
 EXCEPT
 SELECT p.id_producto, p.nombre, p.precio_actual, c.nombre
 FROM producto p
 JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE p.activo = TRUE)
UNION ALL
(SELECT ... ); -- (reverso: base EXCEPT vista)
```

## Orden de ejecución recomendado
`schema_completo.sql` → `data.sql` → `seguridad_usuario.sql` → `views.sql` → `indices.sql`