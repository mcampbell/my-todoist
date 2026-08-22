---
type: Decision
title: Inbox already shows overdue tasks — no filtering needed
description: TasksController#index has no due_at filter, so overdue nil-project tasks already appear; a reported "bug" turned out to be a coverage gap, not a defect.
tags: [inbox, verified-no-bug, regression-test]
timestamp: 2026-08-22T00:00:00Z
---

# Decision

No code change. Added a regression test instead
(`spec/requests/tasks_spec.rb`: "Inbox shows an overdue nil-project
task, marked with the danger background class").

# Rationale

A request came in to "ensure Inbox shows overdue tasks." Investigation
found `TasksController#index` (`Task.where(project: @project).ordered`)
has no due-date filter at all — every nil-project task appears
regardless of due date — and the shared `_task.html.erb` partial already
applies `has-background-danger-light` to any `task.overdue?` row. The
behavior already existed; only test coverage was missing. Confirmed by
writing the test *first* and watching it pass green with zero production
changes, before committing it as a standalone PR.

# Citations

[1] [app/models/task.md](/models/task.md)
