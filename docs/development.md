# Development Workflow

## Development Shell

Enter the Nix development shell:

```bash
nix develop
```

This shell provides:

- Ruby 3.3
- locked gems from `gemset.nix`
- the project scripts in `bin/`
- Git hooks installed through `git-hooks.nix`

## Main Development Commands

```bash
nix develop -c bin/check
nix develop -c bin/lint
nix develop -c bin/test
nix develop -c ruby bin/lint-yaml
nix develop -c bin/format
```

## Dependency Update Workflow

When Ruby dependencies change:

1. edit `Gemfile`
2. refresh `Gemfile.lock`
3. regenerate `gemset.nix`

Commands:

```bash
nix develop -c bundle-lock
nix develop -c bundle-update
nix develop -c bundix
```

## Flake Validation

Run the Nix-level validation suite:

```bash
nix flake check
```

## Optional Smoke Test

If Anki Desktop is installed locally:

```bash
nix develop -c bin/smoke-import-anki path/to/deck.apkg
```

## Related Docs

- [CLI Commands](/Users/nyeong/Repos/anki-deck/docs/cli-commands.md)
- [Dependencies and Installation](/Users/nyeong/Repos/anki-deck/docs/dependencies.md)
- [Project Status](/Users/nyeong/Repos/anki-deck/TODO.md)
