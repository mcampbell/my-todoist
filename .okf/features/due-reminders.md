---
type: Feature
title: Due reminders
description: Client-side JS poll (no background job) that shows an in-page toast, plays a beep, and optionally pops a native OS notification when a timed task becomes due.
resource: file:///home/mcampbell/dev/my-todoist/app/javascript/notifications.js
tags: [notifications, javascript, polling]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

`notifications.js` polls `GET /tasks/due_since.json` every 30s, advancing
a per-tab `anchor` to the server's returned `now` on every successful
poll (so client/server clock skew can't miss or duplicate a task). A
silent poll fires once on tab-refocus after being hidden, to avoid
dumping a toast burst for everything that went due while backgrounded —
it advances the anchor without rendering anything.

`toast(task)` (only called on a *non-silent* poll) renders the in-page
notification, plays a short Web-Audio beep, and calls `notifyOs(task)`,
which `POST`s to `/os_notification` -> [OsNotifier](/models/os-notifier.md).

# Citations

[1] [specs/os-notification-design.md](../../specs/os-notification-design.md)
[2] [decisions/os-notification-client-triggered](/decisions/os-notification-client-triggered.md)
