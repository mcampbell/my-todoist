# Browser notification + mute design

Goal: due-task alerts work when the server runs in the cloud. The browser
shows the OS toast and plays the sound, not the server. A Mute button on the
task lists silences them per browser.

Sliced: 2 slices. Run S1, then S2 (or in parallel; see C1).

## User decisions (2026-10-19)

- Mute silences the sound and the OS toast. The in-page toast still shows.
- The mute setting lives in this browser only (`localStorage`). No server,
  DB, or migration change.
- The Mute button shows on the task lists only: Inbox/project, Today,
  Overdue, Upcoming. Not on Search, Completed, completed-task details, or
  the New/Edit forms.
- Delete the server OS-notification code. Redo it later if needed.

## S1 - Browser notification replaces OsNotifier

Value: an OS-level toast on the device you look at, from any server.

- Delete `app/models/os_notifier.rb`, `app/controllers/os_notifications_controller.rb`,
  the `resource :os_notification` route, `spec/models/os_notifier_spec.rb`,
  `spec/requests/os_notifications_spec.rb`, and the OsNotifier example in
  `spec/requests/authentication_spec.rb`.
- `notifications.js`: replace `notifyOs` (fetch POST) with
  `new Notification("Task due", { body: task.title })`, only when
  `Notification.permission === "granted"`. Skip when the API is missing.
  The OS plays its own notification sound; the Web Audio `beep()` stays for
  the in-page toast.
- Ask permission on the first click on any page while permission is
  `"default"` (`{ once: true }` listener). Safari and Firefox ask only from a
  user gesture, so page load cannot ask.
- Tests: a request spec that `POST /os_notification` routes nowhere (404).
  The JS stays untested: no JS test driver
  (`.okf/decisions/no-js-test-driver.md`). Check it by hand in a browser.

## S2 - Mute toggle

Value: silence the sound and the OS toast, per browser, from any task list.

- `tasks/_page_header.html.erb`: render
  `<button type="button" data-mute-toggle aria-pressed="false">Mute</button>`
  when the caller passes `mute_toggle: true`. index, today, overdue, and
  upcoming pass it. Opt-in, so a new view gets no button by accident.
- `notifications.js`: `muted()` reads `localStorage["notifications-muted"]`
  inside try/catch (private windows can throw; read failure = not muted).
  `toast()` skips `beep()` and the `Notification` when muted. One delegated
  `click` listener on `document` for `[data-mute-toggle]` flips the flag.
  On `turbo:load` it sets the label ("Mute"/"Unmute") and `aria-pressed`.
  An unmute click also asks notification permission (it is a user gesture).
  The S1 first-click ask and the mute toggle share one click handler, so
  the toggle runs first and a Mute click never prompts.
- Tests: request specs - the button renders on the 4 list views, and not
  on Search, Completed, or completed-task details. JS untested, as in S1.

## Conflicts and rework

- C1: S1 and S2 both edit `toast()` in `notifications.js`. In parallel, the
  second merge resolves one small conflict. Run in order to avoid it.
- No rework: S2 keeps S1's first-click permission ask.

## Decisions

- No new dependency, no service worker. A tab must be open for alerts, as
  now (the poll is in-page).
- Keep `beep()`: the OS sound depends on OS settings; the beep is the sound
  you control.
- Leave the history docs (`specs/os-notification-design.md`, `design/*`,
  `.okf/`) as they are. The okf workflow updates `.okf/` (user call).

## Tasks

- [x] S1 branch `browser-notification` (S2 lands on it too, as its own commit)
- [x] S1 red: `POST /os_notification` is 404
- [x] S1 green: delete server code + specs; `Notification` in notifications.js
- [x] S1 `bin/rspec`, `bin/rubocop`; code-reviewer; commit
- [x] S2 red: Mute button on 4 list views, absent on 3 others
- [x] S2 green: page header + notifications.js mute
- [x] S2 `bin/rspec`, `bin/rubocop`; code-reviewer; commit
- [ ] Hand check in a browser: permission prompt, OS toast, beep, mute
