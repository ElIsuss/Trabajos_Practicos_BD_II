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

## Parte C — Laboratorio: simulacro de incidente de acceso indebido

### C.1 — Reconstrucción de prerrequisitos

**Fecha:** 2026-10-23

`fn_autenticar` no existía en la base `foodstore`. Se reconstruyó como paso previo al simulacro, incluyéndola al inicio del script `sql/simulacro_incidente.sql`. La función compara en texto plano contra `usuario.contrasena` (suficiente para entorno de desarrollo). También se seteó la contraseña de `app_web` (que estaba como `PASSWORD NULL` en `roles.sql`) dentro del mismo script.

Adicionalmente, se detectó que los parámetros de auditoría de la Parte B estaban configurados en PostgreSQL 17, pero el simulacro se ejecutó sobre PostgreSQL 18. Se aplicaron los parámetros con `ALTER SYSTEM` y se reinició el servicio `postgresql-x64-18` antes de ejecutar el simulacro.

### C.2 — Ejecución del simulacro

**Fecha:** 2026-10-23  
**Script:** `sql/simulacro_incidente.sql`

El simulacro reprodujo la secuencia completa:

| Fase | Acción | Resultado | ¿Registrada en log? |
|---|---|---|---|
| 1 | 3 intentos fallidos de `fn_autenticar` | `f` en los tres | No (SELECTs con `log_statement = mod`) |
| 2 | 1 login exitoso de `fn_autenticar` | `t` | No (SELECT con `log_statement = mod`) |
| 3 | Conexión como `app_web` | Conexión exitosa | Sí (`log_connections = on`) |
| 4 | `SELECT * FROM usuario` | `ERROR: permiso denegado a la tabla usuario` | No (SELECT, pero el error de permission denied sí se registra) |
| 5 | `GRANT admin_datos TO app_web` | `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos»` | Sí (modificación + error) |
| 6 | Reconexión como `postgres` | Reconectado (como `app_web` por no especificar usuario) | Sí (`log_connections = on`) |

El escalamiento (Fase 5) falló como se esperaba: `app_web` no tiene `CREATEROLE` ni `ADMIN OPTION` sobre `admin_datos`.

### C.3 — Anonimización del log

**Fecha:** 2026-10-23

El fragmento de log se anonimizó antes de enviarlo a la IA:
- Nombres de roles reales (`app_web`, `postgres`, `admin_datos`) → sintéticos (`rol_tecnico_01`, `admin_sys`, `rol_admin`)
- Nombre de la base de datos (`foodstore`) → `db_produccion`
- Nombre de la función (`fn_autenticar`) → `fn_verificar_cred`
- Nombre de la tabla (`usuario`) → `usuarios`
- IPs y puertos → valores sintéticos (`10.0.0.1`, puertos `50100`-`50102`)
- Nombre de la aplicación (`pgAdmin 4 - DB:foodstore`) → `app_interna`
- Contraseña seteada → enmascarada como `****`

**Archivo anonimizado:** `docs/log_simulacro_anonimizado.txt`

### C.4 — Reconstrucción con IA

**Fecha:** 2026-10-23  
**Herramienta:** OpenCode (Kiro)

Se entregó el log anonimizado a la IA sin contexto adicional y se le pidió que reconstruyera qué ocurrió y propusiera una hipótesis de contención.

#### Prompt enviado

El fragmento de log anonimizado (`docs/log_simulacro_anonimizado.txt`) sin contexto adicional, seguido de: "Reconstruye qué ocurrió a partir de este fragmento de log y propón una hipótesis de contención."

#### Respuesta de la IA (resumen)

La IA reconstruyó la siguiente secuencia:
1. El servidor fue reiniciado.
2. Un usuario administrativo (`admin_sys`) se conectó y creó una función de verificación de credenciales con `SECURITY DEFINER`, y modificó la contraseña de `rol_tecnico_01`.
3. Inmediatamente después, alguien se conectó como `rol_tecnico_01` desde el mismo host.
4. Intentó leer la tabla `usuarios` y recibió permiso denegado.
5. Intentó escalar privilegios con `GRANT rol_admin TO rol_tecnico_01`, denegado por falta de `ADMIN OPTION`.
6. Se reconectó y la sesión anterior se cerró.

Hipótesis de contención de la IA: un atacante con acceso a credenciales de `rol_tecnico_01` intentó exfiltrar datos y escalar privilegios. Recomendó rotar la contraseña, bloquear la IP, investigar el origen y auditar la función.

#### Validación o corrección humana

| Aspecto | IA | Realidad | Evaluación |
|---|---|---|---|
| Conexión de `rol_tecnico_01` post cambio de contraseña | Detectó la conexión y la asoció al cambio de contraseña | Conexión de `app_web` en Fase 3 | ✓ Acierto |
| Intento de lectura de `usuarios` | Detectó el `SELECT` y su rechazo | `SELECT * FROM usuario LIMIT 1000` en Fase 4 | ✓ Acierto |
| Intento de escalamiento | Detectó el `GRANT` y lo interpretó como escalamiento | `GRANT admin_datos TO app_web` en Fase 5 | ✓ Acierto |
| Reconexión final | Detectó la reconexión y cierre de sesión | Fase 6 | ✓ Acierto |
| Fuerza bruta previa (3 intentos) | No la mencionó | 3 llamadas a `fn_autenticar` con contraseñas incorrectas en Fase 1 | ✗ Omisión: no visible en log con `mod` |
| Login exitoso a nivel de aplicación | No lo mencionó | `fn_autenticar` retornó `t` en Fase 2 | ✗ Omisión: no visible en log con `mod` |
| Origen del acceso a credenciales | Asumió que el atacante "tenía acceso" | Las credenciales fueron obtenidas por fuerza bruta contra `fn_autenticar` | ✗ Omisión: la causa real no es inferible del log |
| Creación de la función | Sugirió auditar si fue parte del ataque | La función fue creada por el equipo como prerrequisito del simulacro | ⚠ Afirmación no sustentada: el log no permite distinguir acción legítima de maliciosa |

**Caso más significativo de omisión de la IA:** la IA no pudo detectar la fuerza bruta ni el login exitoso a nivel de aplicación porque las llamadas a `fn_autenticar` son `SELECT`s y `log_statement = 'mod'` no las registra. Esto confirma la limitación identificada en la Parte B: la auditoría nativa con `mod` no captura lecturas, y un atacante podría intentar fuerza bruta sin dejar rastro en el log. La extensión `pgaudit` con `log_statement = 'all'` cubriría esta brecha.

**Caso más significativo de afirmación no sustentada:** la IA sugirió auditar si la función `fn_verificar_cred` fue modificada como parte del ataque, asumiendo la hipótesis maliciosa sin evidencia para descartar la alternativa legítima. En realidad, la función fue creada por el equipo como paso previo al simulacro. El registro de la sentencia `CREATE OR REPLACE FUNCTION` en el log no permite distinguir el motivo.

### C.5 — Decisión de contención

**Decisión del equipo (no automatizada):**

En un caso real, ante un incidente con esta evidencia, el equipo decidiría:

1. **Rotar inmediatamente la contraseña de `app_web`** y revocar todos los tokens de sesión activos, dado que la cuenta fue usada para conectarse después de un cambio de credenciales sospechoso.
2. **Bloquear la IP de origen** y revisar si hubo conexiones desde otras IPs en el mismo periodo.
3. **Activar `log_statement = 'all'`** temporalmente para capturar las lecturas que el `mod` no registra, permitiendo rastrear futuros intentos de fuerza bruta contra `fn_autenticar`.
4. **Revisar el código de `fn_autenticar`** para implementar rate limiting o bloqueo tras N intentos fallidos, ya que el log demostró que la fuerza bruta a nivel de aplicación es invisible para la auditoría nativa con `mod`.

Los puntos 1 y 2 coinciden con la sugerencia de la IA. Los puntos 3 y 4 surgen del contraste: la IA no detectó la fuerza bruta porque el log no la registra, y esa omisión es la que motiva estas dos medidas adicionales.

**Informe completo:** `docs/informe_incidente.md`

Esta decisión fue tomada por el equipo a partir de la evidencia del log y el contraste con la reconstrucción de la IA. No se ejecutó automáticamente a partir de la sugerencia de la IA.

---

## Parte D — Protección de datos personales: anonimización y verificación de equivalencia

### D.1 — Construcción de usuario_anon

**Fecha:** 2026-10-23  
**Script:** `sql/usuario_anon.sql`

Se creó la tabla `usuario_anon` a partir de `usuario` con datos sintéticos deterministas. Las columnas con datos personales (`nombre`, `apellido`, `mail`, `celular`, `contrasena`) se reemplazaron por valores sintéticos derivados del `id`. Las columnas de agregación (`rol`, `eliminado`, `created_at`, `id_cliente`) se preservaron idénticas.

Ambas tablas tienen 20.000 filas.

### D.2 — Consulta de agregación y equivalencia

**Fecha:** 2026-10-23

Se ejecutó la consulta "cantidad de usuarios por rol y por mes de alta" sobre ambas tablas:

| Tabla | Resultado |
|---|---|
| `usuario_anon` | `USUARIO / 2026-09-01 / 20000` (1 fila) |
| `usuario` | `USUARIO / 2026-09-01 / 20000` (1 fila) |

Los resultados agregados son idénticos: mismos agrupamientos, mismos conteos.

### D.3 — Información que no debería salir a una IA sin anonimizar

Nombres y apellidos reales de clientes, correos electrónicos, números de teléfono y contraseñas de la tabla `usuario` no deben enviarse a un asistente de IA sin pasar antes por anonimización. Cualquier combinación de atributos que permita reidentificar a un individuo (por ejemplo, correo electrónico más fecha de alta) debe ser tratada como dato personal.

**Informe completo:** `docs/verificacion_equivalencia.md`

---

## Parte E — Cierre: consolidación de la bitácora de IA

### E.1 — Consolidación de registros A-D

La bitácora registra las siguientes interacciones con IA a lo largo del trabajo:

| Parte | Sección | Herramienta | Prompt enviado | Respuesta (resumen) | Validación humana |
|---|---|---|---|---|---|
| A | A.4 | OpenCode | "Auditá roles.sql y proponé mejoras" | 4 sugerencias: SELECT en cliente para escritura y reportes, SELECT en pedido para soporte, REVOKE CONNECT | 2 aplicadas (cliente para escritura/reportes, REVOKE CONNECT), 1 rechazada (soporte con pedido/detalle_pedido — más amplio de lo necesario), 1 aplicada (REVOKE CONNECT) |
| B | — | — | Sin interacción con IA (configuración manual de parámetros) | — | — |
| C | C.4 | Kiro (IA) | Log anonimizado sin contexto: "Reconstruye qué ocurrió y propón una hipótesis de contención" | Reconstruyó conexión, intento de lectura, escalamiento y reconexión. Omitió fuerza bruta y login exitoso. Sugirió auditar si la función fue parte del ataque. | Contrastada contra realidad: 4 aciertos, 3 omisiones, 1 afirmación no sustentada. Decisión de contención tomada por el equipo, no por la IA. |
| D | — | OpenCode | Plan de implementación para usuario_anon.sql | Script SQL completo con CREATE TABLE, índices y consultas de agregación | Ejecutado sin modificaciones. Resultados verificados: equivalencia confirmada. |

### E.2 — Caso más significativo de error o imprecisión de la IA

El caso más significativo se encuentra en la **Parte C (C.4)**: la IA no pudo detectar la fuerza bruta previa al incidente porque las llamadas a `fn_autenticar` son `SELECT`s y `log_statement = 'mod'` no las registra. La IA recibió el log anonimizado, reconstruyó correctamente la conexión, el intento de lectura y el escalamiento, pero omitió por completo las Fases 1 y 2 del simulacro (3 intentos fallidos y 1 login exitoso a nivel de aplicación). Esto no es un error de la IA sino una limitación del mecanismo de auditoría: el log simplemente no contiene esa información. Sin embargo, la IA tampoco señaló esta limitación — no advirtió que podían haber ocurrido operaciones no registradas. Se detectó al contrastar la reconstrucción con la secuencia real ejecutada: la discrepancia entre lo que la IA reportó y lo que realmente pasó reveló que la auditoría nativa con `mod` deja un punto ciego que un atacante puede explotar sin dejar rastro.

Como segundo caso destacable, en la **Parte A (A.4)** la IA propuso otorgar `SELECT` sobre `pedido` y `detalle_pedido` a `rol_soporte`, ampliando el alcance del rol más allá de lo definido en la especificación. Se detectó comparando la sugerencia contra el principio de mínimo privilegio: `rol_soporte` solo necesita datos de contacto del usuario, no historial de transacciones.

### E.3 — Revisión del historial de Git

**Estado actual del repositorio:**

| Parte | Estado del commit |
|---|---|
| A | Commiteado — `9ddec96` "Trabajo Practico N°7 - Resolucion de la parte A" |
| B | Commiteado — `ca895db` "Trabajo Practico N°7 - Resolucion de la parte B" |
| C | Commiteado — `d3dabf4` "Trabajo Practico N7 - Resolucion de la parte C" |
| D | Commiteado — `a923a6a` "Trabajo Practico N7 - Resolucion de la parte D" |
| E | Commiteado — `42ddffb` "Trabajo Practico N7 - Resolucion de la parte E y consolidacion de bitacora" |

El historial refleja el avance por partes con un commit por cada una y mensajes legibles. Adicionalmente, los cambios de la Parte 2 del TP de Unidad 4 (desnormalización controlada) se commitearon en un commit separado: `958f4d0` "TP Unidad 4 - Parte 2: desnormalizacion controlada con vista materializada".

---

*Documento generado progresivamente durante el desarrollo del TP.*
