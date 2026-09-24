Procedimiento de creación de la base de datos FoodStore
Objetivo

Este documento indica los pasos necesarios para crear la base de datos de trabajo del proyecto FoodStore y realizar la carga masiva de datos.

Los archivos necesarios se encuentran dentro de la carpeta FoodStore, ubicada en la raíz del proyecto.

FoodStore/
├── schema_completo.sql
└── data.sql
Paso 1: Crear la estructura de la base de datos

Primero se debe crear la base de datos de trabajo:

createdb foodstore_trabajo

Luego, ejecutar el archivo schema_completo.sql, ubicado dentro de la carpeta FoodStore:

psql -d foodstore_trabajo -f FoodStore/schema_completo.sql

Este archivo crea la estructura de la base de datos, incluyendo las tablas, relaciones, restricciones y demás elementos definidos en el esquema.

Verificación

Para comprobar que las tablas fueron creadas correctamente, ingresar a la base de datos:

psql -d foodstore_trabajo

Y ejecutar:

\dt
Paso 2: Realizar la carga masiva

Una vez creada correctamente la estructura, se debe ejecutar el archivo data.sql.

El archivo se encuentra en:

FoodStore/data.sql

Ejecutar:

psql -d foodstore_trabajo -f FoodStore/data.sql

Este archivo realiza la carga masiva de los datos necesarios para trabajar con la base.

Orden de ejecución

Los pasos deben realizarse en el siguiente orden:

1. Crear la base de datos foodstore_trabajo
            ↓
2. Ejecutar schema_completo.sql
            ↓
3. Ejecutar data.sql
            ↓
4. Verificar la estructura y los datos

No se debe ejecutar data.sql antes de schema_completo.sql, ya que las tablas necesarias para almacenar los datos todavía no existirían.

Verificación final

Después de ejecutar ambos archivos, se puede comprobar que los datos fueron cargados correctamente.

Por ejemplo:

SELECT COUNT(*) FROM cliente;

También se pueden verificar otras tablas:

SELECT COUNT(*) FROM producto;

SELECT COUNT(*) FROM pedido;

SELECT COUNT(*) FROM detalle_pedido;

Los resultados permiten comprobar que la carga masiva se realizó correctamente.
