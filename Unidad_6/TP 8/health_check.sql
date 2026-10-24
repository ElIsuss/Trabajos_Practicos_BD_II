-- health_check.sql
-- Monitoreo del estado de la base foods_store_completo
-- TP Unidad 6 - Parte 3 | Bases de Datos II

-- ============================================================
-- Control 1: Tamaño de la base de datos
-- ============================================================
SELECT pg_size_pretty(pg_database_size('foods_store_completo')) AS tamano_base;

-- ============================================================
-- Control 2: Actividad de conexiones
-- Muestra backends activos, transacciones confirmadas y revertidas
-- ============================================================
SELECT
    numbackends        AS conexiones_activas,
    xact_commit        AS transacciones_confirmadas,
    xact_rollback      AS transacciones_revertidas,
    blks_hit           AS bloques_en_cache,
    blks_read          AS bloques_leidos_disco
FROM pg_stat_database
WHERE datname = 'foods_store_completo';

-- ============================================================
-- Control 3: Estado de las tablas (tuplas vivas, muertas y autovacuum)
-- Permite detectar tablas con fragmentación o que necesiten mantenimiento
-- ============================================================
SELECT
    relname            AS tabla,
    n_live_tup         AS tuplas_vivas,
    n_dead_tup         AS tuplas_muertas,
    last_autovacuum    AS ultimo_autovacuum,
    last_autoanalyze   AS ultimo_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- ============================================================
-- Control 4: Consultas activas en este momento
-- Detecta queries lentas o bloqueadas (excluye conexiones idle)
-- ============================================================
SELECT
    pid,
    state,
    now() - query_start AS duracion,
    left(query, 120)    AS consulta
FROM pg_stat_activity
WHERE datname = 'foods_store_completo'
  AND state <> 'idle'
ORDER BY duracion DESC NULLS LAST;
