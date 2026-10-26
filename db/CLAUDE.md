# db/

## Purpose
Schema, migrations, and seeds for the SQLite database.

## Files
- `schema.rb` - generated schema dump (Rails 8.1, version 2026_10_22_193143). Tables: tasks, projects, labels, task_labels, completed_occurrences, users, sessions.
- `seeds.rb` - Rails default stub. Holds no seed data.
- `migrate/` - see `db/migrate/CLAUDE.md`.
- SQLite files live in `storage/` (see `config/database.yml`), not here.

## Rules for agents
- Never edit `schema.rb` by hand. Run `bin/rails db:migrate` to regenerate it.
- Never open or edit `*.sqlite3` files.
- Commit `schema.rb` together with its migration.
- Seeds must stay idempotent (stub comment says so).

## Verification
- `bin/rails db:migrate` then check `git diff db/schema.rb`.
- `bin/rspec`
- `bin/rubocop`
