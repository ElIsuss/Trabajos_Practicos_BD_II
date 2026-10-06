# Informe RTA — TP Unidad 4

**Tema:** Forma Normal de Boyce-Codd (FNBC) y desnormalización controlada
**Proyecto integrador de referencia:** Food Store
**Motor:** PostgreSQL 17 — base `foodstore_trabajo`
**Alumno:** Juan / Isaías
---
## Parte 1 — Análisis y aplicación de la FNBC: `control_lote_almacen`

### Esquema original

```sql
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);
```
**Instancia de ejemplo:**
| lote_id | deposito_id | responsable_control_id |
|---|---|---|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

**Reglas de negocio relevadas (área de logística):**
- Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado.
- Cada responsable de control pertenece, como dato maestro de la dotación de personal, a un único depósito: no controla lotes coordinados desde depósitos distintos.

**Notación usada en todo el informe:** `L = LoteID`, `D = DepositoID`, `R = ResponsableControlID`. `X → Y` se lee "X determina a Y". El universo de atributos es `U = { L, D, R }`.
---
### a) Dependencias funcionales
> *Enunciar, en notación formal, las dependencias funcionales que se desprenden de la regla de negocio, usando los nombres de atributo LoteID, DepositoID y ResponsableControlID.*

**RTA:**
| Regla de negocio | Dependencia |
|---|---|
| Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado. | **DF1:** `{ LoteID, DepositoID } → ResponsableControlID` |
| Cada responsable de control pertenece, como dato maestro de la dotación de personal, a un único depósito. | **DF2:** `ResponsableControlID → DepositoID` |

**DF1** es la que modela la clave primaria declarada `(lote_id, deposito_id)`.

**DF2** es la que introduce la dependencia parcial problemática: su determinante es un único atributo, y por eso no alcanza para cerrar el universo de atributos. Es la DF que va a resultar violada en el inciso (c).

No se postulan `LoteID → DepositoID` ni `LoteID → ResponsableControlID`, porque un lote puede ser controlado desde varios depósitos y por lo tanto por varios responsables. La instancia de ejemplo lo confirma: el responsable `801` atiende los lotes `501` y `502`.

---

### b) Clausuras y claves candidatas

> *Calcular la clausura de los subconjuntos de atributos que resulten candidatos razonables y determinar el conjunto completo de claves candidatas del esquema. Indicar qué atributos son primos y cuáles no.*

**RTA:**
#### Clausura de `{ L, D }`
```
{ L, D }⁺ = { L, D }     → aplico DF1: agrego R
         = { L, D, R }   → cubre U completo ✓
```
`{L, D}` es superclave. Verifico si es mínima evaluando sus subconjuntos propios:
- `{ L }⁺ = { L }` → no cubre U
- `{ D }⁺ = { D }` → no cubre U
Ningún subconjunto propio es superclave → **`{ L, D }` es clave candidata**.
#### Clausura de `{ R }
```
{ R }⁺ = { R }     → aplico DF2: agrego D
      = { R, D }   → no hay más DF aplicables
```
`{R}⁺ = { R, D }` no cubre U (falta L). **`{ R }` no es clave candidata.**
#### Clausura de `{ L, R }`
```
{ L, R }⁺ = { L, R }     → aplico DF2: agrego D
          = { L, R, D }   → cubre U completo ✓
```
`{L, R}` es superclave. Verifico minimalidad:
- `{ L }⁺ = { L }` → no cubre U
- `{ R }⁺ = { R, D }` → no cubre U (falta L)
→ **`{ L, R }` es clave candidata.**
#### Resultado
**Conjunto completo de claves candidatas:**
```
{ {LoteID, DepositoID} , {LoteID, ResponsableControlID} }
```
**Atributos primos** — los que pertenecen a alguna clave candidata:
| Atributo | ¿Primo? | Razón |
|---|---|---|
| `LoteID` | Sí | Aparece en las dos claves candidatas |
| `DepositoID` | Sí | Aparece en `{L, D}` |
| `ResponsableControlID` | Sí | Aparece en `{L, R}` |
**Atributos no primos:** ninguno. Los tres atributos del universo son primos.
Que no queden atributos no primos es lo que evita un paso de *projection* adicional en la descomposición.
---
### c) Verificación de BCNF
> *Determinar, con la definición formal de BCNF (no con la de 3FN), si control_lote_almacen cumple o no la forma normal. Justificar identificando explícitamente la dependencia funcional violatoria, si la hubiera, y explicando por qué su determinante no es superclave.*

**RtA:**
**Definición formal:** un esquema `R` está en BCNF si y solo si para toda dependencia funcional no trivial `X → Y` que se cumple en `R`, `X` es superclave de `R`.
Las DF no triviales del esquema son:
| DF | Determinante | ¿Es superclave? | Criterio |
|---|---|---|---|
| `{L, D} → R` | `{L, D}` | **Sí** | `{L, D}⁺ = {L, D, R} = U` |
| `R → D` | `{R}` | **No** | `{R}⁺ = {R, D} ≠ U` |
**`control_lote_almacen` NO está en BCNF.**
La dependencia violatoria es **`ResponsableControlID → DepositoID`**. Su determinante `{ R }` no es superclave porque su clausura `{R, D }` no alcanza a cubrir el atributo `LoteID`.
#### Por qué no la rescata la clave candidata alternativa `{ L, R }`
Esta es la diferencia con la definición de 3FN, y es lo que la consigna pide no aplicar:
| Forma normal | Condición para toda DF no trivial `X → Y` |
|---|---|
| **3FN** | `X` es superclave **o** `Y` es un atributo primo |
| **BCNF** | `X` es **siempre** superclave |
En este caso `R → D` **pasaría el filtro de 3FN**: `R` no es superclave, pero `D` (`DepositoID`) sí es un atributo primo, ya que pertenece a la clave candidata `{L, D}`. En 3FN esa DF sería perdonada.
**En FNBC no existe esa segunda alternativa.** Cada DF se juzga de forma individual, sin importar si su atributo determinado es primo ni si el esquema admite claves candidatas alternativas. Por eso el veredicto es negativo: `R` no es superclave, y punto.
---
### d) Anomalías sobre la instancia de ejemplo
> *Con la instancia de ejemplo provista, redactar en un párrafo cada una de las tres anomalías clásicas que la violación detectada habilita, describiendo un escenario concreto sobre esos datos.*

**RTA:**
#### Anomalía de inserción
Supongamos que se contrata al responsable `803` y se lo asigna al depósito `32` como dato maestro del personal, pero todavía no se le asignó ningún lote para controlar. Es imposible registrar que `803` pertenece al depósito `32`: la única tabla disponible es `control_lote_almacen`, y `lote_id` forma parte de la clave primaria y admite `NOT NULL`, por lo que no puede quedar vacío. Para insertar la fila habría que inventar un `lote_id` ficticio. El hecho "803 pertenece al depósito 32" queda completamente fuera del sistema hasta que exista un lote real que lo justifique. La restricción de clave primaria es la que fuerza el invento.
#### Anomalía de borrado
El lote `503` es el único lote que intervino el depósito `31`. Si se borra la fila `(503, 31, 802)` con el fin de eliminar ese control de calidad, se elimina también el único registro que evidenció que el responsable `802` pertenece al depósito `31`. Se pierde un dato maestro de dotación de personal como efecto colateral de eliminar un hecho operativo. Los dos datos tienen ciclo de vida distinto y no deberían compartir fila.
#### Anomalía de actualización
El responsable `801` aparece en dos filas: `(501, 30, 801)` y `(502, 30, 801)`, ambas correspondientes al depósito `30`. Si `801` es transferido al depósito `33`, hay que actualizar `deposito_id` en las dos filas. Si por error de tipeo o por concurrencia entre dos operaciones simultáneas se actualiza solo una de ellas, la base queda en estado inconsistente: `801` queda registrado en el depósito `30` para el lote `501` y en el depósito `33` para el lote `502`. Una misma persona aparece perteneciendo a dos depósitos distintos, violando la DF2 y la regla de negocio que la sustenta.
---
### e) Descomposición sin pérdida — script SQL
> *Aplicar el algoritmo de descomposición sin pérdida visto en clase y entregar el script SQL completo de las tablas resultantes, incluyendo sus claves primarias, sus restricciones FOREIGN KEY, y una vista de compatibilidad que reconstruya la relación original mediante una reunión natural.*

**RTA:**
El algoritmo de descomposición se aplica sobre la DF violatoria `R → D`, separando el atributo **determinado** (`DepositoID`) del resto del esquema:
| Esquema | Contenido | Tabla resultante |
|---|---|---|
| **R1** | `{ R, D }` — la DF misma | `responsable_deposito` |
| **R2** | `{ L, R }` — el original menos el determinado, más el determinante | `control_lote` |
```sql

-- R1: donde vive el dato maestro de personal
CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT NOT NULL
        REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL
        REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

-- R2: el hecho operativo, sin el atributo determinado
CREATE TABLE control_lote (
    lote_id                 BIGINT NOT NULL
        REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL
        REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Vista de compatibilidad: reconstruye la relación original
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
FROM control_lote          cl
JOIN responsable_deposito  rd
    ON cl.responsable_control_id = rd.responsable_control_id;
```

#### Dos decisiones que explican el resultado
**En `responsable_deposito`, la clave primaria es `responsable_control_id`.** Eso es lo que *materializa* la DF `R → D`: al ser clave primaria, la restricción de unicidad impide que un responsable figure asociado a dos depósitos distintos. La DF deja de ser una afirmación teórica del papel y pasa a estar garantizada por el esquema mismo. Sin esa PK, la DF2 quedaría sin respaldo en la base.
**En `control_lote`, la clave primaria cambia a `(lote_id, responsable_control_id)`.** Como `deposito_id` deja de pertenecer a este esquema, la clave primaria declarada en el esquema original, `(lote_id, deposito_id)`, es inválida. La PK correcta es la **otra clave candidata** determinada en el inciso (b). No puede ser `lote_id` en solitario, porque eso asumiría que cada lote tiene un único responsable, algo que la consigna no afirma: un mismo lote puede ser controlado simultáneamente desde varios depósitos.
#### Efecto sobre las anomalías
En el esquema descompuesto, la pertenencia de un responsable a un depósito vive en `responsable_deposito` con clave propia. Esto resuelve las tres anomalías del inciso (d):
| Anomalía | Cómo queda resuelta |
|---|---|
| Inserción | `803` puede registrarse en el depósito `32` con una única fila, sin ningún lote asociado |
| Borrado | Eliminar un lote de `control_lote` no afecta el dato maestro del responsable |
| Actualización | Cambiar el depósito de `801` requiere modificar exactamente **una** fila de `responsable_deposito` |
Script completo y ejecutable: `Unidad_4/tp_fnbc_control_lote.sql`.
---
### f) Sin pérdida y migración de datos
> *Justificar por escrito, invocando el criterio de superclave sobre el atributo común de la descomposición, por qué la reunión de las dos tablas resultantes es sin pérdida, y migrar los datos de la instancia de ejemplo hacia las tablas descompuestas, verificando la equivalencia mediante la vista de compatibilidad.*

**RTA:**
#### Justificación por el criterio de superclave (teorema de Heath)
El teorema de Heath establece que una descomposición `R → {R1, R2}` es **sin pérdida** si y solo si el conjunto de atributos común a `R1` y `R2` es superclave de al menos uno de los dos esquemas resultantes.
El atributo común a `responsable_deposito` (R1) y `control_lote` (R2) es **`responsable_control_id`**.
En `R1`, ese atributo es la **clave primaria** de la tabla. Toda clave primaria es superclave del esquema, por lo tanto `responsable_control_id` es superclave de `R1`.
La condición del teorema se cumple, y en consecuencia la reunión `R1 ⋈ R2` reconstruye exactamente la relación original, sin generar tuplas espurias.
Como control, se verificó además que en `R2` el atributo `responsable_control_id` **no** es superclave: `{L, R}⁺ = {L, R, D}` sí cierra el universo, pero `{R}⁺ = {R, D}` no alcanza a `L`, ya que `control_lote` no contiene `deposito_id`. La superclave se aporta del lado de R1, que es lo que el teorema exige.
#### Migración de la instancia de ejemplo

```sql
-- R1: un registro por responsable
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
VALUES (801, 30),
       (802, 31);

-- R2: un registro por (lote, responsable)
INSERT INTO control_lote (lote_id, responsable_control_id)
VALUES (501, 801),
       (502, 801),
       (503, 802);
```
#### Verificación de la equivalencia
**Primera comprobación — la vista de compatibilidad** debe devolver exactamente la instancia original del esquema no normalizado:
```sql
SELECT * FROM v_control_lote_almacen ORDER BY lote_id;
```
| lote_id | deposito_id | responsable_control_id |
|---|---|---|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |
**Segunda comprobación — diferencia simétrica.** Esta es la prueba formal de la sin pérdida. `EXCEPT` devuelve únicamente las tuplas que difieren entre ambos lados, por lo que aplicándolo en las dos direcciones se obtiene el conjunto de todo lo que no coincide. Si el resultado es vacío, no hay tuplas perdidas ni tuplas espurias:

```sql
SELECT * FROM (
    (SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen)
    UNION ALL
    (SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen)
) AS diferencia;
```

**Resultado obtenido: 0 filas.** Ninguna tupla faltante, ninguna tupla sobrante.

**Tercera comprobación — conteo comparado:**

```sql
SELECT (SELECT COUNT(*) FROM control_lote_almacen)   AS filas_original,
       (SELECT COUNT(*) FROM v_control_lote_almacen) AS filas_vista;
```

| filas_original | filas_vista |
|---|---|
| 3 | 3 |

**Cuarta comprobación — la DF `R → D` garantizada por el esquema.** Ningún responsable puede aparecer con dos depósitos distintos:

```sql
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos
FROM responsable_deposito
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;
```

**Resultado obtenido: 0 filas.**

#### Conclusión

La equivalencia queda verificada empíricamente: la vista reproduce la relación original sin pérdida ni aparición de tuplas espurias, y el esquema descompuesto garantiza por sí mismo la dependencia funcional que motivó la descomposición.

---

## Parte 2 — Consulta con desnormalización controlada

> *Pendiente de completarse. Requiere la medición con `EXPLAIN ANALYZE` sobre la base poblada y la ejecución del script `Unidad_4/tp_desnormalizacion_top_categorias.sql`.*

---

## Evidencia SQL

| Artefacto | Ruta |
|---|---|
| Script de la Parte 1 | `Unidad_4/tp_fnbc_control_lote.sql` |
| Script de la Parte 2 | `Unidad_4/tp_desnormalizacion_top_categorias.sql` (pendiente) |