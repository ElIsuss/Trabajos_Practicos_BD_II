-- =====================================================================
-- PARTE D — Protección de datos personales: anonimización
-- Archivo: usuario_anon.sql
-- Motor: PostgreSQL 18 — base foodstore
-- Ejecutar: psql -d foodstore -f usuario_anon.sql
-- =====================================================================
-- Crea una tabla usuario_anon con datos sintéticos deterministas
-- a partir de la tabla usuario. Las columnas de agregación (rol,
-- eliminado, created_at, id_cliente) se preservan idénticas para
-- que los resultados agregados sean equivalentes. Las columnas con
-- datos personales (nombre, apellido, mail, celular, contrasena)
-- se reemplazan por valores sintéticos deterministas derivados del id.
-- =====================================================================

-- Tabla anonimizada: misma estructura que usuario pero con datos sintéticos
CREATE TABLE usuario_anon AS
SELECT
    id,
    -- Datos sintéticos deterministas derivados del id
    'Usuario_' || id::TEXT                          AS nombre,
    'Apellido_' || id::TEXT                         AS apellido,
    'anon_' || id::TEXT || '@anonimo.com'           AS mail,
    '+54900' || LPAD(id::TEXT, 7, '0')              AS celular,
    'anonimizado'                                    AS contrasena,
    -- Columnas de agregación: se preservan idénticas
    rol,
    eliminado,
    created_at,
    id_cliente
FROM usuario;

-- Índices para que las consultas de agregación sean eficientes
CREATE INDEX idx_usuario_anon_rol ON usuario_anon (rol);
CREATE INDEX idx_usuario_anon_created_at ON usuario_anon (created_at);
CREATE INDEX idx_usuario_anon_rol_fecha ON usuario_anon (rol, created_at);

-- Verificar que ambas tablas tienen el mismo número de filas
SELECT 'usuario' AS tabla, COUNT(*) AS filas FROM usuario
UNION ALL
SELECT 'usuario_anon', COUNT(*) FROM usuario_anon;

-- =====================================================================
-- Consulta de agregación sobre usuario_anon
-- Cantidad de usuarios por rol y por mes de alta
-- =====================================================================

SELECT
    rol,
    date_trunc('month', created_at)::date AS mes_alta,
    COUNT(*) AS cantidad
FROM usuario_anon
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;

-- =====================================================================
-- Consulta equivalente sobre la tabla real usuario
-- =====================================================================

SELECT
    rol,
    date_trunc('month', created_at)::date AS mes_alta,
    COUNT(*) AS cantidad
FROM usuario
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
