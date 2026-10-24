# Verificación de equivalencia — Parte D

**Base:** foodstore  
**Fecha:** 2026-10-23  
**Script:** `sql/usuario_anon.sql`

---

## 1. Construcción de usuario_anon

Se creó la tabla `usuario_anon` a partir de `usuario` con datos sintéticos deterministas:

| Columna original | Columna anonimizada | Método |
|---|---|---|
| `nombre` | `'Usuario_' \|\| id` | Sintético determinista |
| `apellido` | `'Apellido_' \|\| id` | Sintético determinista |
| `mail` | `'anon_' \|\| id \|\| '@anonimo.com'` | Sintético determinista |
| `celular` | `'+54900' \|\| LPAD(id, 7, '0')` | Sintético determinista |
| `contrasena` | `'anonimizado'` | Valor fijo sin información |
| `rol` | sin cambios | Preservada para agregación |
| `eliminado` | sin cambios | Preservada para agregación |
| `created_at` | sin cambios | Preservada para agregación |
| `id_cliente` | sin cambios | Preservada para agregación |

**Filas:**

```
   tabla     | filas
-------------+-------
 usuario     | 20000
 usuario_anon| 20000
```

Ambas tablas tienen 20.000 filas.

---

## 2. Consulta de agregación sobre usuario_anon

```sql
SELECT
    rol,
    date_trunc('month', created_at)::date AS mes_alta,
    COUNT(*) AS cantidad
FROM usuario_anon
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

**Resultado:**

```
   rol   |  mes_alta  | cantidad
---------+------------+----------
 USUARIO | 2026-09-01 |    20000
(1 row)
```

---

## 3. Consulta equivalente sobre usuario

```sql
SELECT
    rol,
    date_trunc('month', created_at)::date AS mes_alta,
    COUNT(*) AS cantidad
FROM usuario
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

**Resultado:**

```
   rol   |  mes_alta  | cantidad
---------+------------+----------
 USUARIO | 2026-09-01 |    20000
(1 row)
```

---

## 4. Verificación de equivalencia

| Criterio | ¿Coincide? |
|---|---|
| Número de filas (usuario vs usuario_anon) | Sí — 20.000 en ambas |
| Mismos agrupamientos (rol × mes de alta) | Sí — un único grupo: USUARIO / 2026-09-01 |
| Mismos conteos por grupo | Sí — 20.000 en ambos casos |

**Conclusión:** los resultados agregados son idénticos. La anonimización preserva exactamente la misma información de agregación (cantidad de usuarios por rol y por mes de alta) sin exponer ningún dato personal.

---

## 5. Información que no debería salir a una IA sin anonimizar

Nombres y apellidos reales de clientes, correos electrónicos y números de teléfono de la tabla `usuario` no deberían enviarse a un asistente de IA sin pasar antes por anonimización, ya que permiten identificar directamente a personas físicas. Las contraseñas, aunque sean hashes de prueba en este entorno, tampoco deben exponerse: un valor de prueba en desarrollo podría convertirse en un valor real en producción, y el hábito de no compartir credenciales debe ser consistente. Finalmente, cualquier combinación de atributos que permita reidentificar a un individuo (por ejemplo, correo electrónico más fecha de alta) debe ser tratada como dato personal y anonimizada antes de salir del entorno controlado.
