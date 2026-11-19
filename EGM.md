# my-todoist Blueprint

## System Overview

A single-user Todoist clone. Rails 8.1, Ruby 3.4, SQLite, ERB, RSpec. It runs on the internet behind nginx (TLS) and a login. `CLAUDE.md` is the style and architecture reference.

## Local Interface & Invariants

- `config.ru`: mounts the app at `RAILS_RELATIVE_URL_ROOT` (default `/`).
- Every route except the login form needs a login session. Scripts log in like the browser and send `X-CSRF-Token` on non-GET requests. See [controllers](./app/controllers/EGM.md) and `README.md` section "Scripted access".

## Subdirectories & System Boundaries

- app: [EGM.md](./app/EGM.md) - controllers, models, grammars, helpers, views, and JS.
- lib: [EGM.md](./lib/EGM.md) - Rake tasks for the login user.
- config: [EGM.md](./config/EGM.md) - frameworks, routes, Importmap, time zone.
- db: [EGM.md](./db/EGM.md) - SQLite schema and migrations.
- spec: [EGM.md](./spec/EGM.md) - RSpec suite.

## Global Invariants

- Single user. Multi-user and authorization are out of scope.
- The app can run under a sub-path. Build URLs with route helpers in Ruby and `appPath` in JS.
- Grammars stay pure and run without the database.
- Due-date writes go through `Task#due_date=` and `Task#due_time=`.

## Global Side Effects

- One SQLite database in `storage/`.
- No background jobs, mail, or external API calls.

## System Verification

- Run: `bin/rubocop && bin/rspec`
