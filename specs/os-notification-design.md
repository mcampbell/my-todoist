# OS-level toast for due tasks (macOS / WSL2)

## Grill

Q: Where does OS detection happen?
A: `OsNotifier.macos?` (`app/models/os_notifier.rb`), `RbConfig::CONFIG["host_os"]
=~ /darwin/i`. Pure computation, no DB, no state — same posture as
`Recurrence`.

Q: How does it actually pop a native notification?
A: Shells out to `osascript -e 'display notification ...'` via
`Open3.capture3` with array args (no shell interpolation — the OS command
is `osascript`/`-e`/script as three separate exec args, so user-controlled
text in the script string is an AppleScript-syntax concern, not a shell-
injection one). No-op on non-macOS.

Q: First cut wired this into `TasksController#due_since` (the poll
endpoint). Why not?
A: Code review caught three problems with that:
1. Violates CLAUDE.md's "keep due reminders client-side" rule — delivery
   moved into a server action instead of staying behind the client's
   existing toast logic.
2. `due_since` is also polled *silently* on tab-refocus
   (`notifications.js` `poll({ silent: true })`, added specifically to
   avoid dumping a toast burst for tasks that went due while backgrounded)
   — the silent flag never reached the server, so silent polls still
   fired OS notifications.
3. Doubled the DB query per poll (`.each` then a separate `.pluck`).

Q: Fixed how?
A: Moved the trigger to the client's `toast()` function in
`notifications.js` — the same function that already renders the in-page
toast and beeps, and which the silent poll path never calls. `toast()`
now also POSTs to `/os_notification` (fire-and-forget, errors logged and
swallowed — an OS toast is a nice-to-have layered on the in-page one,
never worth failing the poll over). `OsNotificationsController#create`
delegates to `OsNotifier.notify`.

Q: Multi-tab duplicate notifications?
A: Same class of risk the in-page toast already has (each tab polls
independently) — not a regression introduced by this feature, so out of
scope here.

Q: AppleScript string escaping?
A: `OsNotifier.escape` escapes backslashes before quotes (order matters —
escaping quotes first would double-escape the backslash the quote-escape
itself introduces... no wait, it's escaping backslashes first so a
literal `\` in a title/message doesn't get consumed as an AppleScript
escape character, or land the string in a state where a trailing
backslash swallows the closing quote).

## WSL2

Q: This app's dev machine runs WSL2 under Windows. Does `macos?` cover it?
A: No — Ruby inside WSL2 reports `host_os` as plain `linux`, same as any
other Linux. The only WSL signal is the kernel string in `/proc/version`
(`OsNotifier.wsl?` matches `/microsoft/i` there).

Q: What pops the toast on Windows?
A: `powershell.exe` — reachable from WSL via interop, no install needed on
the WSL side. Uses `System.Windows.Forms.NotifyIcon#ShowBalloonTip`, which
ships with .NET already on Windows — a real modern-toast library
(`BurntToast`) would need the user to `Install-Module BurntToast` on the
Windows side first, which this app can't silently ensure, so the balloon
tip (visually older-style, but zero setup) is the fallback that actually
works out of the box. Verified live in-session: the balloon rendered.

Q: Escaping?
A: PowerShell single-quoted strings escape by doubling `'` → `''`
(`escape_powershell`); different rule from AppleScript's `"`/`\\`
handling, so it's a separate method, not a shared `escape`.

Q: The PowerShell script does `Start-Sleep -Seconds 6` before disposing
the tray icon (so the balloon has time to render) — doesn't that block?
A: Caught in code review: `notify_wsl` originally used `Open3.capture3`,
which waits for the subprocess to exit — so the 6-second sleep blocked
the calling thread. Since `OsNotifier.notify` runs synchronously inside
`OsNotificationsController#create`, that tied up a Puma worker thread per
notification; three or more due tasks in one poll cycle could exhaust the
default thread pool. Fixed by spawning detached instead
(`Process.spawn` + `Process.detach`), so the request returns immediately
and the sleep only holds the detached subprocess open.

## Testing

- `spec/models/os_notifier_spec.rb`: OS detection (stubbed
  `RbConfig::CONFIG`), shells out only on macOS, quote/backslash escaping.
- `spec/requests/os_notifications_spec.rb`: controller delegates params to
  `OsNotifier.notify`.
- No JS spec — suite is `rack_test` only (see `q-shortcut-design.md`,
  `esc-shortcut-design.md`); `notifyOs`'s fetch call isn't exercised.
