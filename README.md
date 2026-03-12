# Amgi

Goal-oriented Anki deck builder.

The repository now includes the first working v1 slice:

- load deck YAML
- lint schema and note data
- build a minimal `.apkg`

The implementation is intentionally small. It focuses on a stable schema,
repeatable local development, and TDD-friendly iteration speed.

## Current Result

- `nix develop -c` provides the Ruby development environment.
- `bin/lint`, `bin/format`, `bin/test`, `bin/check` are ready.
- `bin/amgi lint <deck_dir>` validates a deck.
- `bin/amgi build <deck_dir> [--out DIR]` writes a minimal `.apkg`.
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

Lint and build a deck:

```bash
nix develop -c bin/amgi lint spec/fixtures/decks/toeic
nix develop -c bin/amgi build spec/fixtures/decks/toeic
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
exe/        Ruby CLI entry point
lib/        Ruby entry points and application code
spec/       RSpec tests
flake.nix   Nix development shell
Gemfile     Ruby dependencies for local tooling
```

## v1 Schema

`build.yaml`

```yaml
schema: amgi_v1
name: JLPT_Vocabulary
required_fields:
  - target
  - meaning
optional_fields:
  - reading
  - context
  - translation
  - memo
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

`notes` YAML

```yaml
notes:
  - Target: comply
    Meaning: 준수하다, 따르다
    Example: All employees must comply with the rules.
    BlankExample: All employees must {} with the rules.
    tags:
      - Part5
```

Rules:

- `schema` must be `amgi_v1`
- `required_fields` are mandatory in every note
- `optional_fields` may be omitted
- note keys outside declared fields and `tags` are rejected
- template placeholders must reference declared fields or `FrontSide`

## Current Limits

- media files are not supported yet
- output `.apkg` is a minimal package, not a feature-complete Anki exporter
- multi-deck discovery and multiple note types are not implemented yet
