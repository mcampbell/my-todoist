---
type: Decision
title: Browser notifications replace the server notifier
description: Due-task OS toasts come from the browser Notification API, not a server shell-out, so they work when the app runs in the cloud; a per-browser Mute silences them.
tags: [notifications, javascript, cloud]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-19T00:00:00Z
sources:
  - id: design
    resource: "../../specs/browser-notification-design.md"
    title: "specs/browser-notification-design.md"
  - id: pr-56
    resource: "https://github.com/mcampbell/my-todoist/pull/56"
    title: "PR #56: Browser notifications and a Mute toggle"
---

# Decision

Delete `OsNotifier`, `OsNotificationsController`, and `POST /os_notification`.
`notifications.js` calls `new Notification("Task due", { body: title })`
when permission is `"granted"`, so the OS toast shows on the device you look
at.[^design] The in-page toast and the Web Audio beep stay.

A Mute button on the task lists (Inbox/project, Today, Overdue, Upcoming)
sets a `localStorage` flag. Mute silences the beep and the OS toast; the
in-page toast still shows.[^pr-56]

# Rationale

- The app may move to the cloud. A server shell-out (`osascript`,
  `powershell.exe`) pops the toast on the server's screen, not yours.
- Safari and Firefox ask permission only from a user gesture, so the ask
  runs on a click, never on page load. One click handler runs the Mute
  toggle first, so a Mute click never prompts.
- Mute stays per browser (no DB, no migration): each device chooses for
  itself. The user picked this over a server-side flag.
- No service worker: a tab must stay open, as before. Android Chrome needs
  a service worker for `new Notification`; the call is wrapped in
  try/catch and skips there.

# Consequences

- Supersedes [OS notification triggered client-side](/decisions/os-notification-client-triggered.md).
- The JS has no automated test ([No JS-capable test driver](/decisions/no-js-test-driver.md)).
  Request specs cover only where the Mute button renders.

[^design]: specs/browser-notification-design.md, S1.
[^pr-56]: PR #56, S2 commit.
