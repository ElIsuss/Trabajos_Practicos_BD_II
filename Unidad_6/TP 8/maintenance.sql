-- maintenance.sql
-- Revisión de autovacuum y acción de mantenimiento justificada
-- TP Unidad 6 - Parte 3 | Bases de Datos II

-- ============================================================
-- Paso 1: Revisión del estado de autovacuum/ANALYZE
-- Se observa el estado actual antes de decidir cualquier acción
-- ============================================================
SELECT
    relname                                         AS tabla,
    n_live_tup                                      AS tuplas_vivas,
    n_dead_tup                                      AS tuplas_muertas,
    last_autovacuum                                 AS ultimo_autovacuum,
    last_autoanalyze                                AS ultimo_autoanalyze,
    CASE
        WHEN n_dead_tup > 1000 THEN 'Revisar - muchas tuplas muertas'
        WHEN last_autoanalyze IS NULL THEN 'Sin estadísticas aún'
        ELSE 'OK'
    END                                             AS estado
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- ============================================================
-- Paso 2: Acción de mantenimiento justificada
--
-- Observación previa (ejecutado el 2026-10-24):
--   - La tabla "usuario" tiene 20.000 tuplas vivas y fue procesada
--     por autovacuum el 2026-10-23. Es la tabla de mayor volumen.
--   - Las demás tablas no presentan tuplas muertas significativas.
--   - No hay fragmentación relevante en ninguna tabla.
--
-- Decisión: ANALYZE manual sobre "usuario"
--   El autovacuum ya limpió las tuplas muertas, pero un ANALYZE
--   manual garantiza que el planificador de consultas cuente con
--   estadísticas actualizadas sobre la distribución de datos,
--   especialmente útil después de cargas masivas de datos.
--
-- Por qué NO se usa VACUUM FULL:
--   VACUUM FULL bloquea la tabla completamente durante su ejecución
--   y solo se justifica cuando hay fragmentación severa (muchas
--   tuplas muertas acumuladas). En este caso, la base está sana
--   y el autovacuum está funcionando correctamente.
-- ============================================================

ANALYZE usuario;

-- ============================================================
-- Paso 3: Verificación posterior al mantenimiento
-- Confirmar que las estadísticas se actualizaron
-- ============================================================
SELECT
    relname            AS tabla,
    last_autoanalyze   AS ultimo_autoanalyze,
    last_analyze       AS ultimo_analyze_manual
FROM pg_stat_user_tables
WHERE relname = 'usuario';
