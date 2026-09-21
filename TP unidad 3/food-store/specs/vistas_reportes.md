# Spec: vistas_reportes

## Objetivo

Crear 3 vistas para simplificar el acceso a reportes frecuentes y proteger la información sensible de los usuarios.

## Vistas Requeridas

1. `v_productos_vigentes`:

   - Tablas: `producto`, `categoria`

   - Columnas a exponer: `id_producto`, `nombre_producto`, `precio_unitario`, `nombre_categoria`

   - Condición: Productos no eliminados / vigentes.

2. `v_pedidos_usuario` (Criterio de Seguridad):

   - Tablas: `pedido`, `cliente` (o `usuario`)

   - Columnas a exponer: `id_pedido`, `fecha_hora`, `total`, `estado`, `id_cliente`, `nombre`, `apellido`, `email`

   - **Regla de Seguridad:** Omitir explícitamente el campo `password` / `contraseña`.

3. `v_detalle_pedido_completo`:

   - Tablas: `detalle_pedido`, `producto`

   - Columnas a exponer: `id_pedido`, `id_producto`, `nombre_producto`, `cantidad`, `precio_unitario`, `subtotal` (calculado: cantidad * precio_unitario).

## Criterios de Aceptación

- La sintaxis debe ser ANSI SQL estándar sobre PostgreSQL 16+.

- Se debe validar la equivalencia exacta de filas contra la consulta sin vista.
