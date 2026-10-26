# CLAUDE.md (app/javascript)

## Purpose
Browser JavaScript served through Importmap. No Node tooling.

## Files
- `application.js`: entry point. Imports `@hotwired/turbo-rails`, `notifications`, and `app_path`.
- `app_path.js`: exports `appPath(path)`. Adds the sub-path prefix (`RAILS_RELATIVE_URL_ROOT`).
- `notifications.js`: in-page toasts. Polls for due reminders.

## Rules for agents
- Build every URL with `appPath("/...")`. Never a bare `"/..."` literal.
- Do not add a bundler or Node packages. Use Importmap pins.
- The reminder poll must not treat a 401 as a redirect target.

## Verification
- `bin/rails server`, then check the page in a browser.
- `bin/rspec` (system specs load the JS).
- `bin/rubocop`
