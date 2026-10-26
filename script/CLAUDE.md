# script

## Purpose
Rails placeholder for one-off scripts. Currently empty.

## Files
- .keep - keeps the directory in git. No scripts exist.

## Rules for agents
- Put runnable tools in bin/, not here.
- Put rake tasks in lib/tasks (see lib/tasks/user.rake).
- If you add a script, load Rails with `bin/rails runner`. Do not hardcode URL paths.

## Verification
- `bin/rubocop`
- `bin/rspec`
