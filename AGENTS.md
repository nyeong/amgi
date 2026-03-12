# Amgi Working Notes

- Ruby commands must run through `nix develop -c`.
- Default validation command: `nix develop -c bin/check`.
- Auto-fix command: `nix develop -c bin/format`.
- Work in small TDD loops: failing test -> minimal code -> `bin/check` -> refactor.
- Keep code split by responsibility and layer; avoid one-file blobs.
- Prefer clean architecture, but do not over-engineer.
- Use gitmoji commit messages.
- Commit immediately when one meaningful unit of work is complete.
