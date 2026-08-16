# Slice 6 — Client-side due notifications (in-page toasts) — Implementation Plan

Goal: When a task crosses its `due_at` while the app is open, show an
in-page toast. Pure client-side: a JS module polls a lightweight JSON
endpoint; the server only answers a query. No OS notification, no macOS
`terminal-notifier`/`osascript`, **no Active Job, no Solid Queue, no
recurring poller, no `notified_at` column** — the original design's entire
server-side scheduler is superseded (user decision 2026-08-15; the app
runs on WSL2 Linux or macOS — no OS-coupled notification).

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
- **Mount + script persist across Turbo navigations:** Turbo Drive swaps the
  whole `<body>` on each soft visit, so placement alone does not survive.
  Mark the container `<div id="toast-container" data-turbo-permanent …>` —
  Turbo carries the permanent node (and in-flight toasts) across visits by
  matching `id`, so keep the same `id` in the layout. The module (its
  `<script>` lives in `<head>`, not re-run by Drive) stays active, and
  re-resolves `container` via `getElementById` each poll; guarded so
  Turbo-driven restores never double-start its interval.
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
- `app/models/task.rb`: no change needed — the due query stays inline in the
  controller (single-use; a `Task.due_since` scope would be dead code).
- `app/controllers/tasks_controller.rb`: add
  ```ruby
  def due_since
    since = Time.iso8601(params[:since])
    now = Time.current
    tasks = Task.where(all_day: false)
      .where("due_at > ? AND due_at <= ?", since, now)
      .order(:due_at)
    render json: {
      now: now.utc.iso8601,
      tasks: tasks.pluck(:id, :title, :due_at).map { |id, title, due| { id: id, title: title, due_at: due&.utc.iso8601 } }
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
    `let inFlight = false` (poll concurrency guard), `let container = null`,
    `let wasHidden = document.hidden` (visibility edge latch).
  - `ensureContainer()` resolves `document.getElementById("toast-container")`,
    creating it under `document.body` only if absent, and always re-assigns
    `container` — so it tracks the live node across Turbo body swaps.
  - `poll({ silent = false })`: guard with `inFlight` — if a previous poll is
    still awaiting, return immediately; set `inFlight = true` at entry and
    clear it in a `finally` (an overlapping `setInterval` tick or a resume
    silent poll cannot overlap an in-flight request). URL is built with
    `'/tasks/due_since.json?since=' + encodeURIComponent(new
    Date(anchor).toISOString())` so the query value is always safely
    encoded. The whole async body
    is wrapped in try/catch so a `fetch` rejection (network/DNS) or
    `response.json()` parse throw logs and returns — no unhandled promise
    rejection escapes, and the anchor is untouched. On `ok`: unless
    `silent`, toast each of `payload.tasks` first (per-item try/catch so one
    bad render logs and continues, never aborts the batch); then advance the
    anchor to server time — `anchor = Date.parse(payload.now)` — with no
    monotonic comparison: the `inFlight` guard already serializes polls, so
    an out-of-order completion cannot occur; and a one-way guard would pin
    `anchor` above the server clock whenever the client runs ahead (any
    client/server clock skew: `anchor` starts at the browser's `Date.now()`,
    which can sit
    above the Rails server's clock, making the endpoint's `due_at > since`
    window empty and silently disabling every toast). Toasting before
    advancing keeps a render error from consuming never-toasted tasks. On non-ok,
    leave the anchor (no widen-the-gap) and return. A silent poll advances
    the anchor but never toasts. `poll()` calls `ensureContainer()` at
    entry — the container exists before any toast appends.
  - `toast(task)`: build a Bulma `.notification` div with the task title,
    close (delete) button; append to container; `setTimeout` remove ~8s.
    Navigation: a click listener on the `.notification` element itself
    (`click` → `Turbo.visit('/tasks/' + id + '/edit')` for the soft nav —
    there is no bare `visit` global; Turbo's API is `Turbo.visit(url)`).
    Do **not** wrap the notification
    in `<a href>` — `stopPropagation()` cancels bubbling to ancestor
    *listeners*, not an enclosing anchor's default navigation, so an `<a>`
    body would navigate even when the close button is clicked. The `.delete`
    close handler calls `event.stopPropagation()` before `remove()` so its
    click does not bubble to the navigation listener.
    `toast()` re-resolves `container` via `ensureContainer()` first, so an
    append never hits a `null` container.
  - `document.visibilitychange` → fire the silent resume poll **only on the
    hidden→visible edge**: `if (wasHidden && !document.hidden)
    poll({ silent: true });` then set `wasHidden = document.hidden` on every
    event. This fires one silent poll per resume (advancing the anchor to
    resume-time, no toasts) and never fires on visible→hidden or repeated
    visible events. Not a flag for the next interval tick, so a task that
    comes due between resume and the next tick still toasts. If the silent
    poll fires while a regular poll is still in flight, the `inFlight` guard
    drops it and that poll resolves normally — the anchor still advances and
    the hidden gap toasts once: bounded to at most one stray toast, never a
    burst.
  - Start: attach on `DOMContentLoaded` and the Turbo `turbo:load` event,
    guarded by `started` (module-level instance + one `setInterval`).
- `app/views/layouts/application.html.erb`: add the toast container in
  `<body>`, marked permanent so Turbo carries it (and any in-flight toasts)
  across visits:
  `<div id="toast-container" data-turbo-permanent aria-live="polite"></div>`.
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
- Confirm the resume's immediate silent poll advances `anchor` to server
  `now` without toasting (tasks that came due while the tab was hidden are
  not spammed), and a task due after resume toasts on the next regular tick.
  Edge: if a regular poll is in flight at the resume moment, the `inFlight`
  guard drops the silent poll and that poll advances the anchor instead
  (toasting the hidden gap once — see the Step-2 visibilitychange note);
  the common path above is what the resume check should confirm.
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
    `poll({ silent: true })` resume path in code + a manual tab-switch check.)

## Done when

- A task crossing its `due_at` while the page is open shows one in-page
  toast (auto-dismiss, closeable, click → edit).
- Tasks already overdue when the page loads do **not** toast.
- `all_day` tasks never toast.
- `<toast-container>` + poller survive Turbo soft-nav; interval starts once.
- No job stack exists: no Active Job / Solid Queue / recurring job /
  `notified_at`; `db/schema.rb` untouched by this slice.
- Full suite green, Rubocop clean.

## Doc changes already applied (commit cad2af3, this branch)

All doc edits this slice introduces were committed alongside this plan;
none remain as pending action.

- **design.md** — Slice 6 rewritten (client-side toasts, no job stack); Task
  Domain drops `notified_at` and reflects `CompletedOccurrence` + one-off
  destruction (slice-5 follow-up); Deferred/Open questions updated.
- **README.md** — "Slice 6 adds Active Job plus Solid Queue for reminders"
  replaced with the client-side toast description.
- **specs/estimates.md** — slice 6 medium→small; rework R4 void (there is no
  `completed_at` after slice 5); conflict C1 no longer includes slice 6 (no
  column added).
- **specs/tech.md, specs/todo-app-grill.md** — stale job-stack claims
  corrected.
- **specs/slice-1-plan.md, slice-2-plan.md, slice-5-plan.md** — stale
  `notified_at` forward-references corrected in the review pass (working
  tree, not in cad2af3 — land with this branch's commit).
- **Grill log:** `~/tmp/2026-08-15-slice-6-grill.md`.

If implementing on a fresh checkout, `git show cad2af3` confirms these edits —
do not re-apply them.