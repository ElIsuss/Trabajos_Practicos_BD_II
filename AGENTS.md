# Food Store - Agent Instructions

## Repository Scope

- `schema.sql` is the PostgreSQL schema entrypoint. It creates `forma_pago_enum`, the five Food Store tables, and their indexes; it has no seed data or migration runner.
- Keep database identifiers and constraint naming in Spanish, following the existing `snake_case` names and prefixes: `fk_`, `chk_`, `unq_`, and `idx_`.
- Product and category deletion is intentionally restricted with foreign keys; product/category deactivation uses the `activo` flag. Do not replace these rules with cascade deletes without an explicit requirement.

## Safe Database Changes

- Never execute SQL against real or third-party data. Use a development copy; the assignment suggests `createdb -T plantilla_base copia_trabajo`.
- Before any DDL (`ALTER`, `DROP`, or migration), back up the working copy with `pg_dump`.
- Run every write first inside `BEGIN; ... ROLLBACK;`, inspect the result, and only then repeat it with `COMMIT` after approval.
- Read the complete diff before applying it: `git diff`. Every proposed SQL line must be explainable for the oral defense.
- For new integrity rules, write an unambiguous spec with the exact table and columns first, then test valid and invalid `INSERT` cases on the working copy.

## Assignment Deliverables

- Keep the safety procedure in root `protocolo_seguridad.md`, adapted to the local PostgreSQL commands and backup location.
- Document each IA-assisted exercise in its DUIA, including the exact prompt, generated changes, accepted/modified portions, and verification evidence.
- Record concurrency work in root `informe_concurrencia.md`: commands and actual output from both sessions, IA explanation, and the result of verifying it in PostgreSQL. Reproduce at least three scenarios.
