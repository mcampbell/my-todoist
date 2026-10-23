---
type: ActiveRecord Model
title: Task
description: The core domain object — a to-do item with optional due date/time, priority, project, labels, and recurrence.
resource: file:///home/mcampbell/dev/my-todoist/app/models/task.rb
tags: [core-model, active-record]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-23T00:00:00Z
sources:
  - resource: "../../app/models/task.rb"
    title: "app/models/task.rb"
  - resource: "../../db/schema.rb"
    title: "db/schema.rb"
  - id: ending-design
    resource: "../../specs/recurrence-ending-design.md"
    title: "specs/recurrence-ending-design.md"
---

# Overview

`belongs_to :project, optional: true` (no project = Inbox), `has_many
:labels, through: :task_labels`. All due-date writes route through the
virtual setters `due_date=`/`due_time=`; `compose_due_at`
(`before_validation`) combines them into the real `due_at` column and
derives `all_day` (true when no time was given). **Check `due_time` for
`nil` to detect an all-day task** — midnight is a valid clock time, not a
signal by itself.

`priority` is a 0-3 integer (DB check constraint), displayed as p1..p4
(p1 most urgent, integer 3; p4/priority 0 renders no badge). Mapping
lives in `TasksHelper::PRIORITY_LABELS`, inverted from
`QuickAdd::PRIORITY_TOKENS` — one source of truth.

# Completion

`#complete!` runs inside a `with_lock`. It always snapshots the task
into a `CompletedOccurrence` row (title, project name, priority, denormalized
label names, due info, completion time) — this is why completion
history survives even after a recurring task's `Task` row is mutated (or
a non-recurring task's row destroyed).

- No `recurrence` -> `destroy!` (task is done).
- `recurrence` present -> `Recurrence.parse(recurrence).next_from(...)`
  computes the next `due_at`, and the task is updated in place, not
  recreated. A rolling all-day recurrence that lands off-midnight clears
  `all_day` so the new due tag shows a time.

# Scopes

| Scope | Purpose |
|-------|---------|
| `ordered` | `due_at ASC NULLS LAST, created_at DESC` — the default list ordering, reused by every list view including [Task search](/features/task-search.md) |
| `due_today_or_undated` | Today view |
| `due_between(range)` | Upcoming view |
| `overdue` | `due_at < ` start of today; also drives the danger-red row highlight in the shared `_task` partial, which is why [Inbox already shows overdue tasks](/decisions/inbox-overdue-no-bug.md) with no extra filtering needed |

# Times left (recurrence_remaining)

Nullable integer column `tasks.recurrence_remaining`. nil = no limit. Validated integer 1..10_000; the cap stops a value past SQLite's 64-bit range from raising `ActiveModel::RangeError` (a 500). Cleared in `before_validation` when `recurrence` is blank. `complete!` destroys the task (after writing the CompletedOccurrence snapshot) when the count is 1, else advances and decrements by 1. `skip!` advances without changing the count.[^ending-design]

# End date (recurrence_ends_at)

Nullable datetime column `tasks.recurrence_ends_at`. Inclusive. A date with no time is stored as 23:59:59 that day (`ends_all_day?` checks for it). In `advance_to_next_occurrence!` (shared by `complete!` and `skip!`), the task is destroyed when the next occurrence lands after the end. `complete!` has already logged the CompletedOccurrence; `skip!` logs nothing. Validations: one limit only ("use one ending: a date or a count"), and the end may not be before `due_at` ("the task ends before its next occurrence"), so create, edit, and reschedule all hit it. The edit-form virtual fields `ends_on_date` / `ends_on_time` (mirroring `due_date` / `due_time`) compose it in `before_validation`; a blank date removes it. Cleared with the recurrence, like the count.[^ending-design]

[^ending-design]: specs/recurrence-ending-design.md, S1 and S2.

# Time in the Recurrence field

The edit form's Recurrence field accepts quick-add's rule-plus-time text, such as "every workday at 4pm" or "every workday 16:00". `TasksController#split_recurrence_time!` runs the text through `QuickAdd.parse`. When the result holds only a recurrence and a due time, the rule goes to `recurrence` and the time goes to `due_time`. That time wins over the pre-filled Due time picker. When the reschedule box is used, the reschedule text sets the time and the field's time is dropped. Text with any other quick-add part (a date, a priority, `starting`) stays raw, so `recurrence_must_be_parseable` still rejects it.
