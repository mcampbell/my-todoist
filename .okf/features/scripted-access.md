---
type: Feature
title: Scripted access
description: A script adds, deletes, and marks tasks done with the browser's own login (session cookie + CSRF token). No API token, no JSON.
resource: file:///home/mcampbell/dev/my-todoist/app/controllers/tasks_controller.rb
tags: [api, scripting, auth, csrf]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-19T00:00:00Z
verified:
  by: claude-code/claude-opus-5-5
  at: 2026-11-19T00:00:00Z
sources:
  - id: readme
    resource: "../../README.md"
    title: "README.md, section Scripted access"
  - id: routes
    resource: "../../config/routes.rb"
    title: "config/routes.rb"
  - id: auth
    resource: "../../app/controllers/concerns/authentication.rb"
    title: "app/controllers/concerns/authentication.rb"
---

# Overview

The app has no separate API. A script sends the same requests as the
browser forms, with the same login.[^readme] The routes come from
`resources :tasks` and its member routes.[^routes]

| Action | Request | Parameters |
|---|---|---|
| Add a task | `POST /tasks` | `task[title]` (quick-add text, see [QuickAdd](/models/quick-add.md)) |
| Delete a task | `DELETE /tasks/:id` | none |
| Mark a task done | `PATCH /tasks/:id/complete` | `completion_notes` (optional) |
| Find tasks | `GET /tasks/search?q=TEXT` | see [Task search](/features/task-search.md) |

# Auth

- Log in with `GET /session/new` (read the `csrf-token` meta tag), then
  `POST /session` with `email_address`, `password`, and
  `authenticity_token`. Keep the cookie jar.
- Each `POST`, `PATCH`, or `DELETE` sends the session's CSRF token in the
  `X-CSRF-Token` header.
- No CSRF token: `422`. A `GET` with no login: redirect to the login page
  (a JSON request gets `401`).[^auth] Unknown `:id`: `404`.
- Login tries are rate-limited (10 per 3 minutes per IP).
- Authorization is out of scope: one user owns every task. See
  [Single-user scope, login required](/decisions/single-user-scope.md).

# Responses

Each action answers with a `302` redirect or HTML, not JSON. A `302`
means success. Mark done calls `Task#complete!`, as the checkbox does: a
one-off task is removed from the list, a recurring task moves to its
next date (see [Task](/models/task.md)).

# Verification

Checked on 2026-11-19 with `curl` against a development server (CSRF
protection on): login `302`, delete `302`, complete `302`, no token `422`,
unknown id `404`.

[^readme]: README.md, section "Scripted access", has a full `curl` example.
[^routes]: `config/routes.rb`: `resources :tasks` and `member { patch :complete }`.
[^auth]: `Authentication#request_authentication` returns `401` for JSON requests.
