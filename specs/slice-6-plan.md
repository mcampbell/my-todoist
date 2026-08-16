# Slice 6 — Client-side due notifications (in-page toasts) — Implementation Plan

Goal: When a task crosses its `due_at` while the app is open, show an
in-page toast. Pure client-side: a JS module polls a lightweight JSON
endpoint; the server only answers a query. No OS notification, no macOS
`terminal-notifier`/`osascript`, **no Active Job, no Solid Queue, no
recurring poller, no `notified_at` column** — the original design's entire
server-side scheduler is superseded (user decision 2026-08-15; host is WSL2
Linux, not macOS).

The app must **not** toast tasks already overdue when the page opens
(Today/Overdue show them) — the poll's `since` anchor handles this
(`due_at > anchor`). A backgrounded tab that resumes must not dump a toast
burst for tasks that came due while hidden (suppress-on-resume).

Source: `specs/design.md` (Slice 6), grill session `~/tmp/2026-08-15-slice-6-grill.md`. Branch off `main` (slice 5 merged). Tests interleaved per step. Runner: `bin/rspec`.

## Grill session (2026-08-15)

Full log: `~/tmp/2026-08-15-slice-6-grill.md`. Summary:

| # | Question | Answer |
|---|----------|--------|
| 1 | Backend: replace Solid Queue + recurring poller + terminal-notifier entirely? | Drop job stack entirely; pure client-side poll + toasts; no `notified_at`. |
| 2 | Backgrounded-tab resume backlog of toasts? | Suppress on-resume: advance the anchor silently, don't toast the hidden gap. |
| 3 | Mobile LAN access is required? | Desktop-first; mobile = nice-to-have (toasts identical if reachable); no bind/hardening now. |

## Locked decisions

- **One thin slice, no sub-slicing** — a single deployable feature. Order:
  backend endpoint → JS module + toast mount → anchor/suppression behavior →
  suite + browser smoke.
- **Poll source of truth is client clock only at first**, then server time:
  the endpoint returns a server `now`; the client advances its `since`
  anchor to `response.now` each poll so client/server clock skew can't cause
  a missed or duplicate task.
- **Endpoint** `GET /tasks/due_since.json?since=<ISO8601 UTC>` returns
  `{ "now": <server now ISO8601>, "tasks": [{ "id", "title", "due_at" }] }`
  for tasks `due_at > since AND due_at <= now AND all_day == false`.
  No completed filter: `Task#complete!` destroys one-off rows and advances
  recurring ones, so every row in `tasks` is inherently active (slice-5
  model; the old design's `completed_at IS NULL` clause is dead —
  the column doesn't exist).
- **`all_day` tasks skipped** (design-note rule, carried over): no time to
  fire a notification at.
- **Anchor = page load time.** Hard refresh resets it → a fresh "page opens"
  never toasts tasks already overdue (they're visible on Today/Overdue, and
  the endpoint's `due_at > anchor` filter excludes them anyway).
- **Dedup = per-session client anchor**, not a DB column. Each task toasts
  once per page session; each open tab/device anchors independently (toasting
  on every open device is accepted, even desired). No cross-device dedup —
  a conscious scope cut (mobile nicety; single-user local app).
- **Suppress-on-resume:** track `document.hidden`; on `visibilitychange` to
  visible after a hidden period, run one silent poll that advances the anchor
  without toasting, then resume normal toasts. Honors "don't notify on
  overdue you're being shown."
- **Mount + script persist across Turbo navigations:** the toast container
  and `<script>` live in `application.html.erb` `<body>` outside `<%= yield
  %>`, so Turbo soft-nav never tears them down and the poller keeps running
  + anchor keeps advancing across views. The JS module is guarded so
  Turbo-driven restores don't double-start its interval.
- **Toast UX:** fixed top-right stack, Bulma `notification`, auto-dismiss
  ~8s + manual close, click navigates to the task edit page. Default poll
  interval **30s**.
- **Blank/parse-failed `since`** → `400`, and the client does *not* advance
  its anchor on a non-200 (stops the risk of silently widening the gap).
- **Mobile follow-up, not in this slice:** reachability (bind 0.0.0.0 + WSL2
  Windows port-forward). Code is identical — a pure `fetch` poll over HTTP,
  no WebSockets — so it works on mobile Chrome the moment the phone can reach
  the server.

## Step 1 — Backend endpoint + tests

- `config/routes.rb`: inside `resources :tasks` collection,
  `get :due_since`.
- `app/models/task.rb`: add scope
  `scope :due_since, ->(since) { where(all_day: false).where("due_at > ? AND due_at <= ?", since, Time.current) }`
  (or a `where` chain inline in the action — one line, no need for a scope
  if it stays single-use; prefer the inline query, YAGNI).
- `app/controllers/tasks_controller.rb`: add
  ```ruby
  def due_since
    since = Time.iso8601(params[:since])
    tasks = Task.where(all_day: false)
      .where("due_at > ? AND due_at <= ?", since, Time.current)
      .order(:due_at)
    render json: {
      now: Time.current.iso8601,
      tasks: tasks.pluck(:id, :title, :due_at).map { |id, title, due| { id: id, title: title, due_at: due&.iso8601 } }
    }
  rescue ArgumentError, TypeError
    render json: { error: "since must be ISO8601" }, status: :bad_request
  end
  ```
- No `notified_at` migration. Verify `db/schema.rb` is untouched.
- Tests (`spec/requests/tasks_spec.rb`):
  - returns a task whose `due_at` is `> since` and `<= now`, with
    `all_day: false`; body carries `id/title/due_at` and a `now` field.
  - excludes an `all_day` task that is technically due (no time to fire).
  - excludes a task with `due_at <= since` (already-overdue-at-load case).
  - excludes a task due in the future (`due_at > now`).
  - `400` with an unparseable `since`.

## Step 2 — Toast mount + JS module + importmap

- `config/importmap.rb`: `pin "notifications"`.
- `app/javascript/application.js`: add `import "notifications"`.
- `app/javascript/notifications.js`:
  - Module-scope: `let anchor = Date.now()`, `const INTERVAL = 30_000`,
    `let started = false` (idempotency guard against Turbo cache restore),
    `let suppressed = false`, `let container = null`.
  - `ensureContainer()` lazily creates `<div id="toast-container">` under
    `document.body` if absent (defensive — normally rendered in layout).
  - `poll()`: `fetch(/tasks/due_since.json?since=AISO8601(anchor))`; on
    `ok`, set `anchor = payload.now`; if not `suppressed`, `payload.tasks`
    → toast each; clear `suppressed` after. On non-ok, leave anchor (no
    widen-the-gap) and just return.
  - `toast(task)`: build a Bulma `.notification` div with the task title,
    close (delete) button; append to container; `setTimeout` remove ~8s;
    click on the body navigates to `/tasks/<id>/edit`.
  - `document.visibilitychange` → when `document.hidden` becomes false
    (and was previously true), set `suppressed = true` for the next poll.
  - Start: attach on `DOMContentLoaded` and the Turbo `turbo:load` event,
    guarded by `started` (module-level instance + one `setInterval`).
- `app/views/layouts/application.html.erb`: add the toast container in
  `<body>` (outside `<%= yield %>`), e.g.
  `<div id="toast-container" aria-live="polite"></div>`.
- `app/assets/stylesheets/application.css`: `#toast-container { position:
  fixed; top: 1rem; right: 1rem; z-index: 1000; display: flex;
  flex-direction: column; gap: 0.5rem; min-width: 16rem; max-width: 22rem;
  }`.
- No JS unit tests (plain DOM module, not framework-bound); behavior covered
  by the Step-4 browser smoke.

## Step 3 — Anchor/suppression edge behaviors (refinements to Step 2)

- Confirm on a hard page load the anchor is `Date.now()` at module init (so
  already-overdue items never toast even while the Today list renders them).
- Confirm Turbo soft-navigation does **not** reset the anchor (module
  persists) and does **not** double-start the interval.
- Confirm `suppressed` catches the resume case: a poll that fires after the
  tab comes back advances `anchor` to server `now` without toasting.
- Confirm a task that becomes due while the page is visible and stationary
  toasts exactly once (anchor advanced per poll → the same task fails
  `due_at > anchor` on the next poll).

## Step 4 — Full suite + smoke

- `bin/rspec` green, full suite.
- Rubocop clean.
- Browser smoke (drive the real app at `localhost:3000`):
  - Open a page, note no toasts for the currently-due/overdue tasks shown.
  - Create a task due ~30s out (future), leave the page open, confirm a
    toast appears when it crosses `due_at`, once; confirm auto-dismiss and
    the close button.
  - Confirm click navigates to the task's edit page.
  - Confirm the toast container and poller persist across a Today ⟷ Inbox
    Turbo navigation.
  - Confirm an `all_day` task due today neither times out nor toasts.
  - (Background-tab resume is hard to automate in a smoke; verify the
    `suppressed` flag logic in code + a manual tab-switch check.)

## Done when

- A task crossing its `due_at` while the page is open shows one in-page
  toast (auto-dismiss, closeable, click → edit).
- Tasks already overdue when the page loads do **not** toast.
- `all_day` tasks never toast.
- `<toast-container>` + poller survive Turbo soft-nav; interval starts once.
- No job stack exists: no Active Job / Solid Queue / recurring job /
  `notified_at`; `db/schema.rb` untouched by this slice.
- Full suite green, Rubocop clean.

## Rework / design-doc cost this slice imposes

- **design.md**: Slice 6 section rewritten (client-side toasts, no job
  stack); Task Domain drops `notified_at`; Deferred entry updates
  ("macOS-only in-app notification" → shipped as in-page toasts; email still
  deferred); Open question about `terminal-notifier` resolves (not needed).
- **design.md Domain** (pre-existing, from slice 5, not done yet): the
  "single mutable Task row" sentence + `completed_at` field are stale —
  `CompletedOccurrence` exists and `Task#complete!` destroys one-offs. Update
  while editing the Domain section for `notified_at`.
- **README.md**: "Slice 6 adds Active Job plus Solid Queue for reminders"
  is now false → replace with the client-side toast description.
- **specs/estimates.md**: slice 6 size medium→small (no job stack, no
  column); rework R4 (`drop completed_at IS NULL`, slice 5→6) is void —
  remove; conflict C1 no longer includes slice 6 (it adds no column).