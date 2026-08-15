# my-todoist — Design

Local single-user Todoist clone. Rails 8, SQLite, builtin ERB views, RSpec.
Source of decisions: `specs/todo-app-grill.md`.

## Stack

See `specs/tech.md` for the stack, library choices, and standing technical
rules (server-render-first, dependency ladder, etc.) — kept there so
cross-slice tech decisions have one home instead of drifting out of sync
with this doc.

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
- **Frequency indicator** — the recurrence keyword that opens a recurrence
  string; always starts with `every`. Two modifier forms:
  - `every` (no bang) — fixed: next due_at = original due_at + interval.
  - `every!` (bang) — rolling: next due_at = completion_time + interval.
  The `!` rolling modifier applies to any frequency-indicator form below.
  Known possibilities:
  - `every day` / `every! day` — daily
  - `every N days` / `every! N days` — every N days (e.g. `every 3 days`)
  - `every week` / `every! week` — weekly
  - `every N weeks` / `every! N weeks` — every N weeks
  - `every month` / `every! month` — monthly
  - `every N months` / `every! N months` — every N months
  - `every year` / `every! year` — yearly
  - `every N years` / `every! N years` — every N years
  - `every monday` … `every sunday` — specific weekday (rolling `every!
    monday` reschedules from completion date)
  - `every weekday` / `every workday` — Mon–Fri (no holidays)
  - `every! N hours` — rolling, sub-day hours
  - `every N minutes` / `every! N minutes` — down to 1 min granularity
  **Future feature (deferred):** `every <ordinal> <unit>` — the Nth
  incident of that unit in the month. Ordinals: `first`/`1st` through
  `fifth`/`5th` (`second`/`2nd`, `third`/`3rd`, `fourth`/`4th`), plus
  `last`. e.g. `every first monday`, `every 2nd friday`, `every last
  workday`, `every last day`. Combines with the `!` rolling modifier
  (`every! last friday`). Not in v1; see Deferred.
  Non-frequency-indicator recurrence phrases (do not start with `every`):
  `weekdays`/`workday` (shorthand for `every weekday`). `next monday` is a
  one-off date (chronic-parseable), not recurrence — not in this category.
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
form also defaults its date field to today. **Superseded in slice 4** (user
decision, 2026-08-15): once create moves to quick-add text, this default is
dropped — a task with no date token and no time token stays undated
(no due_date, not today). Quick-add is explicit-by-design;
auto-defaulting was a workaround for an always-visible structured date
field, which no longer exists on create.
Carve-out: a bare time token (no date token) implies a date — today if the
time is still strictly ahead, tomorrow if it is now or has passed (e.g.
"buy milk 3pm" typed at 14:00 -> today 3pm; typed at 16:00 -> tomorrow 3pm;
typed at exactly 15:00 -> tomorrow 3pm). An explicit date token with a
time obeys the typed date; no date and no time token -> undated.

### Slice 4 — Quick-add NLP (one-off)  *(Todoist single-field entry)*

Implementation plan: `specs/slice-4-plan.md` (sliced by input type: priority
token, then date/time token, then `#project` token, then structured-field
removal — see that doc's grill session for the resolved decision branches).

Replace create form with single text field. Parse: chronic date/time,
`p1..p4` priority (translated to internal `0..3`, `p1`->3 ... `p4`->0 — see
priority mapping below), `#project`. **`@label` parsing is out of scope for
this slice** (user decision, 2026-08-15) — label assignment stays on the
existing structured control until a later slice. **No recurrence yet** — if
the parser recognizes `every`/`every!` syntax, OR the bare recurrence
shorthand `weekdays`/`workday` (design: shorthand for `every weekday`, not a
`every`-prefixed form), it rejects submission with "Recurrence not supported
yet" (user decision, 2026-08-15) rather than silently folding the phrase into
the title (chronic parses `weekdays` as a one-off date, so rejecting avoids a
silent recurrence->one-off misparse; `workday` isn't chronic-parseable but is
still recurrence shorthand); `next monday` is a one-off date (chronic-parseable),
not recurrence, and is NOT rejected. Slice 5 removes the rejection once it
lands. Rework: replaces slice-1 plain form + slice-1
create controller path.

**Priority mapping.** Quick-add tokens follow Todoist convention (`p1`=most
urgent .. `p4`=none), inverted from the internal `0..3` scale (`0`=baseline/no
badge .. `3`=highest/danger tag). Parser translates: `p1`->3, `p2`->2, `p3`->1,
`p4`->0.

**Inline project creation + drop the structured fields (user intent).** A
`#ProjectName` token that matches no existing project **creates** it (find-or-
create by normalized name — reuses slice-2 NOCASE + trim identity), *unless*
it's a likely typo of an existing project name (fuzzy match), in which case
the parser flags it and asks for confirmation before creating a near-duplicate
project. **Confirm UX (user decision, 2026-08-15, no-JS):** re-render the
quick-add form like a validation failure — banner "Did you mean #Work? [Use
existing] [Create #Wrok anyway]" — same request/response cycle as any other
validation error; no new persisted state, no JS, no new endpoint. Once the
text field owns project, due-date, *and* priority parsing, **remove**
the slice-2 Project dropdown, the Due-date `datetime_field`, and the priority
`<select>` from the task form — the quick-add string is the single source for
those three. Notes textarea is dropped from create (quick-add is a fast
capture tool; extended detail deferred to edit). Label control stays (see
above — `@label` out of scope). **Edit form is unchanged** (user decision,
2026-08-15): keeps its existing structured date picker + project dropdown +
priority select. Only *create* moves to quick-add text; editing an existing
task keeps precise widgets rather than round-tripping through NLP text.

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
Second-level recurrence granularity. `every <ordinal> <unit>` month-boundary
recurrence — Nth incident of a unit in the month, ordinals `first`/`1st`
through `fifth`/`5th` plus `last` (e.g. `every first monday`,
`every 3rd friday`, `every last workday`).
`@label` quick-add parsing (slice 4, 2026-08-15 — label assignment stays on
the structured form control).

## Open questions

None blocking. Confirm `terminal-notifier` install acceptable (else osascript-only).
