---
type: Service Class
title: OsNotifier
description: Pops a native OS notification (macOS or WSL2/Windows) for a due task; no-op elsewhere.
resource: file:///home/mcampbell/dev/my-todoist/app/models/os_notifier.rb
tags: [notifications, macos, wsl2, shell-out]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

Pure OS detection + shell-out; no state, no DB. `OsNotifier.notify(title:,
message:)` dispatches by platform:

- **macOS** (`RbConfig::CONFIG["host_os"]` matches `/darwin/i`) — shells
  out to `osascript -e 'display notification ...'` via `Open3.capture3`
  (array args, no shell — injection-safe by construction; escaping is
  only about valid AppleScript string syntax).
- **WSL2** (`/proc/version` mentions "microsoft" — `host_os` alone
  reports plain `linux` under WSL2, so this needed its own detection
  method, `OsNotifier.wsl?`) — pops a Windows balloon-tip toast via
  `powershell.exe` -> `System.Windows.Forms.NotifyIcon`, **spawned
  detached** (`Process.spawn` + `Process.detach`, not `Open3.capture3`)
  because the balloon script needs `Start-Sleep -Seconds 6` alive before
  disposing the tray icon, and a synchronous shell-out would have tied up
  a Puma request thread for that whole time.

Each platform has its own quote-escaping method
(`escape_applescript` / `escape_powershell`) since the two scripting
languages have incompatible string-literal escaping rules.

# Trigger path

Deliberately **not** wired into `TasksController#due_since` (the polling
endpoint) — see
[OS notification triggered client-side, not server-side](/decisions/os-notification-client-triggered.md).
Instead, `POST /os_notification` (`OsNotificationsController#create`) is
called from the client's existing `toast()` function in
`notifications.js`, the same function that already renders the in-page
toast — see [Due reminders](/features/due-reminders.md).

# Citations

[1] [app/models/os_notifier.rb](../../app/models/os_notifier.rb)
[2] [specs/os-notification-design.md](../../specs/os-notification-design.md)
