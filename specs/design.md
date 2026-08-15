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
- Invariant: next due_at is never in the past. On complete, march forward
  from the original due_at in steps of X — repeatedly re-applying the same
  interval, never jumping straight to today — until the result is >= today.
  This preserves the original phase/grid (e.g. an every-3-days task keeps
  landing on the same Mon/Thu/Sun-style cycle) rather than resetting it to
  the completion date. Examples: an `every wednesday` task 10 days overdue,
  completed on a Saturday, steps 0->7->14 days from the missed Wednesday and
  lands on the coming Wednesday (4 days out). An `every 3 days` task overdue
  by 8 days steps 0->3->6->9 days from the original due_at and lands 1 day
  out, not on today.

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

Today view (due_at <= end-of-today OR overdue OR undated — an undated task
carries no due date to exclude it, so it counts as "today" until it's dated
or completed). Upcoming view (grouped by date, next N days; excludes today
and undated, since Today already owns both). Dates still set via form (no
NLP yet). Adds nav links.

**Due date/time entry (added post-slice-3):** the due-date form field splits
into a date field plus an optional time field, backed by an `all_day`
boolean column — a task with no time entered is `all_day: true` (`due_at`
stored at beginning-of-day), distinct from a task genuinely set to midnight.
`due_today_or_undated`/`due_between` key off `due_at` only, unaffected.
Slice 6's notifier should skip `all_day` tasks (no time to fire a
notification at).

**New task entry point on every filter view (added post-slice-3):** the
New task button (previously only on Inbox/per-project index) now also
appears on Today/Upcoming/Completed via a shared `_page_header` partial,
and on the sidebar nav link. Creating a task from any of these returns to
that same view afterward (not Inbox) — threaded via a `return_to` query
param -> hidden form field -> controller redirect, since the browser's
Referer on the create POST is the `/tasks/new` page itself, not the
original view (unlike update/destroy/complete, which use
`redirect_back_or_to` directly against the real referer). The New task
form also defaults its date field to today.

### Slice 4 — Quick-add NLP (one-off)  *(Todoist single-field entry)*

Replace create form with single text field. Parse: chronic date/time,
`p1..p4` priority, `#project`, `@label`. No recurrence yet. Rework: replaces
slice-1 plain form + slice-1 create controller path.

**Inline project creation + drop the structured fields (user intent).** A
`#ProjectName` token that matches no existing project **creates** it (find-or-
create by normalized name — reuses slice-2 NOCASE + trim identity). Once the
text field owns project *and* due-date parsing, **remove** the slice-2 Project
dropdown and the Due-date `datetime_field` from the task form — the quick-add
string is the single source. Keep priority + label controls only if the parser
does not yet cover `p1..p4` / `@label` (goal: text covers all four, form shrinks
to one input). Open Qs for that slice: typo/no-match on `#project` — auto-create
vs confirm; whether `@label` also auto-creates (labels are cheap, lean create);
edit UX once the structured fields are gone (edit still needs a way to reassign
project/due without retyping).

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
