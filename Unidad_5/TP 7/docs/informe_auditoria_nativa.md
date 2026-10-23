# Informe de Auditoría Nativa — Parte B
Base de datos: `foodstore_trabajo`  
Servidor: PostgreSQL 17 — Windows local  
Fecha: 2026-10-23

---

## B.1 — Configuración de parámetros de auditoría

Se modificó el archivo `C:\Program Files\PostgreSQL\17\data\postgresql.conf` para activar
el registro de operaciones. Los cambios realizados fueron:

| Parámetro | Valor anterior | Valor nuevo | Propósito |
|---|---|---|---|
| `log_connections` | `off` | `on` | Registra cada conexión entrante al servidor |
| `log_disconnections` | `off` | `on` | Registra cada cierre de sesión |
| `log_statement` | `none` | `mod` | Registra sentencias de modificación: INSERT, UPDATE, DELETE y DDL |
| `log_destination` | `stderr` | `stderr` | Sin cambio — salida a archivo via logging collector |
| `logging_collector` | `on` | `on` | Sin cambio — ya estaba activo, guarda logs en archivos |
| `log_directory` | `log` | `log` | Sin cambio — archivos en `data/log/` |

Para aplicar los cambios sin interrumpir el servicio se intentó `SELECT pg_reload_conf()`,
pero los parámetros `log_connections` y `log_disconnections` requirieron reinicio completo
del servicio. Se ejecutó:

```powershell
Restart-Service -Name "postgresql-x64-17"
```

Verificación posterior confirmó los tres parámetros activos:

```
log_connections    = on
log_disconnections = on
log_statement      = mod
```

---

## B.2 — Secuencia de operaciones de prueba y fragmento de log

Se ejecutaron cuatro operaciones desde DBeaver contra `foodstore_trabajo`:

### Operaciones ejecutadas

1. **Lectura:** `SELECT * FROM producto LIMIT 5;`
2. **Inserción:** `INSERT INTO pedido (id_cliente, fecha_hora, estado, forma_pago) VALUES (1, NOW(), 'PENDIENTE', 'EFECTIVO');`
3. **Actualización:** `UPDATE producto SET stock = stock - 1 WHERE id_producto = 1;`
4. **Login fallido:** intento de conexión con usuario `app_web` y contraseña incorrecta desde DBeaver.

### Fragmento de log capturado

```
2026-10-23 17:40:46 -03 LOG:  conexión recibida: host=127.0.0.1 port=65214
2026-10-23 17:40:46 -03 LOG:  conexión autenticada: identidad=«postgres» método=scram-sha-256 (pg_hba.conf:115)
2026-10-23 17:40:46 -03 LOG:  conexión autorizada: usuario=postgres base_de_datos=foodstore_trabajo

2026-10-23 17:42:16 -03 LOG:  ejecutar <unnamed>: UPDATE producto SET stock = stock - 1 WHERE id_producto = 1

2026-10-23 17:44:33 -03 LOG:  ejecutar <unnamed>: INSERT INTO pedido (id_cliente, fecha_hora, estado, forma_pago)
    VALUES (1, NOW(), 'PENDIENTE', 'EFECTIVO')

2026-10-23 17:46:20 -03 LOG:  conexión recibida: host=127.0.0.1 port=64530
2026-10-23 17:46:20 -03 FATAL:  la autentificación password falló para el usuario «app_web»
2026-10-23 17:46:20 -03 DETALLE:  El usuario «app_web» no tiene una contraseña asignada.
    La conexión coincidió con pg_hba.conf línea 115: «host all all 127.0.0.1/32 scram-sha-256»
```

**Nota:** el SELECT no aparece en el log porque `log_statement = mod` registra solo
operaciones de modificación, no lecturas. Esto es intencional para evitar saturar el log
en bases de datos con alto volumen de consultas.

---

## B.3 — Análisis del fragmento

### Información útil para auditoría

El log nativo de PostgreSQL permite reconstruir los siguientes elementos:

| Dimensión | Información disponible | Ejemplo en el fragmento |
|---|---|---|
| **Quién** | Usuario autenticado | `identidad=«postgres»`, `usuario=«app_web»` |
| **Qué** | Sentencia SQL completa | `UPDATE producto SET stock = stock - 1 WHERE id_producto = 1` |
| **Cuándo** | Timestamp con zona horaria | `2026-10-23 17:44:33 -03` |
| **Desde dónde** | IP y puerto de origen | `host=127.0.0.1 port=64530` |
| **Resultado** | Éxito o error con detalle | `FATAL: la autentificación password falló` |

Esto es suficiente para detectar accesos no autorizados, operaciones fuera de horario,
intentos de login fallidos y cambios en datos sensibles.

### Limitaciones del mecanismo nativo

El log nativo **no registra**:

- **Detalle fila por fila:** se sabe que se ejecutó un UPDATE sobre `producto`, pero no
  qué valor tenía `stock` antes ni cuál quedó después. Para eso sería necesaria la
  extensión `pgaudit`, que puede registrar el estado anterior y posterior de cada fila
  afectada.
- **Consultas SELECT con `log_statement = mod`:** las lecturas no quedan registradas,
  lo que impide detectar exfiltración de datos mediante consultas masivas.
- **Contexto de aplicación:** el log muestra el usuario de base de datos, pero no el
  usuario de la aplicación web que originó la operación. Si diez usuarios de la app
  comparten la conexión `app_web`, el log no distingue entre ellos.
- **Integridad del propio log:** el log nativo no está firmado ni protegido contra
  modificaciones. Un atacante con acceso al sistema de archivos podría alterarlo.
  Herramientas como `pgaudit` combinadas con envío a un servidor de logs externo
  (syslog, SIEM) mitigan este riesgo.

---

## B.4 — El log como activo sensible

Sí, el archivo de log es en sí mismo un activo sensible. Contiene el historial completo
de operaciones sobre la base de datos, incluyendo sentencias SQL, usuarios, IPs de origen
y errores de autenticación — información que un atacante podría usar para mapear el
comportamiento del sistema o identificar vulnerabilidades.

El archivo debería ser legible únicamente por el usuario del sistema operativo que ejecuta
el proceso PostgreSQL (habitualmente `postgres` en Linux o el servicio en Windows) y por
administradores del sistema con necesidad comprobada. En términos de permisos, esto
equivale a `640` en sistemas Unix (`postgres` propietario, grupo `postgres` con lectura,
sin acceso para otros). En Windows, el acceso debe restringirse mediante ACL al usuario
del servicio y al grupo de administradores. Ningún rol de base de datos debería tener
acceso directo al sistema de archivos donde residen los logs.
