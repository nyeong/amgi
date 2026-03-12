# Amgi

Goal-oriented Anki deck builder.

The current milestone is not the deck builder itself yet. This repository is
bootstrapped with a reproducible Ruby development environment, a quality
harness, and lightweight working rules so the actual deck-building features can
be developed with TDD from the next step onward.

## Current Result

- `nix develop -c` provides the Ruby development environment.
- `bin/lint`, `bin/format`, `bin/test`, `bin/check` are ready.
- Ruby quality checks use `RuboCop + RSpec`.
- The repository is prepared for small, test-first iterations.

## Quick Start

Run the full local quality gate:

```bash
nix develop -c bin/check
```

Run each tool separately:

```bash
nix develop -c bin/lint
nix develop -c bin/format
nix develop -c bin/test
```

## Development Workflow

This repository follows a small-loop workflow:

1. Define a small goal.
2. Add a failing test first.
3. Implement the minimum change.
4. Run `nix develop -c bin/check`.
5. Refactor.
6. Commit immediately when that unit of work is complete.

## Working Rules

- Use `nix develop -c` for every Ruby command.
- Use `nix develop -c bin/check` as the default validation command.
- Use `nix develop -c bin/format` for safe auto-fixes.
- Keep files and responsibilities separated by layer.
- Prefer clean structure, but avoid unnecessary over-engineering.
- Use gitmoji in commit messages.
- Make one commit per meaningful unit of completed work.

## Repository Layout

```text
bin/        executable development commands
lib/        Ruby entry points and application code
spec/       RSpec tests
flake.nix   Nix development shell
Gemfile     Ruby dependencies for local tooling
```

## Next Milestone

The next implementation milestone is the actual deck builder:

1. Load deck YAML.
2. Lint schema and note data.
3. Build `.apkg`.

The intended v1 schema direction is:

```yaml
schema: amgi_v1
name: JLPT_Vocabulary
required_fields:
  - Target
  - Meaning
optional_fields:
  - Reading
  - Context
  - Translation
  - Memo
global_tags:
  - JLPT
templates:
  - name: Card 1
    front: |
      <div class="jp-target">{{Target}}</div>
    back: |
      {{FrontSide}}
      <hr id=answer>
      <div class="meaning">{{Meaning}}</div>
```

That schema is documented here as the current design target, not as a completed
feature.
