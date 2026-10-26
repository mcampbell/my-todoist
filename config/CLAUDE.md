# config

## Purpose
Rails app setup: boot, framework loading, routes, database, server, importmap.

## Files
- application.rb - loads only active_model, active_record, action_controller, action_view; time zone Eastern; autoload_lib ignores assets, tasks.
- boot.rb, environment.rb - standard Rails boot.
- routes.rb - session, tasks (member and collection views), projects, labels, completed_occurrences; root is tasks#index.
- database.yml - SQLite at storage/<env>.sqlite3.
- puma.rb - binds 127.0.0.1, PORT default 3000; behind nginx.
- importmap.rb - pins application, notifications, app_path, turbo.
- bundler-audit.yml - ignore list for bin/bundler-audit.
- credentials.yml.enc - encrypted secrets. Do not read or edit.
- environments/, initializers/, locales/ - see their own CLAUDE.md.

## Rules for agents
- Add a Rails framework railtie to application.rb only when a feature needs it.
- Put new JS modules in importmap.rb with a pin. No Node tooling.
- The app may run under RAILS_RELATIVE_URL_ROOT (mounted in config.ru). Use route helpers, never bare "/..." paths.
- Add routes so JSON and HTML requests both stay behind login.
- Do not read config/*.key or credentials files.

## Verification
- `bin/rspec`
- `bin/rubocop`
- `bin/rails routes` after a routes change.
