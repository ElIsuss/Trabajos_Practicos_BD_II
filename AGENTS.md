# AGENTS.md

## Reglas para trabajar con la base de datos

Estas reglas son obligatorias para cualquier agente de IA que trabaje con la base de datos del proyecto.

### 1. Crear un backup antes de trabajar

Antes de realizar cualquier modificación en la base de datos, crear un backup de la base de trabajo.

El backup debe incluir la fecha y hora:

```bash
pg_dump foodstore_trabajo > backups/backup_AAAA-MM-DD_HHMM.sql
```

Nunca trabajar sobre la base original.

### 2. Explicar antes de modificar

Antes de ejecutar cambios, el agente debe explicar:

* qué se va a modificar;
* qué archivos o tablas serán afectados;
* por qué se necesita realizar el cambio;
* qué resultado se espera obtener.

### 3. Pedir confirmación

El agente **no debe ejecutar cambios importantes automáticamente**.

Primero debe explicar el cambio y esperar la confirmación del usuario.

Ejemplo:

> Se va a agregar un índice en `pedido(id_cliente, fecha_hora)` para mejorar las consultas de pedidos recientes por cliente. ¿Querés que lo aplique?

### 4. No hacer muchos cambios de golpe

Los cambios deben realizarse de forma **progresiva y controlada**.

Evitar modificar muchas tablas, archivos o estructuras al mismo tiempo.

Después de cada cambio importante, comprobar que todo siga funcionando correctamente.

### 5. Verificar después de modificar

Después de realizar un cambio, el agente debe comprobar que:

* la modificación se aplicó correctamente;
* no se perdieron datos;
* las relaciones siguen funcionando;
* no aparecieron errores inesperados.

### 6. No eliminar ni sobrescribir sin autorización

No ejecutar automáticamente:

```sql
DROP
TRUNCATE
DELETE
```

cuando puedan afectar datos existentes.

Si una operación puede provocar pérdida de información, debe explicarse primero y solicitar confirmación.

### 7. No asumir

Si el agente no sabe con certeza cómo está estructurada la base de datos, debe comprobarlo antes de modificarla.

No debe inventar tablas, columnas, relaciones, índices u otros elementos.

### 8. Informar el resultado

Al terminar una tarea, indicar brevemente:

* qué se modificó;
* qué se verificó;
* si hubo algún problema.

**Regla principal: primero backup → después explicar → pedir confirmación → realizar el cambio → verificar.**
