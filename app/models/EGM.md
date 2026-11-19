# Models

## Overview

Active Record models and three pure grammars. The grammars parse free text into structured data. They do not touch the database.

## Interface

- `Task`: the main record. Scopes `ordered`, `due_today_or_undated`, `due_between`, `overdue`. Methods `complete!(completion_notes:)`, `skip!`, `overdue?`. Virtual setters `due_date=`, `due_time=`, `ends_on_date=`.
- `CompletedOccurrence`: a snapshot of a task at completion. Stores names as text, not foreign keys.
- `Project`, `Label`, `TaskLabel`: task grouping. Names are unique without case.
- `User`, `Session`, `Current`: login. `User` has `has_secure_password` and a 12-character minimum password.
- `QuickAdd.parse(text)`: title to `{ title:, priority:, due_date:, due_time:, project_name:, recurrence:, ... }`.
- `Recurrence.parse(string)` and `#next_from(due_at:, now:)`: the `every(!)? (count)? unit` grammar.
- `PointInTime.parse(text, now:)`: one-shot anchored dates, for example "first monday in march".
- `MonthDay`, `CalendarTerms`: shared calendar math and word tables for the anchored grammars.

## Invariants

- `QuickAdd.parse` runs a fixed sequence of `extract_*!` methods. Order matters. Each extractor must not overwrite an earlier result.
- To add a grammar: add a regex constant, a `private_class_method` extractor, and wire it into `self.parse` with an inline comment.
- Use Chronic only inside `QuickAdd.date_span`. Recurrence and `in X unit` use their own regex and math.
- `NUMERIC_DATE_RE` gates numeric dates, not Chronic.
- `Recurrence`, `PointInTime`, `MonthDay`, and `CalendarTerms` are pure. No database, no state.
- Fixed recurrence keeps phase from the original due date. `:month` and `:quarter` step by 30 or 90 days, not calendar months. Rolling recurrence (`every!`) steps from completion time.
- Write due dates with `due_date=` and `due_time=`. `compose_due_at` sets `due_at` and `all_day`. A `nil` `due_time` means all-day. Midnight is a valid time.
- `priority` is 0 to 3. Input `p1` maps to stored 3. `p4` maps to stored 0.

## Side Effects

- `Task#complete!` and `Task#skip!` take a row lock. `complete!` writes a `CompletedOccurrence` and then deletes or advances the task.
- Chronic reads `Time.zone` (Eastern), set in `config/initializers/chronic.rb`.

## Verification

- Run: `bin/rspec spec/models spec/lib`
