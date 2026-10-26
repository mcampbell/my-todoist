# config/locales

## Purpose
I18n translation files.

## Files
- en.yml - Rails default stub with one key, `hello`. Nothing in the app depends on it.

## Rules for agents
- English only. Views use literal text; no i18n keys are required.
- Production sets i18n.fallbacks = true.
- Add keys here only when a view or model calls `t(...)`.

## Verification
- `bin/rspec`
- `bin/rubocop`
