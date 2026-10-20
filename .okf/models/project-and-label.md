---
type: ActiveRecord Model
title: Project and Label
description: Lightweight organizing tags for tasks — a task has at most one Project, any number of Labels.
resource: file:///home/mcampbell/dev/my-todoist/app/models/project.rb
tags: [core-model, active-record]
generated:
  by: process:okf-migrate
  at: 2026-08-22T00:00:00Z
sources:
  - resource: "../../app/models/project.rb"
    title: "app/models/project.rb"
  - resource: "../../app/models/label.rb"
    title: "app/models/label.rb"
  - resource: "../../app/models/task_label.rb"
    title: "app/models/task_label.rb"
---

# Overview

Both `Project` and `Label` are near-identical thin models: `name`
normalized (stripped) and validated unique case-insensitively — enforced
at the DB layer via SQLite's `NOCASE` collation on the `name` column, not
just an app-level validation, so uniqueness holds even under concurrent
writes.

`Project has_many :tasks, dependent: :nullify` — deleting a project
un-assigns its tasks back to Inbox rather than deleting them.

`Label has_many :tasks, through: :task_labels`; the join model
`TaskLabel` enforces one label per task at most once
(`validates :label_id, uniqueness: { scope: :task_id }`).

`#project_name` free-text tokens in [QuickAdd](/models/quick-add.md) are
matched against existing `Project` names case-insensitively; a near-miss
typo triggers a "did you mean" suggestion in `TasksController` via
`DidYouMean::SpellChecker`.
