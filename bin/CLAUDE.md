# bin

## Purpose
Executable entry points for dev, test, lint, scans, and backup.

## Files
- rails, rake - standard Rails launchers.
- rspec - runs RSpec through Bundler.
- rubocop - runs RuboCop with the repo .rubocop.yml.
- brakeman - security scan; passes --ensure-latest.
- bundler-audit - dependency scan with config/bundler-audit.yml.
- importmap - importmap CLI.
- setup - bundle install, db:prepare, clear logs and tmp, then start bin/dev. Flags: --reset, --skip-server.
- dev - runs `bin/rails server`.
- create-backup.sh - online SQLite backup of storage/$RAILS_ENV.sqlite3 into backups/; keeps the newest 5. RAILS_ENV defaults to development.

## Rules for agents
- Run tools through these wrappers, not bare `rspec` or `rubocop`.
- Keep the executable bit on every file.
- create-backup.sh needs the sqlite3 CLI. It writes a .tmp file, then renames it.

## Verification
- `bin/rspec`
- `bin/rubocop`
- `bin/brakeman` and `bin/bundler-audit`
- `RAILS_ENV=test bin/create-backup.sh` after a backup script change (needs storage/test.sqlite3).
