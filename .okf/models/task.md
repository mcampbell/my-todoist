---
type: ActiveRecord Model
title: Task
description: The core domain object — a to-do item with optional due date/time, priority, project, labels, and recurrence.
resource: file:///home/mcampbell/dev/my-todoist/app/models/task.rb
tags: [core-model, active-record]
timestamp: 2026-08-22T00:00:00Z
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

# Citations

[1] [app/models/task.rb](../../app/models/task.rb)
[2] [db/schema.rb](../../db/schema.rb)
