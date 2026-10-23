# BITÁCORA — Unidad 5: Seguridad y Auditoría en PostgreSQL

Base de datos de trabajo: `foodstore_trabajo`

---

## Parte A — Diseño e implementación de roles y permisos

### A.1 — Especificación de roles

**Fecha:** 2026-10-23

Se redactó la especificación de roles en `docs/kiro_roles_spec/`:
- `requirements.md`: lista los 6 roles con su justificación, requisitos de seguridad y criterios de aceptación.
- `design.md`: decisiones de diseño, tabla de permisos por rol, política para objetos futuros y plan de verificación.

**Roles definidos:**

| Rol | Tipo | Justificación |
|---|---|---|
| `rol_app_lectura` | Grupo NOLOGIN | Consultar catálogo público (categorías y productos); no necesita modificar ni acceder a datos de clientes. |
| `rol_app_escritura` | Grupo NOLOGIN | Registrar pedidos y detalles; necesita leer el catálogo para validar productos, pero no modificarlo. |
| `rol_soporte` | Grupo NOLOGIN | Consultar y actualizar datos de contacto de usuarios sin acceder a contraseñas ni datos financieros. |
| `rol_reportes` | Grupo NOLOGIN | Consultar datos de ventas para informes; solo lectura, sin acceso a datos personales. |
| `app_web` | LOGIN | Identidad técnica de la aplicación web; recibe lectura y escritura, no administración. |
| `admin_datos` | LOGIN | Identidad administrativa controlada; sin superusuario ni capacidad de crear roles. |

---

### A.2 — Implementación de roles.sql

**Fecha:** 2026-10-23  
**Archivo:** `sql/roles.sql`

Se escribió el script con:
- `CREATE ROLE` para los 6 roles con atributos explícitos.
- `GRANT` de privilegios de esquema, tablas y secuencias por rol.
- Permiso a nivel de columna sobre `usuario` para `rol_soporte` (columna `contrasena` excluida).
- `REVOKE ALL ... FROM PUBLIC` sobre esquema, tablas y secuencias actuales.
- `ALTER DEFAULT PRIVILEGES` para que tablas, secuencias y funciones futuras hereden la misma política restrictiva.

---

### A.3 — Verificación de permisos

**Fecha:** 2026-10-23  
**Script:** `sql/verificacion.sql`  
**Resultado completo:** `docs/verificacion_resultado.txt`

Se ejecutaron 8 controles sobre `foodstore_trabajo`. Resultado:

| Control | Descripción | Resultado |
|---|---|---|
| V-1 | Atributos de roles | ✓ |
| V-2 | Membresías | ✓ |
| V-3 | Privilegios de tabla | ✓ |
| V-4 | Privilegios de columna (usuario) | ✓ |
| V-5 | contrasena inaccesible para roles de app | ✓ |
| V-6 | Privilegios de secuencias | ✓ |
| V-7 | Intento de escalamiento | Pendiente — Parte C |
| V-8 | ALTER DEFAULT PRIVILEGES | ✓ |

Todos los controles ejecutados superados. El esquema de permisos coincide exactamente con la especificación.

---

### A.4 — Auditoría con IA

**Fecha:** 2026-10-23  
**Herramienta:** OpenCode  
**Archivo auditado:** `sql/roles.sql`

La IA revisó el script completo e identificó permisos faltantes, redundancias y mejoras de diseño. Se analizaron sus sugerencias y se aplicaron solo las que respetan el principio de mínimo privilegio definido en la especificación.

#### Sugerencias evaluadas

**1. `rol_app_escritura` sin SELECT en `cliente` — aplicado ✓**

La IA señaló que insertar un pedido requiere poder validar que `id_cliente` existe. Sin `SELECT` en `cliente`, cualquier validación antes del INSERT falla en tiempo de ejecución. Se aplicó el permiso porque es necesario para la operación que el rol tiene habilitada.

**2. `rol_reportes` sin SELECT en `cliente` — aplicado ✓**

La IA indicó que los reportes de ventas necesitan hacer JOIN con `cliente` para mostrar información útil. Se aplicó porque entra dentro de la responsabilidad de lectura de datos de ventas que define el rol.

**3. `rol_soporte` con SELECT en `pedido` y `detalle_pedido` — NO aplicado ✗**

> _Caso de permiso más amplio de lo necesario._

La IA propuso otorgar `SELECT` sobre `pedido` y `detalle_pedido` a `rol_soporte` con el argumento de que el soporte necesita ver el historial de pedidos para atender al cliente. El equipo decidió **no aplicarlo** porque la especificación define `rol_soporte` con alcance exclusivo a datos de contacto y estado de cuenta del usuario (`mail`, `celular`, `eliminado`). Dar acceso a pedidos amplía la responsabilidad del rol más allá de lo definido y expone datos de transacciones a un perfil que no los necesita para cumplir su función. Si en el futuro se requiere esa capacidad, se creará un rol específico.

**4. Falta `REVOKE CONNECT FROM PUBLIC` — aplicado ✓**

La IA señaló que revocar permisos del schema public no es suficiente si cualquier usuario puede conectarse a la base de datos. Se agregó `REVOKE CONNECT ON DATABASE foodstore_trabajo FROM PUBLIC` con `GRANT CONNECT` explícito solo para `app_web` y `admin_datos`.

---

## Parte B — Activación y prueba de la auditoría

### B.1 — Configuración de parámetros

**Fecha:** 2026-10-23  
**Archivo modificado:** `C:\Program Files\PostgreSQL\17\data\postgresql.conf`

Se activaron tres parámetros de auditoría:

| Parámetro | Valor nuevo |
|---|---|
| `log_connections` | `on` |
| `log_disconnections` | `on` |
| `log_statement` | `mod` |

Los cambios requirieron reinicio del servicio (`Restart-Service postgresql-x64-17`) porque
`pg_reload_conf()` no aplicó `log_connections` ni `log_disconnections` en caliente.

**Informe completo:** `docs/informe_auditoria_nativa.md`

---

### B.2 — Operaciones de prueba y log capturado

**Fecha:** 2026-10-23

Se ejecutaron cuatro operaciones contra `foodstore_trabajo`:

| Operación | Resultado |
|---|---|
| `SELECT * FROM producto LIMIT 5` | Exitoso (no aparece en log con `mod`) |
| `INSERT INTO pedido ...` | Exitoso — registrado en log |
| `UPDATE producto SET stock = stock - 1 ...` | Exitoso — registrado en log |
| Login con `app_web` y contraseña incorrecta | FATAL — registrado en log |

Fragmento de log y análisis completo en `docs/informe_auditoria_nativa.md`.

---

### B.3 — Análisis del fragmento

El log registra: quién (usuario autenticado), qué (sentencia SQL completa), cuándo
(timestamp con zona horaria) y desde dónde (IP y puerto). No registra detalle fila por
fila, lecturas con `log_statement = mod`, ni el usuario de aplicación detrás de una
conexión compartida. La extensión `pgaudit` cubriría esas limitaciones.

---

### B.4 — El log como activo sensible

El log es un activo sensible porque expone el historial completo de operaciones,
usuarios e IPs. Debe ser accesible solo para el usuario del servicio PostgreSQL y
administradores con necesidad comprobada, con permisos `640` en Unix o ACL
equivalentes en Windows. Ningún rol de base de datos debería tener acceso directo
al sistema de archivos donde residen los logs.

---

## Parte C — (pendiente)

---

*Documento generado progresivamente durante el desarrollo del TP.*
