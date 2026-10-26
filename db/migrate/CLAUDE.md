# db/migrate/

## Purpose
Active Record migrations (`ActiveRecord::Migration[8.1]`). 17 files, one per change.

## Files
- `20260813234958`..`20260814013913` - create tasks, projects, labels; add organization to tasks; create task_labels.
- `20260815*` - add all_day to tasks; create completed_occurrences; add recurrence to tasks; add all_day to completed_occurrences.
- `20260830190419` - add recurrence_anchor to tasks.
- `20260923145410` - add in_progress to tasks.
- `20261010220554`, `20261010220555` - create users, sessions (login).
- `20261014143020`, `20261015002246` - add notes and completion_notes to completed_occurrences.
- `20261022191742`, `20261022193143` - add recurrence_remaining, recurrence_ends_at to tasks.

## Rules for agents
- Never edit an applied migration. Add a new one with `bin/rails g migration`.
- Name files `<timestamp>_<verb>_<thing>.rb`, one change each.
- Timestamps are not strictly ordered by commit date (`20260923145410` was added in October). Use a fresh timestamp.
- Regenerate `db/schema.rb` by migrating. Commit both together.
- Write a failing spec first for the behavior that needs the column (project TDD rule).

## Verification
- `bin/rails db:migrate` and `bin/rails db:rollback` (if reversible).
- `bin/rspec`
- `bin/rubocop`
