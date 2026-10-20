---
type: Feature
title: Due reminders
description: Client-side JS poll (no background job) that shows an in-page toast, plays a beep, and shows a browser OS notification when a timed task becomes due; a per-browser Mute silences the beep and OS notification.
resource: file:///home/mcampbell/dev/my-todoist/app/javascript/notifications.js
tags: [notifications, javascript, polling, mute]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-19T00:00:00Z
sources:
  - resource: "../../specs/os-notification-design.md"
    title: "specs/os-notification-design.md"
  - id: design
    resource: "../../specs/browser-notification-design.md"
    title: "specs/browser-notification-design.md"
  - resource: "/decisions/browser-notification-api.md"
    title: "decisions/browser-notification-api"
---

# Overview

`notifications.js` polls `GET /tasks/due_since.json` every 30s, advancing
a per-tab `anchor` to the server's returned `now` on every successful
poll (so client/server clock skew can't miss or duplicate a task). A
silent poll fires once on tab-refocus after being hidden, to avoid
dumping a toast burst for everything that went due while backgrounded —
it advances the anchor without rendering anything.

`toast(task)` (only called on a *non-silent* poll) always renders the
in-page notification. Unless muted, it also plays a short Web-Audio beep
and calls `notifyOs(task)`, which shows a browser `Notification` when
permission is `"granted"`.[^design] See
[Browser notifications replace the server notifier](/decisions/browser-notification-api.md).

# Permission

Safari and Firefox ask only from a user gesture. One document `click`
handler asks once per tab while permission is `"default"`, and again after
each Unmute. It runs the Mute toggle first, so a Mute click never asks.

# Mute

`tasks/_page_header.html.erb` renders a `[data-mute-toggle]` button when the
view passes `mute_toggle: true`: Inbox/project, Today, Overdue, Upcoming.
Search, Completed, and completed-task details do not. The flag is
`localStorage["notifications-muted"] = "1"`, per browser; a storage error
reads as unmuted. `turbo:load` syncs the label ("Mute"/"Unmute") and
`aria-pressed`. Other open tabs pick up a new label on their next visit; the
mute itself applies at once.

[^design]: specs/browser-notification-design.md, S1 and S2.
