# CLAUDE.md (app/models)

## Purpose
Domain models and the three free-text grammars (quick add, recurrence, point in time).

## Files
- `application_record.rb`: abstract base class.
- `task.rb`: `Task`. Owns due-date writes. `due_date=` and `due_time=` set virtual attributes. `compose_due_at` (before_validation) sets `due_at` and `all_day`.
- `project.rb`, `label.rb`, `task_label.rb`: records for projects, labels, and their join.
- `completed_occurrence.rb`: one completed run of a recurring task.
- `user.rb`, `session.rb`, `current.rb`: login user, login session rows, request-scoped current user.
- `quick_add.rb`: `QuickAdd.parse`. Runs the `extract_*!` sequence. Order matters.
- `recurrence.rb`: `Recurrence.parse` and `#next_from`. Pure computation, no DB.
- `point_in_time.rb`: `PointInTime.parse`. Parses clock-time phrases.
- `calendar_terms.rb`, `month_day.rb`: shared calendar vocabulary and month-day parsing.

## Rules for agents
- Write due dates only through `Task#due_date=` and `due_time=`.
- Check `due_time` for `nil` to detect all-day. Midnight is a valid time.
- Add a grammar as an `extract_*!` method in `quick_add.rb`. Document the wiring point inline.
- `Recurrence` must stay free of database access.

## Verification
- `bin/rspec spec/models`
- `bin/rspec spec/lib/quick_add_spec.rb`
- `bin/rubocop`
