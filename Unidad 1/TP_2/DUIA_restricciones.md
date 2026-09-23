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

### Regla de categoría obligatoria

No se conservó el texto exacto del prompt. La regla propuesta era que
`producto.id_categoria` no pudiera ser nulo y que debiera existir en
`categoria.id_categoria`. La revisión posterior determinó que esta regla ya
forma parte de `Unidad 1/TP_1/schema.sql`, por lo que no se vuelve a agregar
como restricción nueva.

### Correo electrónico con formato válido

No se conservó el texto exacto del prompt. La regla propuesta era validar un
formato básico de correo electrónico. Se conserva el resumen disponible, pero
no se presenta como transcripción literal.

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

La nulabilidad de `producto.id_categoria` y la FK `fk_producto_categoria` se
verificaron en `schema.sql` y no se modificaron nuevamente.

## Qué se modificó o descartó

Se reemplazaron los comentarios `RN04` y `RN05` por comentarios descriptivos
simples, a pedido del alumno.

La regla de `producto.id_categoria` y su clave foránea se identificaron como
duplicadas de las definiciones existentes en `schema.sql`. Por ello, no deben
presentarse como restricciones nuevas.

No se inventaron los prompts exactos de las dos primeras reglas porque no se
conservaron.

## Verificación

### Estado

La parte documental de la DUIA está completa. La verificación de ejecución
sigue pendiente: no se conserva una salida real de PostgreSQL para los casos
válidos o inválidos. Por lo tanto, no se afirma que las pruebas hayan sido
ejecutadas.

### Evidencia estática disponible

| Regla | Implementación | Evidencia documental | Estado de ejecución |
|---|---|---|---|
| Correo con formato válido | `restriciones.sql:16-18` | Restricción `chk_cliente_correo_formato` definida | Pendiente |
| Nombre de producto no vacío | `restriciones.sql:20-23` | Restricción `chk_producto_nombre_no_vacio` definida | Pendiente |
| Nombre y apellido no vacíos | `restriciones.sql:25-30` | Restricción `chk_cliente_nombre_apellido_no_vacios` definida | Pendiente |
| Categoría obligatoria y FK | `Unidad 1/TP_1/schema.sql:37-40` | Regla preexistente con `ON DELETE RESTRICT` | No es nueva |

### Procedimiento reproducible

La siguiente secuencia debe ejecutarse únicamente sobre `foodstore_trabajo`.
Antes de aplicar el archivo de restricciones se debe generar un respaldo:

```bash
pg_dump foodstore_trabajo > backups/backup_antes_restricciones_<FECHA>_<HORA>.sql
```

Cada caso se ejecuta en una transacción independiente. Una restricción violada
aborta la transacción; después de cada prueba se debe ejecutar `ROLLBACK` hasta
disponer de la salida real.

### Caso válido: correo y nombres

```sql
BEGIN;

INSERT INTO cliente (nombre, apellido, correo_electronico)
VALUES ('Cliente', 'Prueba DUIA', 'duia.valido@example.com');

SELECT nombre, apellido, correo_electronico
FROM cliente
WHERE correo_electronico = 'duia.valido@example.com';

ROLLBACK;
```

Resultado esperado: el `INSERT` y el `SELECT` devuelven la fila, y el
`ROLLBACK` no deja datos persistentes.

### Caso inválido: correo

```sql
BEGIN;

INSERT INTO cliente (nombre, apellido, correo_electronico)
VALUES ('Cliente', 'Correo inválido', 'correo-sin-arroba');

ROLLBACK;
```

Resultado esperado: PostgreSQL informa una violación de
`chk_cliente_correo_formato`, con SQLSTATE `23514`.

### Caso inválido: nombre de producto

```sql
BEGIN;

INSERT INTO producto (nombre, precio_actual, stock, id_categoria)
SELECT '   ', 10.00, 1, MIN(id_categoria)
FROM categoria;

ROLLBACK;
```

Resultado esperado: PostgreSQL informa una violación de
`chk_producto_nombre_no_vacio`, con SQLSTATE `23514`.

### Caso inválido: nombre y apellido de cliente

```sql
BEGIN;

INSERT INTO cliente (nombre, apellido, correo_electronico)
VALUES ('   ', '   ', 'duia.nombres@example.com');

ROLLBACK;
```

Resultado esperado: PostgreSQL informa una violación de
`chk_cliente_nombre_apellido_no_vacios`, con SQLSTATE `23514`.

### Cierre de la verificación

Para cambiar el estado a verificado deben guardarse:

1. La salida real del `pg_dump`.
2. La salida de cada `INSERT` válido e inválido.
3. Los mensajes de error y SQLSTATE entregados por PostgreSQL.
4. La confirmación de que cada prueba terminó con `ROLLBACK`.
5. La repetición con `COMMIT` únicamente después de revisar los resultados.

No deben documentarse errores de PostgreSQL como resultados reales hasta haber
obtenido esa salida mediante una ejecución efectiva.
