# Amgi

Amgi is a Ruby-based Anki deck builder.

Its current v1 scope is intentionally small:

- load deck data from YAML
- lint schema and note structure
- build a minimal `.apkg`

The project is designed around reproducible local development with Nix and
test-first iteration in Ruby.

## What It Does Today

Amgi currently supports:

- `amgi_v1` deck schema
- explicit single-deck linting
- explicit single-deck build
- minimal `.apkg` export with `collection.anki2` and `media`

Amgi does not yet support:

- media assets
- multiple note types in one deck
- repository-wide deck discovery
- full Anki feature parity

## Quick Start

Enter the reproducible development environment through Nix:

```bash
nix develop -c bin/check
```

Lint a sample deck:

```bash
nix develop -c bin/amgi lint spec/fixtures/decks/toeic
```

Build a sample deck:

```bash
nix develop -c bin/amgi build spec/fixtures/decks/toeic
```

The built package is written to the deck's `dist/` directory by default.

## Schema

Each deck directory contains:

- `build.yaml`
- one or more note YAML files

Example `build.yaml`:

```yaml
schema: amgi_v1
name: TOEIC_Vocabulary
required_fields:
  - Target
  - Meaning
optional_fields:
  - Example
  - BlankExample
global_tags:
  - TOEIC
templates:
  - name: Card 1
    front: |
      <div class="target">{{Target}}</div>
    back: |
      {{FrontSide}}
      <hr id=answer>
      <div class="meaning">{{Meaning}}</div>
      <div class="example">{{Example}}</div>
```

Example note file:

```yaml
notes:
  - Target: comply
    Meaning: 준수하다, 따르다
    Example: All employees must comply with the rules.
    BlankExample: All employees must {} with the rules.
    tags:
      - Part5
```

Validation rules:

- `schema` must be `amgi_v1`
- every required field must be present in every note
- note keys must be declared in `required_fields` or `optional_fields`, except `tags`
- `tags` must be a string array when present
- template placeholders must reference declared fields or `FrontSide`

## Commands

Development quality commands:

```bash
nix develop -c bin/lint
nix develop -c bin/format
nix develop -c bin/test
nix develop -c bin/check
```

Optional local GUI smoke test with Anki Desktop:

```bash
nix develop -c bin/smoke-import-anki path/to/deck.apkg
```

This command is intentionally separate from `bin/check`. It assumes:

- Anki Desktop is installed locally
- Anki is not already running
- the machine can launch the GUI app

By default it looks for `/Applications/Anki.app`, launches Anki with a temporary
base/profile, imports the provided `.apkg`, verifies the imported deck and
note/card counts, and then quits Anki.

Application commands:

```bash
nix develop -c bin/amgi lint <deck_dir>
nix develop -c bin/amgi build <deck_dir>
nix develop -c bin/amgi build <deck_dir> --out <output_dir>
```

## Project Layout

```text
bin/        executable entrypoints for development and CLI usage
lib/        application, domain, infrastructure, and interface code
spec/       RSpec tests and fixture decks
flake.nix   Nix development shell definition
Gemfile     Ruby dependencies
TODO.md     implementation tracking and verification checklist
AGENTS.md   working instructions for future coding sessions
```
