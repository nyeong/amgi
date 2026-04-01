# Amgi Agent Notes

- `README.md` is for external readers. Keep it focused on what the project is, how it works, and how to use it.
- `TODO.md` is for implementation tracking, verification checklists, current status, and next work.
- `AGENTS.md` is for coding-session instructions only.
- Ruby commands must run through `nix develop -c`.
- Default validation command: `nix develop -c bin/check`.
- Auto-fix command: `nix develop -c bin/format`.
- Work in small TDD loops: failing test -> minimal code -> `bin/check` -> refactor.
- Keep code split by responsibility and layer; avoid one-file blobs.
- Prefer clean architecture, but do not over-engineer.
- The blank-card DSL is documented in `docs/blank-field-dsl.md`. If you change
  its syntax or rendering rules, update that doc, `docs/amgi-v1-schema.md`, and
  `README.md` in the same unit of work.
- Use actual emoji gitmoji in commit messages.
- Commit immediately when one meaningful unit of work is complete.
