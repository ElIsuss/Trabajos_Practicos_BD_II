# Declaración de Uso de Inteligencia Artificial - Parte 1

## Alcance

Esta declaración documenta cuatro reglas de integridad vinculadas al archivo
`Unidad 1/TP_2/restriciones.sql`.

La consigna solicita elegir entre dos y tres reglas. En este caso se documentan
cuatro como trabajo adicional, indicando cuáles son nuevas en el proyecto actual.

En el repositorio actual, `producto.id_categoria` ya es `NOT NULL` y la clave
foránea `fk_producto_categoria` ya está definida en
`Unidad 1/TP_1/schema.sql:37-40`. Por lo tanto, esa primera regla no es nueva y
no debe agregarse nuevamente después de ejecutar `schema.sql`.

Las tres restricciones realmente nuevas son:

- Validación básica del correo electrónico.
- Nombre de producto no vacío.
- Nombre y apellido de cliente no vacíos.

## Herramienta

OpenCode, modelo OpenAI gpt-5.6-terra.

## Prompts utilizados

### Categoría obligatoria

No se conservó el texto exacto del prompt. La regla propuesta era que
`producto.id_categoria` no pudiera ser nulo y que debiera existir en
`categoria.id_categoria`.

### Correo electrónico con formato válido

No se conservó el texto exacto del prompt. La regla propuesta era validar un
formato básico de correo electrónico.

### Nombre de producto no vacío

Prompt conservado:

> ahora mimso hice 2 restricciones que teniamos, necesito 2 mas, dime algunas
> restrcciones que no esten en schema.sql ni en restriccione.sql asi vemos
> cual podemos implementar ok, hagamos el 1 y el 2, dime como lo harias

### Nombre y apellido no vacíos

Prompt conservado:

> ok perfecto, ahora al editar el archivo quiero que saques el comentario antes
> del codigo en sql, no pongas RN04 o 05 pone un comentario que diga simplemente
> la restriccion que estas haciendo por ejemplo --nombre y apellido no vacio

## Qué generó la IA

La IA propuso las siguientes restricciones:

- `ALTER COLUMN id_categoria SET NOT NULL`.
- La clave foránea `fk_producto_categoria` con `ON DELETE RESTRICT`.
- `chk_cliente_correo_formato` sobre `cliente.correo_electronico`.
- `chk_producto_nombre_no_vacio` sobre `producto.nombre`.
- `chk_cliente_nombre_apellido_no_vacios` sobre `cliente.nombre` y
  `cliente.apellido`.

## Qué se aceptó

Se aceptaron las tres restricciones nuevas y sus nombres con los prefijos
`chk_`.

También se aceptó el uso de `btrim` para rechazar nombres formados únicamente
por espacios ordinarios, sin impedir nombres que tengan espacios al inicio o
al final.

La relación entre `producto` y `categoria` conserva `ON DELETE RESTRICT`, porque
impide eliminar una categoría que tenga productos asociados.

## Qué se modificó o descartó

Se reemplazaron los comentarios `RN04` y `RN05` por comentarios descriptivos
simples, a pedido del alumno.

La regla de `producto.id_categoria` y su clave foránea se identificaron como
duplicadas de las definiciones existentes en `schema.sql`. Por ello, no deben
presentarse como restricciones nuevas.

No se inventaron los prompts exactos de las dos primeras reglas porque no se
conservaron.

## Verificación

Estado: pendiente de completar.

Antes de considerar la verificación como realizada deben registrarse:

1. El respaldo generado con `pg_dump`.
2. La aplicación de las restricciones dentro de `BEGIN; ... ROLLBACK;`.
3. Inserciones válidas e inválidas.
4. La salida exacta de PostgreSQL.
5. La repetición con `COMMIT` únicamente después de aprobar los resultados.

No deben documentarse errores de PostgreSQL como resultados reales hasta haber
obtenido esa salida mediante una ejecución efectiva.
