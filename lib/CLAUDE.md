# lib/

## Purpose
Non-app Ruby code. Holds only rake tasks.

## Files
- `tasks/` - rake tasks. See `lib/tasks/CLAUDE.md`.
- Grammar code is not here. It lives in `app/models/` (`quick_add.rb`, `recurrence.rb`).

## Rules for agents
- Put new domain logic in `app/`, not `lib/`.
- Follow `.rubocop.yml` (omakase).

## Verification
- `bin/rubocop`
- `bin/rspec`
