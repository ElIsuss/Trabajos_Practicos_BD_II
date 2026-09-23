# Protocolo de Seguridad de la Base de Datos

## 1. Objetivo

Este protocolo establece el procedimiento de seguridad que se debe seguir para trabajar con la base de datos del proyecto.

El objetivo es evitar la perdida o modificacion accidental de los datos de la base de datos original, realizando el trabajo sobre una copia y manteniendo un respaldo que permita recuperar el estado anterior en caso de inconvenientes.

Este procedimiento se aplicara a todo cambio realizado sobre la base de datos, ya sea mediante scripts propios o generados automaticamente.

---

## 2. Entorno utilizado

* **Motor de base de datos:** PostgreSQL
* **Herramienta de administracion:** `psql`
* **Herramientas de respaldo y restauracion:** `pg_dump` y `psql`
* **Base de datos original:** `<NOMBRE_BASE_ORIGINAL>`
* **Base de datos de trabajo:** `<NOMBRE_COPIA_TRABAJO>`
* **Directorio de respaldos:** `backups/`

Los nombres de las bases de datos deberan reemplazarse por los utilizados realmente en el proyecto.

---

# 3. Paso 1  Copia de la base de datos

## 3.1. Creacion de la copia inicial

Al comenzar el proyecto se realizara una unica copia de la base de datos original.

La copia sera utilizada como base de trabajo durante el desarrollo, evitando realizar modificaciones directamente sobre la base original.

Para crear la copia se utilizara el comando `createdb` de PostgreSQL:

```bash
createdb -T <schema.sql> <schema_copia_trabajo>
```

Por ejemplo:

```bash
createdb -T foodstore foodstore_trabajo
```

A partir de este momento, todos los cambios y pruebas se realizaran sobre `foodstore_trabajo`.

La base original `foodstore` permanecera sin modificaciones mientras se desarrolla y verifica el trabajo.

## 3.2. Flujo de trabajo

El flujo establecido ser:

```text
BASE ORIGINAL
       |
COPIA DE TRABAJO
       |
Modificaciones y pruebas
       |
Verificaciones
       |
Aplicacion de los cambios
       |
BASE ORIGINAL
```

No se creara una nueva copia cada vez que se ejecute un script. La copia de trabajo sera creada al comenzar el proyecto y sera utilizada durante el desarrollo.

---

# 4. Paso 2  Transacciones

Todo script que realice operaciones de escritura debera probarse inicialmente dentro de una transaccion.

Antes de ejecutar modificaciones se iniciara una transaccion mediante:

```sql
BEGIN;
```

Luego se ejecutara el script que se desea probar.

Una vez finalizada la prueba, se utilizara:

```sql
ROLLBACK;
```

De esta manera, los cambios realizados durante la prueba no quedaran guardados en la base de datos.

## 4.1. Ejemplo

```sql
BEGIN;

UPDATE productos
SET precio = 1000
WHERE id = 1;

-- Se verifican las filas afectadas y el resultado.

ROLLBACK;
```

Si el resultado de la prueba es correcto, el cambio podra ejecutarse nuevamente y confirmarse mediante:

```sql
BEGIN;

UPDATE productos
SET precio = 1000
WHERE id = 1;

COMMIT;
```

El uso de `BEGIN` antes de las operaciones de escritura permite controlar y revisar los cambios antes de confirmarlos definitivamente.

---

# 5. Paso 3  Respaldo

## 5.1. Respaldo inicial

Al comenzar el trabajo se realizara un respaldo de la **base de datos original**, antes de realizar cualquier modificacion.

El respaldo se realizara mediante `pg_dump`.

Primero se creara el directorio de respaldos:

```bash
mkdir backups
```

Luego se realizara el respaldo:

```bash
pg_dump <schema.sql> > backups/backup_<FECHA>_<HORA>.sql
```

Por ejemplo:

```bash
pg_dump foodstore > backups/backup_2026-08-30_2045.sql
```

El nombre del archivo permitira identificar la fecha y hora en la que se realizo el respaldo.

El formato utilizado sera:

```text
backup_AAAA-MM-DD_HHMM.sql
```

Por ejemplo:

```text
backups/
 backup_2026-08-30_2045.sql
```

Este respaldo corresponde al estado de la base original al momento de comenzar el trabajo.

## 5.2. Respaldo antes de cambios estructurales

Ademas del respaldo inicial, antes de aplicar cambios estructurales importantes se debera realizar un nuevo respaldo de la base de trabajo.

Se consideran cambios estructurales, entre otros:

* `ALTER TABLE`
* `DROP TABLE`
* `DROP DATABASE`
* Migraciones
* Cambios importantes en la estructura de la base de datos

Para realizar el respaldo:

```bash
pg_dump <NOMBRE_COPIA_TRABAJO> > backups/backup_<FECHA>_<HORA>.sql
```

Por ejemplo:

```bash
pg_dump foodstore_trabajo > backups/backup_2026-08-30_2210.sql
```

De esta manera, se conserva un punto de recuperacion inmediatamente anterior al cambio estructural.
