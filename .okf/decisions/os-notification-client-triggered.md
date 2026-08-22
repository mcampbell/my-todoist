---
type: Decision
title: OS notification triggered client-side, not from the polling endpoint
description: OsNotifier.notify is called from the client's toast() function via a dedicated endpoint, not from inside TasksController#due_since.
tags: [notifications, code-review-finding]
timestamp: 2026-08-22T00:00:00Z
---

# Decision

`OsNotifier.notify` is invoked from `notifications.js`'s `toast()`
function, via `POST /os_notification`
(`OsNotificationsController#create`) — not called directly from
`TasksController#due_since`, the endpoint the client polls every 30s.

# Rationale

The first implementation called `OsNotifier.notify` inside
`due_since` itself. Code review caught three problems:

1. **Violated the client-side-reminders rule** —
   [No-auth, single-user scope](single-user-scope.md)'s sibling
   convention in `CLAUDE.md`, "keep due reminders client-side," was
   crossed by moving delivery into a server action.
2. **Fired on silent polls too.** `due_since` is also hit by a *silent*
   poll on tab-refocus (see [Due reminders](/features/due-reminders.md)),
   specifically designed to avoid a toast burst for everything that went
   due while backgrounded — the silent flag never reached the server, so
   every one of those tasks would still pop an OS notification.
3. **Doubled the DB query per poll** — `.each` over the tasks relation
   for notification purposes, then a separate `.pluck` for the JSON
   response.

Moving the call into `toast()` — which the silent poll path never
invokes — fixed all three at once: notifications only fire when the
in-page toast also fires, and `due_since`'s query shape is unchanged.

# Citations

[1] [specs/os-notification-design.md](../../specs/os-notification-design.md)
