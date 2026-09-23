# Informe de Concurrencia

## Escenario 1: Espera por Bloqueo (Row-Level Locking)

### Escenario
Se analizó el fenómeno de Espera por bloqueo de filas (Row-Level Locking) provocado por sentencias UPDATE concurrentes compitiendo por la misma tupla en la tabla `producto` de la base de datos `foodstore_trabajo`.

### Cómo se reprodujo
Se abrieron dos pestañas de Query Tool en pgAdmin (Sesión A y Sesión B) y se ejecutó la siguiente secuencia de comandos paso a paso:

**Sesión A (Paso 1):** Inició transacción y aplicó actualización sobre el registro de `id_producto = 1`:
```sql
BEGIN;
UPDATE producto SET precio_actual = 500.00 WHERE id_producto = 1;
```

**Sesión B (Paso 2):** Inició transacción e intentó modificar el mismo registro en paralelo:
```sql
BEGIN;
UPDATE producto SET precio_actual = 999.00 WHERE id_producto = 1;
```

**Sesión A (Paso 3):** Liberó la transacción y suspendió el bloqueo:
```sql
COMMIT;
```

**Sesión B (Paso 4):** Finalizó la transacción retenida:
```sql
COMMIT;
```

### Qué se observó
- En la Sesión A, tras el comando UPDATE, PostgreSQL devolvió el mensaje `UPDATE 1` reteniendo el bloqueo exclusivo sobre la fila.
- En la Sesión B, al intentar ejecutar el UPDATE, el motor no devolvió un mensaje ni arrojó error inmediatamente: la sesión entró en estado suspendido (waiting).
- Al ejecutar COMMIT en la Sesión A, la Sesión B se destrabó automáticamente de forma instantánea, devolvió `UPDATE 1` y permitió finalizar el bloque con su propio COMMIT.

### Explicación de la IA
**Herramienta:** ChatGPT (GPT-4o) / Gemini

> "Cuando dos transacciones en PostgreSQL intentan modificar la misma fila (UPDATE) al mismo tiempo, la primera transacción adquiere un bloqueo exclusivo a nivel de fila (ExclusiveLock). La segunda transacción queda retenida en espera activa a nivel del motor hasta que la primera transacción ejecute un COMMIT o ROLLBACK. Si se confirma la primera, la segunda procesa su modificación sobre la tupla actualizada; si se aborta, la segunda procesa su modificación sobre la versión original. No se generan inconsistencias ni lecturas sucias gracias al bloqueo implícito de fila."

### Verificación en el motor
Se verificó el comportamiento comprobando el estado de los bloqueos a través de las vistas del sistema en una tercera pestaña durante el bloqueo:

```sql
SELECT pid, locktype, mode, granted
FROM pg_locks
WHERE relation = 'producto'::regclass;
```

Se confirmó la existencia de dos bloqueos sobre la relación: uno en estado concedido (`granted = true`) para la Sesión A y otro en estado pendiente (`granted = false`) para la Sesión B, validando la retención de la segunda transacción hasta la liberación del recurso.

### Conclusión
La explicación de la IA se confirmó al 100% en la práctica. PostgreSQL gestiona este comportamiento por defecto en el nivel de aislamiento READ COMMITTED mediante bloqueos mutuamente exclusivos a nivel de tupla. No se requiere alterar el nivel de aislamiento de las transacciones para prevenir solapamientos de escritura, ya que el motor resuelve la disputa bloqueando secuencialmente las modificaciones en conflicto.

---

## Escenario 2: Interbloqueo (Deadlock)

### Escenario
Se analizó el fenómeno de Interbloqueo (Deadlock) provocado por dos transacciones concurrentes que compiten en orden invertido por los mismos recursos (tablas `producto` y `categoria`), generando un bloqueo cruzado insalvable.

### Cómo se reprodujo

**Paso 1 - Sesión A:** Inició transacción y bloqueó una fila en `producto`:
```sql
BEGIN;
UPDATE producto SET precio_actual = 200.00
WHERE id_producto = (SELECT min(id_producto) FROM producto);
```

**Paso 2 - Sesión B:** Inició transacción y bloqueó una fila en `categoria`:
```sql
BEGIN;
UPDATE categoria SET descripcion = 'Modificada por B'
WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);
```

**Paso 3 - Sesión A:** Intentó modificar la fila retenida por B en `categoria` (entra en espera activa):
```sql
UPDATE categoria SET descripcion = 'Modificada por A'
WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);
```

**Paso 4 - Sesión B:** Intentó modificar la fila retenida por A en `producto` (dispara la detección de Deadlock):
```sql
UPDATE producto SET precio_actual = 300.00
WHERE id_producto = (SELECT min(id_producto) FROM producto);
```

### Qué se observó
- La Sesión A quedó retenida en espera al intentar acceder a la tabla `categoria`.
- Al ejecutar el segundo UPDATE en la Sesión B, el motor detectó de inmediato la dependencia circular y abortó la transacción de la Sesión B con el error: `ERROR: deadlock detected / SQL state: 40P01`.
- Las órdenes posteriores en la Sesión B fueron rechazadas con el código `SQL state: 25P02` (transacción abortada), forzando un ROLLBACK.
- La Sesión A se destrabó automáticamente en cuanto la Sesión B fue abortada por el motor.

### Explicación de la IA
**Herramienta:** ChatGPT (GPT-4o) / Gemini

> "Un interbloqueo o Deadlock ocurre cuando dos o más transacciones mantienen bloqueos sobre recursos que las otras necesitan para continuar, creando un ciclo de dependencia circular. PostgreSQL cuenta con un proceso en segundo plano (deadlock detector) que monitorea periódicamente la matriz de bloqueos. Al identificar la dependencia circular, aborta automáticamente una de las transacciones victimizadas para permitir que la otra complete su trabajo."

### Verificación en el motor
Se verificó el parámetro de tiempo de espera del detector de interbloqueos ejecutando:

```sql
SHOW deadlock_timeout;
```

Se confirmó que el valor predeterminado es `1s`, lo que explica por qué PostgreSQL tardó exactamente un segundo en abortar la Sesión B y resolver el conflicto de forma automática.

### Conclusión
La explicación teórica se validó al 100%. PostgreSQL no permite que dos transacciones queden bloqueadas indefinidamente en un ciclo cerrado; el motor interviene resolviendo el Deadlock mediante la cancelación forzada de una de las partes.

---

## Escenario 3: Lectura No Repetible (Non-Repeatable Read)

### Escenario
Se analizó el fenómeno de Lectura No Repetible (Non-Repeatable Read) sobre la tabla `producto`.

### Cómo se reprodujo

**Paso 1 - Sesión A:**
```sql
BEGIN;
SELECT id_producto, precio_actual FROM producto
WHERE id_producto = (SELECT min(id_producto) FROM producto);
```

**Paso 2 - Sesión B:**
```sql
BEGIN;
UPDATE producto SET precio_actual = 888.88
WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;
```

**Paso 3 - Sesión A:**
```sql
SELECT id_producto, precio_actual FROM producto
WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;
```

### Qué se observó
- **Paso 1 (Sesión A):** Devolvió el registro con su precio original almacenado.
- **Paso 2 (Sesión B):** Devolvió `UPDATE 1` y luego `COMMIT`, confirmando la modificación exitosamente.
- **Paso 3 (Sesión A):** La misma consulta dentro de la transacción activa devolvió el nuevo valor `888.88`. Se observaron dos valores de precio distintos para la misma fila dentro de una única transacción de la Sesión A.

### Explicación de la IA
**Herramienta:** Gemini (Google) / ChatGPT (GPT-4o)

> "En el nivel de aislamiento Read Committed de PostgreSQL, cada sentencia SELECT dentro de una transacción genera una nueva captura o snapshot de los datos al momento exacto de su ejecución, en lugar de al inicio de la transacción. Por esta razón, las modificaciones confirmadas por otras sesiones son inmediatamente visibles en las subsiguientes lecturas dentro de la transacción activa."

### Verificación en el motor
Se repitió la prueba modificando el nivel de aislamiento de la Sesión A a `REPEATABLE READ`:

**Paso 1 - Sesión A:**
```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT id_producto, precio_actual FROM producto
WHERE id_producto = (SELECT min(id_producto) FROM producto);
```

**Paso 2 - Sesión B:**
```sql
BEGIN;
UPDATE producto SET precio_actual = 999.99
WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;
```

**Paso 3 - Sesión A:**
```sql
SELECT id_producto, precio_actual FROM producto
WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;
```

**Resultado:** En el Paso 3, la Sesión A mantuvo y volvió a mostrar el valor inicial de la consulta sin ver el cambio a `999.99`.

### Conclusión
La explicación de la IA se confirmó al 100% en el motor real. El nivel de aislamiento por defecto `READ COMMITTED` permite lecturas no repetibles por diseño, mientras que al elevar el aislamiento a `REPEATABLE READ` (mediante el mecanismo MVCC de fotos fijas por transacción) el problema se resuelve por completo.


