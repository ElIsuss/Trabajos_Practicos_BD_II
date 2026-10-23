# Requisitos — Roles y permisos de Food Store

## Propósito

Definir roles de PostgreSQL para Food Store conforme al principio de mínimo privilegio. Cada identidad debe recibir únicamente los permisos indispensables para su responsabilidad.

## Alcance del esquema

Las tablas existentes son `categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido` y `usuario`.

La tabla `usuario` contiene datos personales y credenciales: `mail`, `celular` y, especialmente, `contrasena`. Ningún rol operativo debe tener acceso a la columna `contrasena`.

## Roles requeridos

| Rol | Tipo | Necesidad que cubre |
|---|---|---|
| `rol_app_lectura` | Grupo (`NOLOGIN`) | Consultar el catálogo público de categorías y productos activos. |
| `rol_app_escritura` | Grupo (`NOLOGIN`) | Registrar pedidos y sus detalles, además de consultar el catálogo necesario para la operación. |
| `rol_soporte` | Grupo (`NOLOGIN`) | Consultar datos de contacto y realizar actualizaciones limitadas de cuentas de usuario, sin acceder a contraseñas. |
| `rol_reportes` | Grupo (`NOLOGIN`) | Consultar los datos necesarios para informes de ventas y productos, sin modificarlos ni acceder a datos personales. |
| `app_web` | Inicio de sesión (`LOGIN`) | Identidad técnica de la aplicación web; recibe únicamente los roles de lectura y escritura. |
| `admin_datos` | Inicio de sesión (`LOGIN`) | Identidad administrativa controlada para tareas de consulta y mantenimiento de datos; no será superusuario ni tendrá `CREATEROLE`. |

## Requisitos de seguridad

1. Los roles de grupo deben ser `NOLOGIN`; solo `app_web` y `admin_datos` pueden iniciar sesión.
2. Se debe revocar el acceso implícito de `PUBLIC` sobre el esquema `public`, las tablas y las secuencias involucradas.
3. `rol_app_lectura` solo puede consultar `categoria` y `producto`.
4. `rol_app_escritura` puede consultar `categoria` y `producto`, e insertar pedidos y detalles; no puede eliminar datos ni modificar el catálogo.
5. `rol_soporte` puede consultar columnas no sensibles de `usuario` y actualizar únicamente los datos de contacto y el estado lógico de una cuenta. No puede consultar ni actualizar `contrasena`.
6. `rol_reportes` puede consultar `categoria`, `producto`, `pedido` y `detalle_pedido`; no puede modificar datos ni consultar `cliente` o `usuario`.
7. `app_web` será miembro de `rol_app_lectura` y `rol_app_escritura`, pero no de `rol_soporte`, `rol_reportes` ni `admin_datos`.
8. `admin_datos` no debe ser `SUPERUSER`, `CREATEDB`, `CREATEROLE` ni `REPLICATION`; tampoco debe tener `ADMIN OPTION` sobre roles de aplicación.
9. Las tablas futuras deben heredar una política explícita mediante `ALTER DEFAULT PRIVILEGES`.
10. La función de autenticación y la de reseteo de contraseña se reconstruirán antes de la Parte C. Sus permisos `EXECUTE` se definirán al conocer su firma y su modelo de seguridad.

## Criterios de aceptación

- Las consultas de verificación muestran exactamente los privilegios documentados.
- Ningún rol de aplicación puede leer `usuario.contrasena`.
- Un rol de bajo privilegio no puede otorgarse ni otorgar a terceros membresía en `admin_datos`.
- `app_web` puede operar pedidos sin permisos de administración ni de soporte.
