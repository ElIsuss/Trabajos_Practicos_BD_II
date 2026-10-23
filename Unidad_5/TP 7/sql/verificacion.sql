-- ==========================================================
-- PARTE A — Verificación de roles y permisos
-- Ejecutar conectado como postgres sobre foodstore_trabajo.
-- Cada bloque tiene un encabezado que indica qué se verifica.
-- ==========================================================

-- ----------------------------------------------------------
-- V-1: Atributos de todos los roles creados para Food Store
-- Equivalente a \du filtrado por los roles del proyecto.
-- Qué se espera: NOLOGIN para los cuatro roles de grupo;
-- LOGIN para app_web y admin_datos. Ninguno con SUPERUSER,
-- CREATEDB, CREATEROLE, REPLICATION ni BYPASSRLS.
-- ----------------------------------------------------------
SELECT
    rolname                  AS rol,
    rolcanlogin              AS puede_login,
    rolsuper                 AS superuser,
    rolcreatedb              AS createdb,
    rolcreaterole            AS createrole,
    rolreplication           AS replication,
    rolbypassrls             AS bypassrls
FROM pg_roles
WHERE rolname IN (
    'rol_app_lectura',
    'rol_app_escritura',
    'rol_soporte',
    'rol_reportes',
    'app_web',
    'admin_datos'
)
ORDER BY rolname;


-- ----------------------------------------------------------
-- V-2: Membresías (qué grupos tiene cada rol de login)
-- Qué se espera:
--   app_web    → rol_app_lectura, rol_app_escritura
--   admin_datos → rol_app_lectura, rol_app_escritura,
--                 rol_soporte, rol_reportes
-- ----------------------------------------------------------
SELECT
    r.rolname  AS miembro,
    g.rolname  AS grupo
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.member
JOIN pg_roles g ON g.oid = m.roleid
WHERE r.rolname IN ('app_web', 'admin_datos')
ORDER BY r.rolname, g.rolname;


-- ----------------------------------------------------------
-- V-3: Privilegios sobre tablas (nivel de tabla)
-- Qué se espera: exactamente los privilegios listados en
-- requirements.md, sin ningún privilegio extra ni faltante.
-- ----------------------------------------------------------
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN (
    'rol_app_lectura',
    'rol_app_escritura',
    'rol_soporte',
    'rol_reportes',
    'app_web',
    'admin_datos'
)
  AND table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;


-- ----------------------------------------------------------
-- V-4: Privilegios a nivel de columna (tabla usuario)
-- Qué se espera:
--   rol_soporte tiene SELECT sobre las columnas no sensibles
--   (id, nombre, apellido, mail, celular, rol, eliminado,
--    created_at, id_cliente) y UPDATE sobre (mail, celular,
--    eliminado).
--   NO debe aparecer ninguna fila con column_name = 'contrasena'.
-- ----------------------------------------------------------
SELECT
    grantee,
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE grantee IN (
    'rol_app_lectura',
    'rol_app_escritura',
    'rol_soporte',
    'rol_reportes',
    'app_web',
    'admin_datos'
)
  AND table_schema = 'public'
ORDER BY grantee, table_name, column_name, privilege_type;


-- ----------------------------------------------------------
-- V-5: Verificación explícita — contrasena nunca aparece
-- Debe devolver 0 filas. Si devuelve alguna, hay una brecha.
-- ----------------------------------------------------------
SELECT
    grantee,
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE column_name = 'contrasena'
  AND table_schema = 'public';


-- ----------------------------------------------------------
-- V-6: Privilegios sobre secuencias
-- Qué se espera: rol_app_escritura tiene USAGE sobre
-- pedido_id_pedido_seq y detalle_pedido_id_detalle_pedido_seq.
-- ----------------------------------------------------------
SELECT
    grantee,
    object_name,
    privilege_type
FROM information_schema.usage_privileges
WHERE object_schema = 'public'
  AND object_type = 'SEQUENCE'
  AND grantee IN (
      'rol_app_lectura',
      'rol_app_escritura',
      'rol_soporte',
      'rol_reportes',
      'app_web',
      'admin_datos'
  )
ORDER BY grantee, object_name;


-- ----------------------------------------------------------
-- V-7: Intento de escalamiento de privilegios (debe fallar)
-- Ejecutar conectado como app_web (rol de bajo privilegio).
-- Se espera: ERROR: must be member of role "admin_datos"
-- Registrar el mensaje de error obtenido en BITACORA.md.
-- ----------------------------------------------------------
-- \c foodstore_trabajo app_web
-- GRANT admin_datos TO app_web;   -- debe producir ERROR


-- ----------------------------------------------------------
-- V-8: Política para objetos futuros (ALTER DEFAULT PRIVILEGES)
-- Verifica que la configuración de defaults esté registrada.
-- ----------------------------------------------------------
SELECT
    pg_roles.rolname   AS propietario,
    pg_default_acl.defaclobjtype AS tipo_objeto,
    pg_default_acl.defaclacl     AS acl_resultante
FROM pg_default_acl
JOIN pg_roles ON pg_roles.oid = pg_default_acl.defaclrole
WHERE pg_roles.rolname = 'postgres';
