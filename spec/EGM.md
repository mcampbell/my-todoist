# spec

## Overview

The RSpec suite. Do not confuse it with `specs/`, which holds design docs.

## Interface

- `models/`, `lib/` (`QuickAdd`), `helpers/`, `requests/`, `system/`, `tasks/`, `config/`, `bin/`.
- `support/authentication_helpers.rb`: signs in each request and system example by default.

## Invariants

- Write a failing spec first for each code change.
- Tag a group `signed_out: true` to run without login.
- `spec/bin` runs plain RSpec without the Rails environment.

## Side Effects

- Uses the test SQLite database. Writes `coverage/lcov.info`.

## Verification

- Run: `bin/rspec`
