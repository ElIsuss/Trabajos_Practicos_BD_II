# Informe parcial I – Food Store

## 1. Alcance

Este informe resume los principales elementos implementados en las tres unidades del proyecto Food Store, las pruebas realizadas, los resultados obtenidos, las optimizaciones de consultas y el uso de herramientas de inteligencia artificial. El trabajo se desarrolló sobre PostgreSQL utilizando la base de prueba `foodstore_trabajo`.

La información se obtuvo de los scripts SQL, diagramas, informes de medición y DUIA disponibles en el repositorio. Cuando un resultado aparece en un informe, pero no existe una salida completa, se describe como una medición registrada.

## 2. Elementos implementados por unidad

### Unidad 1

En la Unidad 1 se construyó el modelo conceptual y relacional del sistema. El modelo principal incluye las entidades `categoria`, `cliente`, `producto`, `pedido` y `detalle_pedido`.

La relación N:M entre `pedido` y `producto` se resolvió mediante la tabla intermedia `detalle_pedido`, que contiene una clave primaria propia, las claves foráneas hacia pedido y producto, la cantidad vendida y el precio unitario histórico.

El DDL utiliza claves primarias `BIGINT GENERATED ALWAYS AS IDENTITY`, claves foráneas con `ON DELETE RESTRICT`, restricciones `UNIQUE` y restricciones `CHECK` para validar precios, stocks, cantidades, precios unitarios, nombres y correos electrónicos.

También se implementaron el análisis de un `UPDATE` sin condición `WHERE` y la comparación entre `NOT IN` y `NOT EXISTS` para eliminar categorías sin productos. La resolución N:M, la integridad referencial y la conservación del precio histórico se analizan en `Unidad 1/TP_1/schema.sql`, `Unidad 1/TP_1/Diagrama.png` y `Unidad 1/TP_2/ejercicio_lectura_critica.md`.

En el área de concurrencia se reprodujeron tres escenarios: espera por bloqueo de fila, interbloqueo y lectura no repetible. El detalle de las sesiones, resultados y explicaciones se encuentra en `Unidad 1/TP_2/informe_concurrencia.md`.

### Unidad 2

En la Unidad 2 se desarrolló la carga de datos de prueba y el trabajo con distintas formas de consulta y análisis de datos.

El generador crea 10 categorías, 20.000 clientes, 50.000 productos y 200.000 pedidos. También genera líneas de detalle, aplica `DISTINCT ON` para evitar duplicados dentro de un pedido y ejecuta `ANALYZE` sobre las tablas.

Las consultas desarrolladas utilizan `JOIN`, `GROUP BY`, `HAVING`, funciones de agregación, subconsultas correlacionadas, CTE y funciones de ventana como `DENSE_RANK`. Se prepararon versiones lentas y rápidas de consultas de productos, pedidos, historial de clientes y ranking de clientes por gasto.

El archivo `Unidad 2/queris/verificacion_equivalencia_except.sql` contiene comparaciones mediante `EXCEPT` para comprobar que dos formulaciones de una consulta devuelven el mismo conjunto de filas.

### Unidad 3

En la Unidad 3 se amplió el modelo con la tabla `usuario`, el enum `rol` y el enum `estado_pedido_enum`. La tabla `usuario` se relaciona con `cliente` mediante una relación 1:1 y también incorpora un indicador de eliminación lógica.

Se crearon las vistas `v_productos_vigentes`, `v_pedidos_usuario` y `v_detalle_pedido_completo`, además de la vista materializada `mv_facturacion_categoria_mes`.

La vista de pedidos utiliza una lista blanca de columnas y no expone el campo `contrasena`. La vista materializada se crea con `WITH DATA` y posee un índice único sobre categoría y mes para permitir `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

También se crearon índices sobre `detalle_pedido(id_producto)`, `pedido(id_cliente)` y `pedido(id_cliente, fecha_hora)` para optimizar las consultas de volumen.

El sistema utiliza borrado lógico mediante `categoria.activo`, `producto.activo` y `usuario.eliminado`. Las claves foráneas con `ON DELETE RESTRICT` impiden eliminar físicamente registros que todavía sean referenciados.

En los SQL revisados se encuentran vistas y vistas materializadas, pero no se localizan declaraciones de funciones, procedimientos almacenados o triggers.

## 3. Pruebas realizadas y resultados

Las pruebas de concurrencia se realizaron sobre dos sesiones de la base de trabajo.

En el primer escenario, la Sesión A actualizó una fila de `producto` y la Sesión B quedó esperando hasta que la primera sesión ejecutó `COMMIT`.

En el segundo escenario, las sesiones retuvieron recursos en orden inverso. PostgreSQL detectó el deadlock y abortó una de las transacciones con el código `40P01`. Los comandos posteriores de esa sesión fueron rechazados con el estado `25P02`.

En el tercer escenario se comparó una lectura bajo `READ COMMITTED` con otra bajo `REPEATABLE READ`. Bajo `READ COMMITTED`, la segunda lectura observó el cambio confirmado por otra sesión. Bajo `REPEATABLE READ`, se mantuvo el valor original de la transacción.

Las restricciones de integridad están implementadas mediante `CHECK`, `UNIQUE`, `NOT NULL` y claves foráneas. Las pruebas de inserciones válidas e inválidas quedaron definidas en la DUIA de restricciones, pero su sección de verificación permanece pendiente de salida de PostgreSQL.

Los scripts de `EXCEPT` permiten comprobar la equivalencia de consultas, pero no se conservaron todas sus salidas de ejecución. Las mediciones de rendimiento se encuentran registradas en `Unidad_3/TP 5/volumen/informe_mediciones.md` y en `Unidad 2/TP 3/registro_competencia.md`.

## 4. Consultas optimizadas

| Consulta | Antes | Después | Resultado |
|---|---:|---:|---|
| Productos activos por precio | 6,429 ms | 0,250 ms | Mejora aproximada de 25,7 veces mediante un índice parcial. |
| Productos más vendidos | 806,504 ms | 652,446 ms | El plan posterior utiliza un índice sobre `detalle_pedido(id_producto)`. |
| Ranking de clientes | 388,309 ms | 295,607 ms | El tiempo disminuye, aunque el índice evaluado no fue utilizado por el plan. |
| Pedidos recientes | 15,382 ms | 0,166 ms | Mejora registrada mediante el índice compuesto por cliente y fecha. |
| Facturación | 423,323 ms | 0,107 ms | La vista materializada evita recalcular el agregado y devuelve 250 filas precalculadas. |

La consulta de productos por precio utiliza un índice parcial sobre `precio_actual` donde `activo = TRUE`. La consulta de productos más vendidos se optimiza mediante un índice sobre `detalle_pedido(id_producto)`. La consulta de pedidos recientes utiliza un índice compuesto por `id_cliente` y `fecha_hora`.

La vista materializada de facturación se actualiza mediante:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

Su utilización permite reducir el costo de las consultas frecuentes, aunque las ventas posteriores al último refresco no aparecen inmediatamente.

## 5. Uso de inteligencia artificial

Se utilizaron diferentes herramientas para generar SQL, revisar soluciones y explicar conceptos de concurrencia.

| Herramienta | Finalidad | Decisiones |
|---|---|---|
| OpenCode | Restricciones, DDL, consultas, vistas, índices y explicaciones de concurrencia | Se aceptaron las soluciones adaptadas a los nombres reales del esquema. |
| Kiro | Consultas de agregación, subconsultas y propuestas de optimización | Se aceptaron con ajustes. |
| ChatGPT y Gemini | Bloqueos a nivel de fila, deadlock, SQLSTATE y niveles de aislamiento | Las explicaciones se contrastaron con los escenarios reproducidos. |

Las decisiones aceptadas incluyeron conservar `ON DELETE RESTRICT`, utilizar `btrim` para nombres no vacíos, proteger la contraseña mediante proyección explícita y crear índices orientados a las consultas más frecuentes. También se descartaron nombres de columnas que no correspondían al esquema real y no se atribuyó una mejora de rendimiento a un índice cuando el plan no lo utilizó.

La trazabilidad del uso de IA se encuentra en `Unidad 1/TP_2/DUIA_restricciones.md`, `Unidad 1/TP_2/DUIA_informe_concurrencia.md`, `Unidad 2/TP 3/duia.md` y `Unidad_3/TP 5/volumen/duia.md`.
