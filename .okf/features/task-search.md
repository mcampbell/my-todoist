---
type: Feature
title: Task search
description: GET /tasks/search — title-only, case-insensitive substring search over active tasks, with an opt-in completed-history checkbox.
resource: file:///home/mcampbell/dev/my-todoist/app/views/tasks/search.html.erb
tags: [search, ui]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

`GET /tasks/search?q=&include_completed=1`. Matches `Task#title` (and
`CompletedOccurrence#task_title` when the checkbox is checked) via SQL
`LIKE` — SQLite's `LIKE` is already case-insensitive for ASCII by
default, so no `ILIKE`/`COLLATE NOCASE` is needed. User-typed `%` and `_`
(LIKE wildcards) are escaped with an explicit `ESCAPE` clause
(`TasksController#escape_like`) so they match literally.

Results order like every other list view — [Task](/models/task.md)'s
`ordered` scope — with completed matches appended after, ordered
`completed_at desc`. Blank query renders the form only, no table. Cancel
returns to Inbox.

Reachable via the navbar, the `/` global shortcut (mirrors the `q` ->
new-task shortcut), and `autofocus` on the query input for the same
"land focus immediately" behavior `q` gets. `Esc` on this page also
returns to Inbox, same mechanism as `/tasks/new` — see
[Keyboard shortcuts](/features/keyboard-shortcuts.md).

# Citations

[1] [specs/task-search-design.md](../../specs/task-search-design.md)
[2] [app/controllers/tasks_controller.rb](../../app/controllers/tasks_controller.rb)
