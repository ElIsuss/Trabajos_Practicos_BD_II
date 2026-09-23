# DUIA_informe_concurrencia

## Declaración de Uso de IA (DUIA) - Parte 2

### Herramienta

OpenCode / IA.

### Spec o prompt utilizado

> Explicar e indicar el paso a paso SQL para reproducir 3 escenarios de concurrencia en PostgreSQL (Row-Level Locking, Deadlock y Non-Repeatable Read) sobre las tablas producto y categoria, y redactar los hallazgos en formato de texto plano.

### Qué generó

La IA generó la secuencia de comandos SQL cruzados por pasos para la Sesión A y la Sesión B, las explicaciones teóricas de los bloqueos, el error 40P01 y los niveles de aislamiento MVCC. También generó el resumen de conclusiones de cada escenario.

### Qué se aceptó

Se aceptaron las secuencias de comandos `BEGIN`, `UPDATE`, `COMMIT` y `ROLLBACK` para reproducir las anomalías, la explicación del parámetro `deadlock_timeout` y la lógica teórica de los niveles de aislamiento.

### Qué se modificó o descartó y por qué

Se ajustaron los nombres de las tablas y campos al esquema real del proyecto (`producto` y `categoria`, con las columnas `id_producto` y `precio_actual`), descartando las consultas genéricas que utilizaban `id` y `precio`. También se adaptaron las sentencias de inserción para evitar conflictos con la columna `IDENTITY`.

### Verificación realizada

Se ejecutaron los pasos en dos terminales o sesiones de `psql` o pgAdmin contra la base de datos de trabajo `foodstore_trabajo`. Se confirmó el error 40P01 en vivo y se verificaron los aislamientos `READ COMMITTED` y `REPEATABLE READ`.
