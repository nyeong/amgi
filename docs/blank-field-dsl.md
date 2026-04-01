# Blank Field DSL

Amgi includes a small DSL for word-learning "fill in the blank" cards.
It lets you author a sentence once in a base field such as `example`, then
derive a blanked variant such as `exampleBlank` for an expansion card.

This is not Anki's built-in cloze note type. Amgi still exports a regular note
type and derives a masked field value before building the deck.

## Field Pairing

To use the DSL:

1. Declare the base field in `note_schema`.
2. Declare a sibling derived field whose name ends with `Blank`.
3. Write the DSL only in the base field inside `notes:`.
4. Reference the base field for the revealed text and the `...Blank` field for
   the masked text.

Example:

```yaml
note_schema:
  required_fields:
    - target
    - meaning
  optional_fields:
    - example
    - exampleBlank

cards:
  - name: Recall Meaning
    default: true
    front: "{{target}}"
    back: |
      {{FrontSide}}
      <hr id=answer>
      {{meaning}}
      {{example}}

  - name: Blank Example
    front: "{{exampleBlank}}"
    back: |
      {{FrontSide}}
      <hr id=answer>
      {{example}}
      {{target}}
      {{meaning}}

notes:
  - target: comply
    meaning: 준수하다, 따르다
    example: All employees must [[comply]] with the rules.
```

In the example above:

- `{{example}}` becomes `All employees must comply with the rules.`
- `{{exampleBlank}}` becomes `All employees must [...] with the rules.`

## Syntax

Grammar:

```text
blank-field := (text | marker)*
marker      := "[[" answer "]]" | "[[" answer "|" hint "]]"
answer      := one or more characters except the marker delimiters and "|"
hint        := one or more characters except the marker delimiters and "|"
```

Supported marker forms:

- `[[answer]]`
- `[[answer|hint]]`

Examples:

- `All employees must [[comply]] with the rules.`
- `He [[went|go]] home early.`
- `The [[heart]] pumps [[blood]] through the body.`

## Rendering Rules

- The base field renders the fully revealed text.
- The derived `...Blank` field renders `[...]` for `[[answer]]`.
- The derived `...Blank` field renders `[hint]` for `[[answer|hint]]`.
- Multiple markers are allowed in one field.
- If the base field contains no markers, the derived `...Blank` field is empty.
  Cards that depend on that field will not be generated.

## Validation Rules

Amgi rejects:

- unclosed markers like `[[answer`
- unexpected closing markers like `]]`
- empty markers like `[[]]`
- empty hints like `[[answer|]]`
- markers with more than one `|`, such as `[[a|b|c]]`
- direct note values for derived fields like `exampleBlank`

Keep the base field as the single source of truth.
