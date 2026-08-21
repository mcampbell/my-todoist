# OS-level toast for due tasks (macOS)

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

## Testing

- `spec/models/os_notifier_spec.rb`: OS detection (stubbed
  `RbConfig::CONFIG`), shells out only on macOS, quote/backslash escaping.
- `spec/requests/os_notifications_spec.rb`: controller delegates params to
  `OsNotifier.notify`.
- No JS spec — suite is `rack_test` only (see `q-shortcut-design.md`,
  `esc-shortcut-design.md`); `notifyOs`'s fetch call isn't exercised.
