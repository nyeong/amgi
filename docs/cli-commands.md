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
nix run github:nyeong/amgi -- lint JLPT/n2_frequent_vocabulary_001
```

## Build

Build an `.apkg` from a deck directory.

```bash
nix run github:nyeong/amgi -- build <deck_dir>
```

Example:

```bash
nix run github:nyeong/amgi -- build JLPT/n2_frequent_vocabulary_001
```

By default, the output is written to the deck directory's `dist/` folder.

## Build With Custom Output Directory

```bash
nix run github:nyeong/amgi -- build <deck_dir> --out <output_dir>
```

Example:

```bash
nix run github:nyeong/amgi -- build JLPT/n2_frequent_vocabulary_001 --out /tmp/amgi-output
```
