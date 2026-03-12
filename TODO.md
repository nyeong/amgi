# TODO

Updated: 2026-03-12

## Verification Checklist

- [x] `nix develop -c bin/lint` completed successfully on 2026-03-12
- [x] `nix develop -c bin/test` completed successfully on 2026-03-12
- [x] `nix develop -c bin/check` completed successfully on 2026-03-12
- [x] CLI lint path verified with `nix develop -c bin/amgi lint spec/fixtures/decks/toeic`
- [x] CLI build path verified through automated spec coverage
- [x] minimal `.apkg` output verified through integration test

## Current Status

- [x] Nix-based Ruby development environment
- [x] RuboCop formatter/lint harness
- [x] RSpec test harness
- [x] `amgi_v1` schema loading
- [x] deck lint pipeline
- [x] minimal `.apkg` build pipeline
- [x] shell wrapper `bin/amgi`

## Known Gaps

- [ ] media asset packaging
- [ ] richer Anki metadata compatibility
- [ ] multiple note types
- [ ] repository-wide deck discovery
- [ ] clearer end-user error messages with more precise YAML locations

## Next Candidates

- [ ] improve `.apkg` compatibility beyond the current minimal export
- [ ] add more invalid fixture decks for schema edge cases
- [ ] add deterministic output assertions for deck/model metadata
