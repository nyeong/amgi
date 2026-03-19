# CLI Commands

## Help

```bash
nix run github:nyeong/amgi -- help
```

Also works with:

```bash
nix run github:nyeong/amgi -- --help
```

## Lint

Validate a deck directory without building an `.apkg`.

```bash
nix run github:nyeong/amgi -- lint <deck_dir>
```

Example:

```bash
nix run github:nyeong/amgi -- lint examples/toeic
```

## Build

Build an `.apkg` from a deck directory.

```bash
nix run github:nyeong/amgi -- build <deck_dir>
```

Example:

```bash
nix run github:nyeong/amgi -- build examples/toeic
```

Output path precedence:

1. `-o <output_path>` or `--out <output_path>`
2. `output` in `amgi.yaml` relative to the deck directory
3. `<current-working-directory>/<name>.apkg`

## Build With Custom Output Path

```bash
nix run github:nyeong/amgi -- build <deck_dir> -o <output_path>
```

Example:

```bash
nix run github:nyeong/amgi -- build examples/toeic -o /tmp/amgi-output/toeic.apkg
```
