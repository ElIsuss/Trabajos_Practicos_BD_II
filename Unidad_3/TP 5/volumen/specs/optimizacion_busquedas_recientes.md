# Especificación de Optimización (Kiro) — Consulta: Histórico de Pedidos por Cliente

## 1. Contexto y Consulta Objetivo
Consulta frecuente ejecutada desde el panel del usuario o el módulo de atención al cliente para visualizar las compras recientes de un cliente específico en un rango de fechas.

```sql
SELECT p.id_pedido, p.fecha_hora, p.forma_pago, p.estado
FROM pedido p
WHERE p.id_cliente = 1500
  AND p.fecha_hora >= NOW() - INTERVAL '180 days'
ORDER BY p.fecha_hora DESC;
2. Frecuencia y Uso
Frecuencia: Alta (operación transaccional y de consulta frecuente por usuario registrado).

Carga de Trabajo: Lecturas frecuentes filtradas por un cliente en particular y ordenadas por fecha reciente.

3. Análisis de Columnas
Filtros (WHERE):

pedido.id_cliente (Igualdad / Filtro por un cliente individual).

pedido.fecha_hora (Filtro por rango/intervalo temporal).

Ordenamiento (ORDER BY): pedido.fecha_hora DESC.

4. Criterio de Aceptación para la Propuesta de IA
Proponer un índice en la tabla pedido que optimice el filtro combinado por cliente y fecha.

El plan de ejecución en PostgreSQL debe evitar el filtrado posterior en memoria de la fecha y el paso explícito de Sort.

El tiempo de ejecución medido con EXPLAIN ANALYZE debe reducirse significativamente respecto al plan inicial.