# Ejercicio de Lectura Crítica - Parte 3

## Script 1: Baja de funciones retiradas de cartel

### Qué filas afectaría realmente

No se dispone de la base de datos ni del esquema genérico de cine para enumerar registros concretos. Sin embargo, al no incluir una cláusula `WHERE`, el script actualizaría todas las filas de la tabla `funcion`, cambiando el valor de la columna `activa` a `FALSE`.

### Por qué no coincide con la consigna

La consigna indica dar de baja únicamente las funciones de películas retiradas de cartel. El script no contiene ninguna condición para identificar cuáles funciones fueron retiradas, por lo que también desactivaría funciones que todavía están en cartel.

### Versión original

```sql
UPDATE funcion
SET activa = FALSE;
```

### Versión corregida

La condición exacta depende de la columna que el esquema use para registrar el fin de cartelera. Por ejemplo, si `fecha_fin` representa esa fecha:

```sql
UPDATE funcion
SET activa = FALSE
WHERE fecha_fin < CURRENT_DATE
  AND activa = TRUE;
```

La cláusula `WHERE` limita la actualización a funciones cuya fecha de finalización ya pasó. La condición `activa = TRUE` evita actualizar innecesariamente filas que ya estaban dadas de baja.

## Script 2: Eliminación de categorías sin productos asociados

### Qué filas afectaría realmente

El script intenta eliminar las filas de `categoria` cuyo valor de `id_categoria` (usando la base de datos de este proyecto) no aparece en la columna `id_categoria` de la tabla `producto`.

Si la subconsulta devolviera al menos un valor `NULL`, la condición `NOT IN` no sería verdadera para ninguna categoría. En ese caso, el script podría no eliminar ninguna fila, incluso si existen categorías sin productos asociados.

### Por qué no coincide con la consigna

La consigna indica eliminar las categorías que no tienen productos asociados. El uso de `NOT IN` no maneja correctamente los valores `NULL` que podrían existir en la subconsulta. Por esa razón, no garantiza que se eliminen las categorías sin productos.

### Versión original

```sql
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### Versión corregida

```sql
DELETE FROM categoria AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto AS p
    WHERE p.id_categoria = c.id_categoria
);
```

La condición `NOT EXISTS` comprueba, para cada categoría, que no exista ningún producto relacionado. A diferencia de `NOT IN`, esta versión funciona correctamente aunque `producto.id_categoria` contenga valores `NULL`.
