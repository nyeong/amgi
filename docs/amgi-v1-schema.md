# Amgi v1 Schema

## `amgi.yaml`

```yaml
schema: amgi_v1
name: JLPT_N2_Frequent_Vocabulary_001
output: build/jlpt.apkg
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

### `schema`

Must be `amgi_v1`.

### `name`

The Anki deck name.

### `output`

Optional output path for `amgi build` when `-o` is not provided.
Relative paths are resolved from the deck directory that contains `amgi.yaml`.

### `global_tags`

Tags applied to all notes in the deck.

### `note_schema`

Defines the allowed note fields.

- `required_fields`: fields every note must have
- `optional_fields`: fields that may appear on notes

### `cards`

Defines the card templates that will be derived from each note.

- `name`: card template name
- `front`: front-side template
- `back`: back-side template
- `default`: exactly one card must be marked as the default

## Dataset Files

Dataset files are YAML files with a top-level `notes:` key.

```yaml
notes:
  - target: "環境"
    reading: "かんきょう"
    meaning: "environment, conditions"
    context: "環境を守る"
    clozeContext: "_____を守る"
    translation: "protect the environment"
    memo: "Memorize common collocations as well."
    _tags:
      - Noun
```

## Note Rules

Fields that start with `_` are reserved metadata fields.
All other fields must be declared in `amgi.yaml`.

Current reserved fields:

- `_tags`: note-specific tags
