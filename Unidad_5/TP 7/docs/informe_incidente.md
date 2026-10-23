# Informe de incidente — Parte C: Simulacro de acceso indebido

**Base:** foodstore  
**Fecha del simulacro:** 2026-10-23  
**Script ejecutado:** `sql/simulacro_incidente.sql`

---

## 1. Secuencia ejecutada

El simulacro reprodujo la siguiente secuencia contra la base `foodstore`:

| Fase | Acción | Resultado esperado | Resultado real |
|---|---|---|---|
| 1 | 3 intentos fallidos de `fn_autenticar` con contraseñas incorrectas | `false` en cada llamada | `f` en los tres intentos |
| 2 | 1 llamado exitoso a `fn_autenticar` con contraseña correcta | `true` | `t` |
| 3 | Conexión como `app_web` (cuenta comprometida) | Conexión exitosa | "You are now connected to database foodstore as user app_web" |
| 4 | `SELECT * FROM usuario LIMIT 1000` | `permission denied for table usuario` | `ERROR: permiso denegado a la tabla usuario` |
| 5 | `GRANT admin_datos TO app_web` | `permission denied for role admin_datos` | `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos»` |
| 6 | Reconexión como `postgres` | Conexión exitosa | Reconectado (como `app_web` — ver nota) |

**Nota sobre la Fase 6:** el comando `\connect foodstore` reconectó como `app_web` en lugar de `postgres` porque no especificó el usuario. Es un detalle del script que no afecta al resultado del simulacro.

**Log anonimizado:** `docs/log_simulacro_anonimizado.txt`

---

## 2. Verificación del escalamiento

El intento de escalamiento (Fase 5) **falló** como se esperaba. `app_web` no tiene el atributo `CREATEROLE` ni `ADMIN OPTION` sobre `admin_datos`, por lo que PostgreSQL rechazó la sentencia `GRANT`. El error fue explícito:

```
ERROR: se ha denegado el permiso para otorgar el rol «admin_datos»
DETAIL: Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
```

Esto confirma que el esquema de permisos de la Parte A es correcto: un rol de bajo privilegio no puede autoescalar a un rol administrativo.

---

## 3. Reconstrucción de la IA

**Prompt enviado:** el fragmento de log anonimizado, sin contexto adicional.

**Respuesta de la IA (resumen):**

La IA reconstruyó la siguiente secuencia a partir del log:

1. El servidor fue reiniciado.
2. Un usuario administrativo (`admin_sys`) se conectó y creó una función de verificación de credenciales (`fn_verificar_cred`) con `SECURITY DEFINER`, y modificó la contraseña del rol `rol_tecnico_01`.
3. Inmediatamente después, alguien se conectó como `rol_tecnico_01` desde el mismo host.
4. El usuario conectado como `rol_tecnico_01` intentó leer la tabla `usuarios` y recibió permiso denegado.
5. El mismo usuario intentó escalar privilegios con `GRANT rol_admin TO rol_tecnico_01`, lo que también fue denegado por falta de `ADMIN OPTION`.
6. El usuario se reconectó y la sesión anterior se cerró.

**Hipótesis de contención de la IA:** un atacante con acceso a credenciales de `rol_tecnico_01` intentó exfiltrar datos y escalar privilegios. Ambos intentos fallaron. Recomendó revocar y rotar la contraseña, bloquear la IP de origen, investigar cómo se obtuvo la contraseña, y auditar si la función fue modificada legítimamente.

---

## 4. Contraste: IA vs realidad

### 4.1 Qué acertó la IA

- **Conexión de `rol_tecnico_01` después del cambio de contraseña:** la IA detectó correctamente que la conexión de `rol_tecnico_01` ocurrió inmediatamente después de que `admin_sys` modificara su contraseña.
- **Intento de lectura de la tabla `usuarios`:** la IA identificó el `SELECT * FROM usuarios LIMIT 1000` y su rechazo por permiso denegado.
- **Intento de escalamiento de privilegios:** la IA detectó el `GRANT rol_admin TO rol_tecnico_01` y correctamente interpretó que fue un intento de escalamiento que falló por falta de `ADMIN OPTION`.
- **Reconexión final:** la IA notó la reconexión y el cierre de la sesión anterior.

### 4.2 Qué omitió la IA

- **Fuerza bruta previa (Fase 1):** la IA no mencionó los 3 intentos fallidos contra `fn_autenticar`. No podía saberlo: las llamadas a la función son `SELECT`s y `log_statement = 'mod'` no registra lecturas. El log no contiene ninguna traza de estos intentos.
- **Login exitoso a nivel de aplicación (Fase 2):** la IA no detectó que hubo un llamado exitoso a `fn_autenticar` antes de la conexión a la base. Por la misma razón: es un `SELECT` que no se registra en el log.
- **Método de obtención de credenciales:** la IA asumió que el atacante "tenía acceso a credenciales" pero no pudo inferir que fueron obtenidas por fuerza bruta contra la función de autenticación, porque esa secuencia no deja rastro en el log.

Punto clave: las Fases 1 y 2 (llamadas a `fn_autenticar`) son `SELECT`s. Con `log_statement = 'mod'`, PostgreSQL no registra lecturas. La IA no tiene forma de saber que hubo fuerza bruta ni que el login fue exitoso a nivel de aplicación. Esta es la limitación identificada en la Parte B y ahora confirmada en la práctica.

### 4.3 Afirmaciones no sustentadas por el log

- La IA sugirió "auditar si la función `fn_verificar_cred` fue modificada legítimamente o como parte del ataque". En realidad, la función fue creada por el propio equipo como paso previo al simulacro (prerrequisito), no por un atacante. El log muestra la sentencia `CREATE OR REPLACE FUNCTION` pero no permite distinguir si fue una acción legítima o maliciosa; la IA asumió la hipótesis de ataque sin evidencia suficiente para descartar la alternativa.
- La IA no hizo afirmaciones sobre fechas o causas que el log no sustente más allá de este caso.

---

## 5. Decisión de contención

**Decisión del equipo (no automatizada):**

En un caso real, ante un incidente con esta evidencia, el equipo decidiría:

1. **Rotar inmediatamente la contraseña de `app_web`** y revocar todos los tokens de sesión activos, dado que la cuenta fue usada para conectarse después de un cambio de credenciales sospechoso.
2. **Bloquear la IP de origen** (`10.0.0.1` en el log anonimizado / `::1` en el log real) y revisar si hubo conexiones desde otras IPs en el mismo periodo.
3. **Activar `log_statement = 'all'`** temporalmente para capturar las lecturas que el `mod` no registra, permitiendo rastrear futuros intentos de fuerza bruta contra `fn_autenticar`.
4. **Revisar el código de `fn_autenticar`** para implementar rate limiting o bloqueo tras N intentos fallidos, ya que el log demostró que la fuerza bruta a nivel de aplicación es invisible para la auditoría nativa con `mod`.

**Esta decisión es del equipo, tomada a partir de evidencia, y no una acción ejecutada automáticamente a partir de lo que sugirió la IA.** La IA propuso medidas similares (rotar contraseña, bloquear IP, investigar origen), pero el punto 3 (activar `log_statement = 'all'`) y el punto 4 (rate limiting en `fn_autenticar`) surgen del contraste: la IA no detectó la fuerza bruta porque el log no la registra, y esa omisión es la que motiva estas dos medidas adicionales.
