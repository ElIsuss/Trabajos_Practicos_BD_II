# Diseño — Roles y permisos de Food Store

## Decisiones de diseño

### Roles de grupo y roles de inicio de sesión

Los permisos se concentran en cuatro roles de grupo `NOLOGIN`. Las cuentas que inician sesión reciben membresías puntuales, evitando duplicar privilegios y permitiendo auditar qué permisos obtiene cada identidad.

| Rol | Permisos previstos |
|---|---|
| `rol_app_lectura` | `USAGE` del esquema `public`; `SELECT` sobre `categoria` y `producto`. |
| `rol_app_escritura` | `USAGE` del esquema; `SELECT` sobre `categoria` y `producto`; `INSERT` sobre `pedido` y `detalle_pedido`; uso de las secuencias asociadas a esas tablas. |
| `rol_soporte` | `USAGE` del esquema; `SELECT` sobre columnas no sensibles de `usuario`; `UPDATE (mail, celular, eliminado)` sobre `usuario`; `SELECT` sobre columnas de contacto de `cliente` si es necesario para identificar el vínculo. |
| `rol_reportes` | `USAGE` del esquema; `SELECT` sobre `categoria`, `producto`, `pedido` y `detalle_pedido`. |
| `app_web` | `LOGIN`, miembro de `rol_app_lectura` y `rol_app_escritura`. |
| `admin_datos` | `LOGIN`, miembro de los roles de grupo que correspondan a tareas administrativas aprobadas; sin atributos de superusuario ni administración de roles. |

## Protección de datos personales

El permiso a nivel de columna se implementará sobre `usuario`:

```text
Permitidas para soporte: id, nombre, apellido, mail, celular, rol, eliminado,
created_at, id_cliente.

Excluida explícitamente: contrasena.
```

La modificación directa de `contrasena` no se otorgará a ningún rol de soporte. El futuro reseteo se realizará mediante una función específica, con permisos y validaciones definidos al reconstruir `fn_resetear_password`.

## Prevención del escalamiento de privilegios

- `rol_app_lectura`, `rol_app_escritura`, `rol_soporte` y `rol_reportes` no tendrán `CREATEROLE` ni `ADMIN OPTION`.
- `app_web` no tendrá pertenencia ni capacidad de administrar `admin_datos`.
- `admin_datos` no será superusuario ni podrá crear o modificar roles.
- El propietario técnico de los objetos y el ejecutor de cambios de roles será `postgres` durante el TP; no se usará como cuenta operativa de la aplicación.

Esto permite que el intento de escalamiento del simulacro de la Parte C falle y quede registrado en el log.

## Política para objetos futuros

El script `sql/roles.sql` incluirá `ALTER DEFAULT PRIVILEGES` ejecutado por el propietario `postgres`, para revocar privilegios por defecto de `PUBLIC` y dejar documentada la política que deberán seguir las tablas y secuencias nuevas.

## Verificación prevista

Después de aplicar el script se comprobará:

1. Roles y atributos con `\du` o `pg_roles`.
2. Privilegios de tablas con `information_schema.role_table_grants`.
3. Privilegios de columnas con `information_schema.column_privileges`.
4. Ausencia de permisos para `usuario.contrasena`.
5. Fallo controlado de un intento de `GRANT admin_datos TO app_web` ejecutado con una cuenta de bajo privilegio.
