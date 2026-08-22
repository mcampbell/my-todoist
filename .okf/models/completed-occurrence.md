---
type: ActiveRecord Model
title: CompletedOccurrence
description: An immutable snapshot of a task at the moment it was completed — history survives task mutation or destruction.
resource: file:///home/mcampbell/dev/my-todoist/app/models/completed_occurrence.rb
tags: [core-model, active-record, history]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

Not a foreign-keyed reference to `Task` — it's a fully denormalized copy
(`task_title`, `project_name`, `priority`, `label_names` as a
comma-joined string, `due_at`, `all_day`, `completed_at`). Created by
[Task#complete!](/models/task.md) on every completion, recurring or not,
before the source `Task` row is either destroyed or advanced to its next
occurrence.

Several view helpers (`priority_badge`, `due_tag`) duck-type against
`priority`/`due_at`/`all_day?` and work unmodified against a
`CompletedOccurrence`, which is why
[Task search's optional completed-results branch](/features/task-search.md)
could reuse them directly instead of writing parallel rendering logic.

# Schema

| Field | Type | Description |
|-------|------|-------------|
| `task_title` | String | Required |
| `project_name` | String or nil | nil = was Inbox |
| `priority` | Integer | Required |
| `label_names` | String or nil | Comma-joined, sorted case-insensitively at snapshot time |
| `due_at` / `all_day` | | Same semantics as `Task` |
| `completed_at` | Datetime | Required |

# Citations

[1] [app/models/completed_occurrence.rb](../../app/models/completed_occurrence.rb)
