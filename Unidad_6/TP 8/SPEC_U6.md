# SPEC_U6 — Plan de Mantenimiento Food Store (Unidad 6)

## 1. Propósito

Automatizar respaldo, monitoreo, mantenimiento y recuperación de desastres sobre la base `foodstore`, sin afectar la base principal y sin escribir contraseñas en los scripts.

## 2. Reglas de seguridad

- Nunca trabajar sobre la base original sin backup previo.
- No incluir contraseñas en scripts ni en el repositorio.
- No ejecutar `DROP`, `TRUNCATE` ni `DELETE` sobre datos existentes sin autorización.
- Las pruebas destructivas solo sobre entornos descartables (`foodstore_restore_test`).
- La base `foodstore` no se elimina ni se reemplaza durante el simulacro.

## 3. Tareas automatizadas

| Tarea | Frecuencia | Qué se automatiza | Condición de finalización correcta |
|---|---|---|---|
| Respaldo de `foodstore` | Diaria | `pg_dump` custom (`-Fc`) con fecha y hora en el nombre; registro de resultado en `logs/` | Archivo `.dump` generado y log de éxito |
| Chequeo de salud | Diaria | Ejecución de `health_check.sql` | Salida de `health_check.sql` sin errores |
| Revisión de mantenimiento | Semanal | `maintenance.sql`: revisión de autovacuum/ANALYZE y una acción de mantenimiento segura y justificada | Estado de tuplas muertas, autovacuum y estadísticas revisado |
| Restauración de prueba | Semanal | Restaurar el último respaldo en `foodstore_restore_test` y validar | `foodstore_restore_test` validada (filas y restricciones lógicas OK) |

## 4. Comandos de referencia

- Respaldo: `pg_dump -h localhost -p 5432 -U postgres -d foodstore -Fc -f backups/foodstore_FECHA_HORA.dump`
- Crear base de prueba: `createdb -h localhost -p 5432 -U postgres foodstore_restore_test`
- Restaurar: `pg_restore -h localhost -p 5432 -U postgres -d foodstore_restore_test --no-owner --no-privileges backups/ULTIMO_RESPALDO.dump`

## 5. Evidencia de entrega

Cada tarea debe dejar evidencia: archivo de respaldo, log, salida SQL o base de prueba validada. El script de respaldo debe ejecutarse manualmente antes de considerarlo apto para programación.
