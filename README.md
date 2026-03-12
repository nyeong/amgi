# Amgi

Amgi is a Ruby-based Anki deck builder for study datasets managed as a single
source of truth.

It is for people who want to:

- keep each word, expression, or concept in one place
- derive multiple Anki card styles from that dataset
- build `.apkg` files reproducibly from plain YAML

In short:

- the dataset is the source of truth
- cards are derived review views of that dataset
- Amgi validates the structure and builds an importable deck

## Why This Project Exists

Many Anki workflows turn the card itself into the thing you edit. That works at
first, but it gets painful when:

- the same fact appears in several cards
- one correction needs to be applied in multiple places
- card counts grow faster than understanding

Amgi takes the opposite approach.

You define the thing you want to memorize once in `notes:` and then describe
how that note can be reviewed through deck-level `cards:` templates.

This is especially useful when:

- building JLPT vocabulary decks from reading and practice mistakes
- building TOEIC expression decks from collocations and test context
- maintaining a long-lived study dataset without duplicated cards

## How It Works

Each deck directory contains:

- one `amgi.yaml` config file
- one or more dataset YAML files containing `notes:`

Amgi reads the deck, validates it, and builds an `.apkg`.

The design model is:

1. capture layer: collect items you got wrong or want to remember
2. knowledge layer: normalize them into clean `notes:`
3. card layer: derive review cards from that dataset

The important idea is that the dataset stays primary.

- one note represents one memorization target
- one default card is always created
- additional cards are derived from the same note

## Quick Start

Enter the development shell and run the full check:

```bash
nix develop -c bin/check
```

Lint a deck:

```bash
nix develop -c bin/amgi lint spec/fixtures/decks/toeic
```

Build a deck:

```bash
nix develop -c bin/amgi build spec/fixtures/decks/toeic
```

The built `.apkg` is written to the deck's `dist/` directory by default.

## Example Deck

`amgi.yaml` defines the deck name, note schema, and card templates:

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

A dataset file contains only the memorization data:

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

This means:

- `環境` is defined once
- the default card is always created
- extra cards can be derived from the same note

## Deck Format

### `amgi.yaml`

`amgi.yaml` is the only config file for a deck.

It defines:

- `schema`: currently `amgi_v1`
- `name`: Anki deck name
- `global_tags`: tags applied to all notes
- `note_schema.required_fields`
- `note_schema.optional_fields`
- `cards`: the set of possible card templates

### Dataset Files

Dataset files are normal YAML files with a top-level `notes:` key.

Each note must follow the schema declared in `amgi.yaml`.

Reserved note-level metadata fields must start with `_`.

Current reserved fields include:

- `_tags`: array of note-specific tags

## Card Derivation Model

Amgi is built around the idea that not every note should explode into every
possible card.

Current behavior:

- exactly one card must be marked `default: true`
- every note gets that default card
- additional cards are derived automatically when the note has the front-side
  fields needed to render that card

This keeps the note as the thing you maintain, while letting one note support
different recall angles such as:

- recognition
- reverse recall
- context recall
- cloze-style prompts

## Validation Rules

Amgi currently checks:

- `amgi.yaml` exists at the deck root
- `schema` is `amgi_v1`
- `note_schema.required_fields` is not empty
- `cards` is not empty
- exactly one card has `default: true`
- field names start with a lowercase letter and use lower camel case
- every note includes all required fields
- notes do not contain undeclared fields except underscore-prefixed reserved
  fields
- `_tags`, when present, is an array of strings
- card placeholders reference declared fields or `FrontSide`
- repository YAML files are valid YAML syntax through `bin/lint-yaml`

## Commands

### Main Commands

```bash
nix develop -c bin/amgi lint <deck_dir>
nix develop -c bin/amgi build <deck_dir>
nix develop -c bin/amgi build <deck_dir> --out <output_dir>
```

### Development Commands

```bash
nix develop -c ruby bin/lint-yaml
nix develop -c bin/lint
nix develop -c bin/test
nix develop -c bin/check
nix develop -c bin/format
```

### Optional Anki Smoke Test

If Anki Desktop is installed locally, you can run:

```bash
nix develop -c bin/smoke-import-anki path/to/deck.apkg
```

This launches Anki with a temporary profile, imports the deck, checks the deck
and note/card counts, and then quits.

## Current Scope

Amgi currently supports:

- one deck per directory
- one `note_schema` per deck
- YAML-based dataset authoring
- minimal `.apkg` export with `collection.anki2` and `media`

Amgi does not yet support:

- media asset packaging
- multiple note schemas in one deck
- repository-wide deck discovery
- full Anki metadata compatibility beyond the current minimal export

## Project Layout

```text
bin/        CLI and development scripts
lib/        application, domain, infrastructure, and interface code
spec/       automated tests and fixture decks
JLPT/       example real-world deck content
TODO.md     implementation tracking
AGENTS.md   coding-session instructions for contributors
```
