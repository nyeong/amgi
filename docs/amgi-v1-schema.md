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
    - translation
    - memo
  optional_fields:
    - clozeContext

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

- `required_fields`: fields every note must have. `target` must be included and is populated from each note key.
- `optional_fields`: fields that may appear on notes

### `cards`

Defines the card templates that will be derived from each note.

- `name`: card template name
- `front`: front-side template
- `back`: back-side template
- `default`: exactly one card must be marked as the default

Card generation rules:

- the `default: true` card is always generated
- non-default cards are generated only when every field referenced on their `front` is present
- use optional fields on `front` to create expansion cards that appear only for richer notes

## Dataset Files

Dataset files are YAML files with a top-level `notes:` mapping.
Each note key is the stable `target` and is injected into the note fields automatically.

```yaml
notes:
  "環境":
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

Identity rules:

- Amgi uses the note key, which is the `target`, as the stable note identity inside a deck
- changing `meaning`, `memo`, `context`, or tags does not create a new note
- renaming the note key creates a new note identity

Current reserved fields:

- `_tags`: note-specific tags
