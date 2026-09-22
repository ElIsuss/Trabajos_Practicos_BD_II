# Como ejecutar el trabajo

## Requisitos

- PostgreSQL 16 o superior.
- DBeaver conectado a una base de datos vacia.

## Orden de ejecucion

1. Ejecutar `schema_completo.sql`, ubicado en la carpeta `food-store`.
   Crea las tablas, tipos, restricciones e indices heredados.

2. Ejecutar `data.sql`, ubicado en la carpeta `food-store`.
   Carga los datos de prueba.

3. Ejecutar `seguridad_usuario.sql`, ubicado en la carpeta `food-store`.
   Crea los objetos necesarios para la vista segura de usuarios.

4. Ejecutar `indices.sql`, ubicado en la carpeta `volumen`.
   Crea los indices de la Parte A.

5. Ejecutar `views.sql`, ubicado en la carpeta `volumen`.
   Crea las vistas de la Parte B y la vista materializada de la Parte C.

6. Consultar `queries.sql`, ubicado en la carpeta `volumen`.
   Contiene las consultas usadas para las mediciones.

## Actualizacion del reporte materializado

Para actualizar la facturacion por categoria y mes, ejecutar:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

Se recomienda ejecutarlo una vez por dia, al cierre de la jornada. Las ventas posteriores al ultimo refresco no apareceran en el reporte hasta la siguiente actualizacion.

## Documentacion

Las mediciones estan registradas en `informe_mediciones.md`, ubicado en la carpeta `volumen`.

La bitacora de uso de IA esta en `duia.md`, ubicado en la carpeta `volumen`.

Las especificaciones estan en la carpeta `specs`, dentro de `volumen`.
