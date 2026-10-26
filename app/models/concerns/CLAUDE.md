# CLAUDE.md (app/models/concerns)

## Purpose
Shared model mixins. The directory is empty except `.keep`.

## Files
- `.keep`: placeholder. No code.

## Rules for agents
- Add a concern here only when two or more models share the same behavior.
- Prefer a plain model method for one-off logic.

## Verification
- `bin/rspec spec/models`
- `bin/rubocop`
