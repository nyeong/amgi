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
  id: "{{target}}"
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

- `id`: a template used to derive the stable note identity and to lint uniqueness
- `required_fields`: fields every note must have
- `optional_fields`: fields that may appear on notes

### `cards`

Defines the card templates that will be derived from each note.

- `name`: card template name
- `front`: front-side template
- `back`: back-side template
- `default`: exactly one card must be marked as the default

Card generation rules:

- the `default: true` card is always generated
- non-default cards must be enabled per dataset file through the root-level `_cards` list
- an enabled non-default card is generated only when every field referenced on its `front` is present
- use `_cards` plus optional fields on `front` to create expansion cards only in the source files that need them

## Dataset Files

Dataset files are YAML files with a top-level `notes:` list.
They may also define a root-level `_cards` string array to opt into extra non-default cards for that file.

```yaml
_cards:
  - "Cloze Context"

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

You can use different card sets per source file. For example:

```yaml
# a.yaml
notes:
  - target: "痛み"
    reading: "いたみ"
    meaning: "pain"
```

```yaml
# b.yaml
_cards:
  - "Recall Target"

notes:
  - target: "症状"
    reading: "しょうじょう"
    meaning: "symptom"
```

With the example above, `a.yaml` generates only the default card, while `b.yaml`
generates the default card plus `Recall Target`.

## Note Rules

Fields that start with `_` are reserved metadata fields.
All other fields must be declared in `amgi.yaml`.

Identity rules:

- Amgi renders `note_schema.id` for each note and uses that value as the stable note identity inside a deck
- lint fails when two notes render the same note id
- `id: "{{target}}"` keeps identity stable when other fields change
- `id: "{{target}}-{{memo}}"` makes `memo` part of the identity, so changing `memo` creates a new note identity

Current reserved fields:

- `_tags`: note-specific tags
- dataset root `_cards`: card names enabled for every note in that source file
