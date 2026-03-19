# CI Usage

## Recommended Path

For another repository that only contains deck data, consume Amgi as a pinned
Nix package instead of installing Ruby and gems manually.

Recommended job shape:

1. Install Nix on the runner, or use a self-hosted runner that already has Nix.
2. Build a pinned Amgi package once:

   ```bash
   nix build "github:nyeong/amgi?rev=<amgi_commit_sha>#amgi"
   ```

3. Reuse the built binary for one or more deck builds:

   ```bash
   ./result/bin/amgi build decks/jlpt -o dist/jlpt.apkg
   ./result/bin/amgi build decks/toeic -o dist/toeic.apkg
   ```

4. Upload the generated `.apkg` files as CI artifacts.

This is better than calling `nix run` repeatedly because the package is built
once per job and the resulting CLI can be reused.

## Cache Strategy

There are two realistic cache layers:

- upstream binary caches:
  `cache.nixos.org`, `nix-community.cachix.org`, and any cache used by your
  runner fleet
- persistent self-hosted runner store:
  if your Forgejo runner already has a warm `/nix/store`, that behaves like a
  practical cache even without a dedicated remote binary cache

For this repository, the most immediately useful pattern is a self-hosted
runner with a persistent Nix store. That is the same pattern used in the
`dotfiles` repository's Forgejo workflows.

## When To Add A Dedicated Binary Cache

Add a dedicated cache only if one of these becomes true:

- multiple repositories consume Amgi frequently
- GitHub-hosted runners rebuild or redownload Amgi too often
- you want both GitHub Actions and Forgejo Actions to share the same warmed
  artifacts

If you go that route, prefer documenting the cache URL and public key in one
place and keeping CI jobs on `nix build ...#amgi` rather than embedding Ruby
installation logic in every consumer repository.
