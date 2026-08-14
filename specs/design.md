# my-todoist — Design

Local single-user Todoist clone. Rails 8, SQLite, builtin ERB views, RSpec.
Source of decisions: `specs/todo-app-grill.md`.

## Stack

- Rails 8, Ruby. SQLite3 (dev + "prod" are same local DB).
- Views: builtin ERB. Assets: Propshaft + Importmap (no Node build).
- CSS: **Bulma** (pure-CSS drop-in via importmap/vendored stylesheet).
- Jobs: Solid Queue (SQLite-backed).
- Tests: rspec-rails.
- Date NLP: `chronic` gem (one-off dates). Recurrence: custom parser (PORO).
- No auth. Single user. Local `bin/dev`.

## Domain

Single mutable `Task` row (no template/instance, no subtasks). On complete of a
recurring task, `due_at` advances in place.

**Task**: title, notes, due_at (datetime, nullable), completed_at (nullable),
project_id (nullable = Inbox), priority (0..3), recurrence (string, nullable),
notified_at (datetime, nullable).
**Project**: name.
**Label**: name; Task<->Label join (`task_labels`).

### Recurrence semantics (core must-have)

- `every! X` = rolling. next due_at = completion_time + X.
- `every X` (no bang) = fixed. next due_at = original due_at + X.
- Units down to minutes (`every! 10 minutes`). Floor granularity = 1 min.
- Phrases: `every day`, `every 3 days`, `every! N minutes`, `every monday`,
  `weekdays`/`workday` (Mon–Fri, no holidays), `next monday`.
- Missed fixed occurrences (app was off): mark most-recent overdue, don't skip.
  On complete, jump to nearest future occurrence (not due_at+interval landing in past).

Recurrence lives in a `Recurrence` PORO: `parse(string) -> rule`,
`rule.next_from(anchor)`. Pure, no DB. Unit-testable in isolation.

## Slices

Ordered. Walking skeleton first. Slices 2, parser(4), notifications(6) run as
parallel streams after slice 1 lands the schema+models.

### Slice 1 — Walking skeleton  *(ships usable flat todo list)*

Rails app + SQLite + RSpec + Bulma layout. Task model (title, notes, due_at,
completed_at). Plain structured create/edit form. List active tasks. Mark
complete (soft, set completed_at). Completed history view. One implicit Inbox.
Deploys as a working plain todo list.

### Slice 2 — Organization  *(projects, labels, priority)*

Add project_id, priority, labels join to Task. Project + Label CRUD. Bulma
sidebar nav (Inbox + project list). Per-project + Inbox views. Priority badge,
label tags on task rows.

### Slice 3 — Date views  *(Today / Upcoming)*

Today view (due_at <= end-of-today OR overdue). Upcoming view (grouped by date,
next N days). Dates still set via form (no NLP yet). Adds nav links.

### Slice 4 — Quick-add NLP (one-off)  *(Todoist single-field entry)*

Replace create form with single text field. Parse: chronic date/time,
`p1..p4` priority, `#project`, `@label`. No recurrence yet. Rework: replaces
slice-1 plain form + slice-1 create controller path.

### Slice 5 — Recurrence engine  *(every / every!)*

`Recurrence` PORO + parser. Quick-add recognizes `every`/`every!` phrases and
stores recurrence string. On complete: advance due_at per semantics above,
clear completed_at (task stays active, re-scheduled). Missed-occurrence catch-up
rule. Depends on slice 4 grammar + Task.due_at.

### Slice 6 — Notifications + scheduler

Adds the Solid Queue stack (removed from slice 1 as unused): `solid_queue` gem,
`active_job/railtie` in application.rb, queue DB in database.yml + production.rb
adapter config, `bin/jobs`, `config/queue.yml`, `config/recurring.yml`,
`db/queue_schema.rb`. Then a recurring job polls every 1 min for due, un-notified tasks
(due_at <= now AND notified_at IS NULL AND completed_at IS NULL). Fire macOS
notification via `terminal-notifier` (fallback `osascript`). Set notified_at.
Manual start (`bin/dev`); on boot the same poll sweeps missed items and fires
once. Depends only on Task.due_at (slice 1) — can parallel slices 2–5.

## Merge conflicts (taken to unlock parallel streams)

1. **`tasks` schema/model** — slices 2, 5, 6 each add columns (project_id +
   priority; recurrence; notified_at) + concurrent migrations. Serialize
   migrations by timestamp; expect model-file merge on Task.
2. **Layout / nav partial** — slice 2 (sidebar) and slice 3 (Today/Upcoming
   links) both edit `app/views/layouts` nav.
3. **TasksController#create** — slice 1 structured params vs slice 4 parse-from-
   text = same action edited by two streams.

## Rework (taken to ship earlier)

1. **Plain create form → quick-add field** — slice 1 form replaced by slice 4.
   Accepted to ship a usable app in slice 1.
2. **Create controller path** — slice 1 strong-params create reworked by slice 4
   text parsing.
3. **Active-task filtering** — slice 3 filters reworked in slice 5 when
   "next occurrence" replaces static due_at on completion.

## Deferred (named, out of v1)

Sections within projects. Subtasks. Todoist import. Holiday-aware weekdays.
Email/in-app notifications (macOS-only). launchd autostart. Multi-timezone.
Second-level recurrence granularity.

## Open questions

None blocking. Confirm `terminal-notifier` install acceptable (else osascript-only).
