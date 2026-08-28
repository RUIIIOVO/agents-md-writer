# acme-api — agent instructions

REST API on Node 20 + Fastify + Postgres 16, TypeScript strict mode.

**Never run migrations against a database you did not start yourself.** Use `pnpm db:reset`.

## Repository layout

```
src/routes/       HTTP layer — validation and serialisation only, no business logic
src/services/     business logic, the only layer allowed to call repositories
src/repos/        SQL access, one file per table
migrations/       numbered SQL migrations, append-only, never edited in place
tests/            mirrors src/, one spec file per module
```

## Environment & commands

Prerequisites: Node 20+, pnpm 9+, Docker (for Postgres).

- **Install**: `pnpm install`
- **Start Postgres**: `docker compose up -d db`
- **Dev server**: `pnpm dev` (port 3000)
- **Reset database**: `pnpm db:reset` (drops, recreates, re-runs `migrations/`)
- **Typecheck**: `pnpm typecheck`

## Testing

- Tests live in `tests/`, mirroring `src/`.
- Run all: `pnpm test`
- Run one: `pnpm test tests/services/user.spec.ts`
- Integration tests need Postgres running. They are skipped without it, so a green run does not
  by itself prove integration coverage.

## Code style

- `pnpm lint` runs ESLint with `--max-warnings=0`. Config: `.eslintrc.cjs`.
- Formatting is Prettier via lint-staged. Do not hand-format.
- No `any`. Use `unknown` and narrow.
- Files and directories: `kebab-case`. Exported types: `PascalCase`.

## Boundaries

- `src/routes/` must not import from `src/repos/`. Routes call services; services call repos.
- `migrations/` is append-only. To change a migration, add a new one.
- `vendor/` and `dist/` are generated. Never hand-edit, never commit.

## Commits & PRs

- Format: `type(scope): summary` — matches existing `git log`.
- One commit, one concern. Formatting changes stay separate from logic changes.

## Review checklist

- [ ] `pnpm typecheck` passes
- [ ] `pnpm lint` passes with zero warnings
- [ ] `pnpm test` passes with Postgres running
- [ ] The changed endpoint was actually called — compiling is not verification
- [ ] New SQL is a new file in `migrations/`, not an edit to an existing one

**A human verifies these. AI must not claim they are done**: staging smoke test, dashboard visuals.

## References

- **Layer rules and rationale**: `docs/architecture.md`
- **Release process**: `docs/deployment.md` — **required reading** when the user says "cut a release"
