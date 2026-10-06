-- =====================================================================
-- TP UNIDAD 4 — PARTE 1
-- FNBC sobre control_lote_almacen
-- Entregable: tp_fnbc_control_lote.sql
-- Motor: PostgreSQL 17
-- Base: foodstore_trabajo
--
-- Ejecutar de arriba hacia abajo, en DBeaver, sobre foodstore_trabajo.
-- Idempotente en su parte estructural; los INSERT usan ON CONFLICT
-- DO NOTHING para que un reintento no duplique la instancia de ejemplo.
-- =====================================================================


-- ---------------------------------------------------------------------
-- SECCION 1 — Tablas maestras de la extension mayorista
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS deposito (
    id BIGINT PRIMARY KEY
);

INSERT INTO lote     (id) VALUES (501), (502), (503)
ON CONFLICT (id) DO NOTHING;

INSERT INTO deposito (id) VALUES (30), (31)
ON CONFLICT (id) DO NOTHING;


-- ---------------------------------------------------------------------
-- SECCION 2 — Precondicion: los responsables 801 y 802 deben existir
-- ---------------------------------------------------------------------

SELECT id, nombre, apellido
FROM usuario
WHERE id IN (801, 802)
ORDER BY id;


-- ---------------------------------------------------------------------
-- SECCION 3 — Esquema original (tal como lo entrega la consigna)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
VALUES (501, 30, 801),
       (502, 30, 801),
       (503, 31, 802)
ON CONFLICT (lote_id, deposito_id) DO NOTHING;


-- ---------------------------------------------------------------------
-- SECCION 4 — Descomposicion de la DF violatoria R -> D
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS responsable_deposito (
    responsable_control_id  BIGINT NOT NULL
        REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL
        REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

CREATE TABLE IF NOT EXISTS control_lote (
    lote_id                 BIGINT NOT NULL
        REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL
        REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);


-- ---------------------------------------------------------------------
-- SECCION 5 — Vista de compatibilidad
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote          cl
JOIN responsable_deposito  rd
    ON cl.responsable_control_id = rd.responsable_control_id;


-- ---------------------------------------------------------------------
-- SECCION 6 — Migracion de la instancia de ejemplo (inciso f)
-- ---------------------------------------------------------------------

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
VALUES (801, 30),
       (802, 31)
ON CONFLICT (responsable_control_id) DO NOTHING;

INSERT INTO control_lote (lote_id, responsable_control_id)
VALUES (501, 801),
       (502, 801),
       (503, 802)
ON CONFLICT (lote_id, responsable_control_id) DO NOTHING;


-- ---------------------------------------------------------------------
-- SECCION 7 — Verificacion de equivalencia (inciso f)
-- ---------------------------------------------------------------------

SELECT * FROM v_control_lote_almacen ORDER BY lote_id;

SELECT * FROM (
    (SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen)
    UNION ALL
    (SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen)
) AS diferencia;

SELECT
    (SELECT COUNT(*) FROM control_lote_almacen)     AS filas_original,
    (SELECT COUNT(*) FROM v_control_lote_almacen)   AS filas_vista;

SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos
FROM responsable_deposito
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;




-- =====================================================================
-- DOCUMENTACION (no forma parte del script; no ejecutar)
-- =====================================================================

-- SECCION 1 — Tablas maestras de la extension mayorista
--
-- La consigna indica que lote y deposito "se asumen existentes". En esta
-- base no lo estan, asi que se crean para que los REFERENCES del inciso
-- (e) sean ejecutables. lote y deposito son claves primarias puras: solo
-- identifican. deposito es analoga a la tabla sucursal del caso
-- AsignacionEntrega.
-- Se las puebla aqui mismo, y no mas adelante en la migracion, porque
-- control_lote_almacen declara REFERENCES a las dos: sin filas en lote y
-- deposito, el INSERT de la seccion 3 viola la FK.

-- SECCION 2 — Precondicion: los responsables 801 y 802 deben existir
--
-- responsable_control_id referencia usuario(id). Los usuarios de Food Store
-- se generan 1:1 desde cliente (~20.000 filas), por lo que 801 y 802
-- deberian existir. Esta consulta lo confirma ANTES de intentar el INSERT:
-- si devuelve 0 filas, la seccion 6 fallara por violacion de FK y no por un
-- error de logica del ejercicio.
-- Esperado: 2 filas (801 y 802).

-- SECCION 3 — Esquema original
--
-- PK declarada: (lote_id, deposito_id).
-- Responde a la DF1: para un lote y un deposito dados, el responsable de
-- control queda univocamente determinado.
--
-- Instancia de ejemplo provista por la consigna:
--     (501, 30, 801)
--     (502, 30, 801)
--     (503, 31, 802)
--
-- Notar que 801 aparece en dos lotes: un responsable atiende mas de un
-- lote, pero siempre desde el mismo deposito.

-- SECCION 4 — Descomposicion de la DF violatoria R -> D
--
-- Inciso (e). Se aplica el algoritmo de descomposicion sin perdida sobre
-- la DF ResponsableControlID -> DepositoID, separando el atributo
-- determinado (deposito_id) del resto del esquema:
--
--     R1 = { R, D }   -> responsable_deposito
--     R2 = { L, R }   -> control_lote
--
-- R1 = responsable_deposito
--   Es la tabla donde vive el dato maestro de personal. La PK es
--   responsable_control_id, y eso es lo que materializa la DF R -> D: cada
--   fila afirma que ESE responsable pertenece a ESE deposito, y la unicidad
--   de la PK impide que un responsable tenga dos depositos.
--   Esto elimina las tres anomalias del inciso (d):
--     - insercion:    803 puede registrarse en el deposito 32 sin ningun lote
--     - borrado:      eliminar un control de lote no borra la pertenencia
--     - actualizacion: cambiar el deposito de 801 toca UNA sola fila
--
-- R2 = control_lote
--   Es el hecho operativo, sin el atributo determinado. En R2 desaparece
--   deposito_id, por lo que la PK declarada (lote_id, deposito_id) deja de
--   ser valida. La PK correcta es la otra clave candidata hallada en el
--   inciso (b): { LoteID, ResponsableControlID }.
--   Un responsable no controla mas de un deposito, asi que la FK a
--   responsable_deposito es consistente con la regla de negocio: el
--   deposito del lote se deduce por la reunion.

-- SECCION 5 — Vista de compatibilidad
--
-- Reconstruye la relacion original por reunion natural sobre el atributo
-- comun responsable_control_id. Las otras tablas (lote, deposito, usuario)
-- no hacen falta en el JOIN porque la vista solo proyecta los tres
-- atributos de la relacion original.

-- SECCION 6 — Migracion de la instancia de ejemplo (inciso f)
--
-- Paso 1: R1 — un registro por responsable
-- Paso 2: R2 — un registro por (lote, responsable)
-- Las tablas maestras lote y deposito ya quedaron pobladas en la seccion 1.

-- SECCION 7 — Verificacion de equivalencia (inciso f)
--
-- 7.1 SELECT * FROM v_control_lote_almacen
--     Debe devolver exactamente la instancia original:
--
--         lote_id | deposito_id | responsable_control_id
--         --------+-------------+-----------------------
--            501 |          30 |                 801
--            502 |          30 |                 801
--            503 |          31 |                 802
--
-- 7.2 Diferencia simetrica (la prueba formal de sin perdida)
--     EXCEPT en ambos sentidos devuelve SOLO las tuplas que difieren.
--     Si el resultado es 0 filas, la descomposicion no perdio ninguna
--     tupla (no hay faltantes) y no genero ninguna espuria (no hay
--     sobrantes). Esto es la comprobacion del criterio de superclave
--     aplicado al atributo comun responsable_control_id.
--     Esperado: 0 filas.
--
-- 7.3 Conteo comparado, como lectura de control
--
-- 7.4 Chequeo de la DF R -> D garantizada por el esquema
--     Ningun responsable puede aparecer con dos depositos distintos.
--     Esperado: 0 filas.