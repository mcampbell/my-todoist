---
type: Feature
title: Project tints
description: Every project gets a deterministic faint background colour on task rows and sidebar links.
tags: [ui, projects, styling]
timestamp: 2026-09-01T18:00:00Z
---

# Overview

`ProjectsHelper#project_tint` picks a faint background colour for a
project by hashing its name (CRC32) into one of 12 evenly spaced HSL
hues at about L92% lightness (strengthened from about L97% so the tint
is actually visible). Deterministic - a bucket hash on the name, not
`String#hash`, so the colour is stable across restarts. No colour is
stored and no picker UI is needed. See
[Project and Label](/models/project-and-label.md).

# Where it applies

| Surface | File | Behaviour |
|---|---|---|
| Task rows | `app/views/tasks/_task.html.erb` | Tinted unless the task is overdue (overdue rows keep the red warning background) |
| Sidebar project links | `app/views/layouts/_navbar.html.erb` | Each project link gets its tint |

# Performance

All task index queries (`index`, `today`, `overdue`, `upcoming`,
`search`) eager-load `:project` alongside `:labels` in
`TasksController`, so the per-row tint never causes an N+1 read.

# Citations

[1] [app/helpers/projects_helper.rb](../../app/helpers/projects_helper.rb)
[2] [app/controllers/tasks_controller.rb](../../app/controllers/tasks_controller.rb)