---
type: Service
title: my-todoist
description: Local single-user Todoist clone — Rails 8.1, Ruby 3.4, SQLite, ERB, RSpec.
resource: file:///home/mcampbell/dev/my-todoist
tags: [rails, sqlite, local-app, todo]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

A local, single-machine, single-user task manager modeled on Todoist.
Wholly LLM-coded; `CLAUDE.md` at the repo root and `specs/` are the style
reference for any change. Scope is deliberately narrow: no auth/authz, no
network exposure, no multi-user concerns — see
[No-auth, single-user scope](/decisions/single-user-scope.md).

Loads only Active Record, Action Controller, Action View, and Active
Model. Other Rails frameworks (Active Job, Solid Queue, Active Storage,
Action Mailer, Action Cable) are added only when a specific feature
needs them — due reminders, for instance, are deliberately client-side
JS polling rather than a background job (see
[Task](/models/task.md), [Due reminders](/features/due-reminders.md)).

Assets are served via Propshaft + Importmap; there is no Node tooling.

# Request shape

`TasksController` is the largest controller — collection actions for
each smart list (`index` = Inbox, `today`, `overdue`, `upcoming`,
`completed`, `search`) plus the standard CRUD member actions. `Project`
and `Label` get their own controllers. `OsNotificationsController` is a
single-action controller triggered client-side (see
[OsNotifier](/models/os-notifier.md)).

Three grammars parse free text into structured data, each in its own
model class computing independently of ActiveRecord — see
[QuickAdd](/models/quick-add.md) and [Recurrence](/models/recurrence.md).

# Schema

| Table | Notable columns |
|-------|------------------|
| `tasks` | `title`, `due_at`, `all_day`, `priority` (0-3, check constraint), `recurrence`, `project_id`, `notes` |
| `projects` | `name` (unique, case-insensitive via `NOCASE` collation) |
| `labels` | `name` (unique, case-insensitive via `NOCASE` collation) |
| `task_labels` | join table, `task_id` + `label_id`, unique per task |
| `completed_occurrences` | snapshot of a completed task: `task_title`, `project_name`, `priority`, `label_names` (denormalized string), `due_at`, `all_day`, `completed_at` |

`completed_occurrences` is a deliberate denormalization — see
[Task#complete!](/models/task.md).

# Testing

`bin/rspec` (RSpec, `rack_test` driver only — no Selenium/Cuprite, so no
`js: true` specs; JS behavior like keyboard shortcuts is reviewed but not
test-covered) and `bin/rubocop` (omakase) must both pass on every change.
TDD is required: a failing spec precedes every implementation change.

# Citations

[1] [CLAUDE.md](../../CLAUDE.md)
[2] [specs/](../../specs/)
