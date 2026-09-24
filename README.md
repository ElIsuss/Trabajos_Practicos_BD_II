# Procedimiento de creación de la base de datos FoodStore

## Objetivo

Este documento indica los pasos necesarios para crear la base de datos de trabajo del proyecto FoodStore y realizar la carga masiva de datos.

Los archivos necesarios se encuentran dentro de la carpeta FoodStore, ubicada en la raíz del proyecto.


FoodStore/
├── schema_completo.sql
└── data.sql

## Paso 1: Crear la estructura de la base de datos

Primero se debe crear la base de datos de trabajo:

1. Dentro de Dbeaver crea la base de datos (food_store_Juan_e_Isaias)
2. En un script vinculado a esa base de datos copiar el codigo que se encuentra en "schema_completo.sql"
3. Para confirmar que se genero la base de datos puede ejecutar el siguiente script:
    
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    
    Le deberia aparecer las tablas de la base de datos:
    categoria
    cliente
    detalle_pedido
    pedido
    producto


## Paso 2: Realizar la carga masiva

1. Una vez creada correctamente la estructura, se debe ejecutar el archivo "data.sql" que se encuentra en la carpeta "food_store"
2. copie el codigo de ese archivo en un script vinculado a la base de datos creada
3. ejecute el script
4. para verificar que se cargo masivamente puede realizar las siguientes consultas:

    A-verificar cuántos registros se cargaron en cada tabla

        SELECT 'categoria' AS tabla, COUNT(*) FROM categoria
        UNION ALL
        SELECT 'cliente', COUNT(*) FROM cliente
        UNION ALL
        SELECT 'producto', COUNT(*) FROM producto
        UNION ALL
        SELECT 'pedido', COUNT(*) FROM pedido
        UNION ALL
        SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

    B-comprobar que todos los productos tengan una categoría válida.

        SELECT
            'Productos sin categoría' AS verificacion,
            COUNT(*) AS errores
        FROM producto p
        LEFT JOIN categoria c ON p.id_categoria = c.id_categoria
        WHERE c.id_categoria IS NULL;

    C-verifica la relación entre pedido y cliente

        SELECT
            'Pedidos sin cliente' AS verificacion,
            COUNT(*) AS errores
        FROM pedido p
        LEFT JOIN cliente c ON p.id_cliente = c.id_cliente
        WHERE c.id_cliente IS NULL;

## Paso 3: Agregamos usuarios al sistema
1. Una vez cargados los datos debemos ejecutar el script llamado "seguridad_usuario" ubicado en la carpeta "food_store" en el TP 5
2. Copie el codigo de ese archivo en un script vinculo a la base de datos 
3. Ejecute todo el codigo
4. Para verificar que este script de seguridad se ejecutó correctamente, corra el siguiente script

        SELECT COUNT(*) AS cantidad_usuarios
        FROM usuario;
    
    Este comando lo que hace es agregar usuarios al sistema y los relaciona con clientes exitentes, por ende, 
    al hacer el comando de verificacion deberia tener la misma cantidad de usuarios como de clientes (20.000)
### Orden de ejecución

Los pasos deben realizarse en el siguiente orden:

```text
1. Crear la base de datos foodstore_trabajo
            ↓
2. Ejecutar schema_completo.sql
            ↓
3. Ejecutar data.sql
            ↓
4. Verificar la estructura y los datos
```

No se debe ejecutar data.sql antes de schema_completo.sql, ya que las tablas necesarias para almacenar los datos todavía no existirían.

## Verificación final

Después de ejecutar ambos archivos, se puede comprobar que los datos fueron cargados correctamente.

Por ejemplo:


SELECT COUNT(*) FROM cliente;


SELECT COUNT(*) FROM producto;


SELECT COUNT(*) FROM pedido;


SELECT COUNT(*) FROM detalle_pedido;


Los resultados permiten comprobar que la carga masiva se realizó correctamente