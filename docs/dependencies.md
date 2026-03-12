# Dependencies and Installation

## End Users

Amgi currently targets Nix-based usage.

You do not need a separate Ruby installation if you run it through:

```bash
nix run github:nyeong/amgi -- help
```

## Runtime Packaging

The published CLI is packaged as a Nix app.

- the app entrypoint is `amgi`
- `nix run` builds the Ruby runtime and gems automatically
- the packaged app includes the project code plus the locked gem set

## Dependency Source of Truth

Ruby dependencies are locked through:

1. `Gemfile`
2. `Gemfile.lock`
3. `gemset.nix`

`gemset.nix` is generated from `Gemfile.lock` through `bundix`.

## Related Docs

- [CLI Commands](cli-commands.md)
- [Development Workflow](development.md)
