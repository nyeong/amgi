# Amgi

Amgi is a Ruby-based Anki deck builder for SSoT-style study datasets.

Its core idea is simple:

- `notes:` hold the facts you want to memorize exactly once
- `cards:` define possible Anki card shapes derived from that dataset
- Amgi validates the structure and builds a reproducible `.apkg`

This keeps the source of truth in the dataset, while letting one note generate
multiple review angles such as recognition, reverse recall, and cloze-style
prompts when they are actually needed.

## What It Does Today

Amgi currently supports:

- a single-deck YAML workflow
- `amgi_v1` validation through `amgi.yaml`
- one `note_schema` per deck
- one default card plus automatically derived expansion cards
- minimal `.apkg` export with `collection.anki2` and `media`

Amgi does not yet support:

- media assets
- multiple note schemas in one deck
- repository-wide deck discovery
- richer Anki metadata compatibility

## Quick Start

Run the full local check:

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

By default, the built package is written to the deck's `dist/` directory.

## Deck Format

Each deck directory contains:

- `amgi.yaml`
- one or more dataset YAML files with `notes:`

Example `amgi.yaml`:

```yaml
schema: amgi_v1
name: JLPT_N2_Frequent_Vocabulary_001
global_tags:
  - JLPT
  - N2

note_schema:
  required_fields:
    - target
    - reading
    - meaning
    - context
    - clozeContext
    - translation
    - memo
  optional_fields: []

cards:
  - name: Recall Meaning
    default: true
    front: |
      <div>{{target}}</div>
    back: |
      {{FrontSide}}
      <hr id=answer>
      <div>{{meaning}}</div>

  - name: Recall Target
    front: |
      <div>{{meaning}}</div>
    back: |
      {{FrontSide}}
      <hr id=answer>
      <div>{{target}}</div>

  - name: Cloze Context
    front: |
      <div>{{clozeContext}}</div>
    back: |
      {{FrontSide}}
      <hr id=answer>
      <div>{{context}}</div>
      <div>{{target}}</div>
```

Example dataset file:

```yaml
notes:
  - target: "環境"
    reading: "かんきょう"
    meaning: "환경, 여건"
    context: "環境を守る"
    clozeContext: "_____を守る"
    translation: "환경을 지키다"
    memo: "환경 보호, 환경 개선처럼 같이 붙는 표현도 함께 외운다."
    _tags:
      - Noun
```

`cards` is the deck-level menu of possible card types. Each note always gets
the one `default: true` card. Additional cards are derived automatically when
the note has the front-side fields needed to render that card.

## Validation Rules

Amgi currently enforces these rules:

- `schema` must be `amgi_v1`
- `amgi.yaml` must exist in the deck root
- `note_schema.required_fields` must contain at least one field
- `cards` must contain at least one card definition
- exactly one card must have `default: true`
- field names must use lowerCamelCase and start with a lowercase letter
- every required field must be present in every note
- note keys must be declared in `note_schema.required_fields` or `note_schema.optional_fields`, except underscore-prefixed reserved fields such as `_tags`
- reserved note fields must start with `_`
- `_tags` must be a string array when present
- card placeholders must reference declared fields or `FrontSide`

## SSoT Authoring Model

Amgi is designed around three layers:

- capture layer: jot down unfamiliar items encountered in real problems or reading
- knowledge layer: normalize them into a clean `notes:` dataset
- card layer: derive only the review angles that match the actual failure mode

The goal is not to generate as many cards as possible. The goal is to stop
repeating the same mistake.

This is why Amgi treats the dataset as the source of truth and cards as
derivations:

- one word, expression, or concept should be maintained once
- cards should be added because of a failure pattern, not because more is better
- not every note should generate every card type

Typical expansion patterns:

- reading failure -> add a reading-focused card
- context failure -> add an example or cloze card
- confusable items -> add a comparison card

This also means deck templates should differ by exam.

- JLPT decks often need reading, kanji, meaning, and short context
- TOEIC decks often need collocation, expression usage, and test-style context

## Commands

Development commands:

```bash
nix develop -c bin/lint
nix develop -c bin/format
nix develop -c bin/test
nix develop -c bin/check
```

Application commands:

```bash
nix develop -c bin/amgi lint <deck_dir>
nix develop -c bin/amgi build <deck_dir>
nix develop -c bin/amgi build <deck_dir> --out <output_dir>
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
