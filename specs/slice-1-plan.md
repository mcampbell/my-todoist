# Slice 1 — Walking Skeleton — Implementation Plan

Goal: ship a usable flat todo list. Create/edit a task, list active tasks,
mark complete (soft), view completed history. No NLP, no recurrence, no
notifications. One implicit Inbox.

Source: `specs/design.md` (Slice 1), `specs/todo-app-grill.md`.
Tests interleaved per step. Test runner: `bin/rspec`.

## Step 0 — Generate app

- `rails new . --database=sqlite3 --skip-test` inside `~/dev/my-todoist`
  (repo already git-init'd; `rails new .` into existing dir).
  - `--skip-test` drops Minitest. **No `--css=bulma`** — that flag pulls
    `cssbundling-rails` → Node/esbuild, which contradicts the no-Node decision.
  - Vendor Bulma (pure Propshaft, no Node): download `bulma.min.css` into
    `app/assets/stylesheets/`. Load it via `stylesheet_link_tag` in the layout
    (Step 5) — **NOT** `*= require bulma`. `*= require` is a Sprockets
    directive; Rails 8 uses Propshaft, which has no directive processor and
    silently ignores the `*=` comment, so Bulma would never load.
- `bin/dev`: importmap-only + vendored CSS generates **no** `Procfile.dev` /
  `bin/dev` (no asset watcher to run). Either hand-write a one-line
  `Procfile.dev` (`web: bin/rails server`) or just boot with `bin/rails server`.
- Smoke check `root 200` belongs **after** Step 3 sets `root to: "tasks#index"`
  — before that it only tests the Rails welcome page. Here, just confirm the
  server boots.

## Step 1 — RSpec setup

- Add to Gemfile `:development, :test`: `rspec-rails`.
- `bundle install` then `rails g rspec:install`.
- Test: `bin/rspec` runs green (0 examples).

## Step 2 — Task model + migration

- `rails g model Task title:string notes:text due_at:datetime completed_at:datetime`
- Migrate.
- Model rules: `validates :title, presence: true`.
- Scopes: `scope :active, -> { where(completed_at: nil) }`,
  `scope :completed, -> { where.not(completed_at: nil) }`.
- Instance: `#complete!` idempotent — `return if completed?` then set
  `completed_at: Time.current`, persist. A repeat PATCH must preserve the
  original timestamp (unconditional set corrupts history order).
  `#completed?` => `completed_at.present?`.

**Tests** (`spec/models/task_spec.rb`):

- invalid without title.
- `active`/`completed` scopes partition rows.
- `complete!` sets completed_at + flips `completed?`.
- `complete!` twice keeps the first `completed_at` (idempotent).
- `bin/rspec spec/models/task_spec.rb` green.

## Step 3 — Tasks CRUD (structured form)

- `resources :tasks, except: [:show]`; root -> `tasks#index`. No `show` action,
  so drop the dead route (also removes any clash with `GET /tasks/completed`).
- `TasksController`: index, new, create, edit, update, destroy.
- Index order (SQLite puts NULLs first by default — `order(due_at: :asc)` is
  wrong): `order(Arel.sql("due_at ASC NULLS LAST, created_at DESC"))`.
- Strong params: `title, notes, due_at`.
- Views (ERB + Bulma): index list, `_form` partial, new, edit.
  - `_form`: title, **notes textarea** (permitted but was unreachable),
    `due_at` via native `<input type="datetime-local">` (no picker lib).
  - Each task row: title, due_at (if set), Complete button, Edit, Delete.
- `create`/`update` redirect to index on success; on invalid re-render
  `:new`/`:edit` with `status: :unprocessable_entity` (fail loud; plain 200
  re-render breaks Turbo form replacement).

**Tests** (`spec/requests/tasks_spec.rb`):

- GET /tasks 200, shows active task titles.
- GET /tasks/new 200. GET /tasks/:id/edit 200, form pre-filled with current
  title/notes/due_at.
- **Index ordering** (locks the `Arel.sql("due_at ASC NULLS LAST, created_at
  DESC")` claim — the whole reason the plan rejects `order(due_at: :asc)`):
  seed 3 rows — due tomorrow, due today, no due_at — plus two same-due rows
  created at different times. Assert render order: earliest due first, NULL
  due_at last, `created_at DESC` breaking ties. Without this test the SQLite
  NULL-first regression ships silently.
- POST valid params creates row + redirects. **Assert `notes` persisted** (it
  was the permitted-but-unreachable field — a blank textarea in the form would
  pass every other test).
- POST invalid (blank title) re-renders **422**, no row created.
- PATCH valid updates; PATCH invalid re-renders **422**, no change.
- DELETE removes.
- `bin/rspec spec/requests/tasks_spec.rb` green.

## Step 4 — Layout / nav shell (before history so the Completed link exists)

- `app/views/layouts/_navbar.html.erb`: Bulma navbar. Links: Tasks (root),
  Completed, New task. **Extract as a partial now** — design's merge-conflict
  note says slices 2 (sidebar) and 3 (Today/Upcoming links) both edit nav;
  a partial keeps those edits off `application.html.erb`.
- `layouts/application.html.erb`: `<%= stylesheet_link_tag "bulma",
  "application" %>` in head, container wrapper for yield, `render "layouts/navbar"`,
  flash messages as Bulma notifications.

**Test** (`spec/requests/navigation_spec.rb`):

- root renders navbar with Tasks + Completed links. `bin/rspec` green.

## Step 5 — Complete + history

- Route: `PATCH /tasks/:id/complete` -> `tasks#complete` (member route).
- Action calls `task.complete!`, redirect back to index.
- Index shows only `Task.active`.
- History: `GET /tasks/completed` (collection) -> lists `Task.completed`
  ordered by completed_at desc. Nav link already in place from Step 4.

**Tests** (append `spec/requests/tasks_spec.rb`):

- PATCH complete moves task out of index into completed view; redirects to
  index (302).
- completed page lists completed titles, hides active.
- **Completed ordering**: seed two completed rows with different
  `completed_at`; assert most-recently-completed first (locks the
  `completed_at desc` claim).
- `bin/rspec` green.

**One system spec** (`spec/system/task_flow_spec.rb`) — the only browser-level
coverage worth the driver cost in Slice 1 (no other JS): prove the Turbo-wired
Complete and Delete buttons (`button_to` / `data-turbo-method`) actually issue
PATCH/DELETE — request specs call the verbs directly and never prove the button
wiring. Skip system specs for create/edit/list (request specs cover them).

## Step 6 — Full suite + smoke

- `bin/rspec` whole suite green.
- Manual smoke via `bin/rails server` (or `bin/dev` if a `Procfile.dev` was
  added in Step 0): create task, complete it, see it in history, edit a task
  (edited title persists), delete a task (absent afterward).

## Done when

- Create / list / edit / delete / complete / history all work in browser.
- Full RSpec suite green.
- No NLP, recurrence, projects, or notifications present (later slices).

## Schema left extensible for later slices

`tasks` will later gain `project_id`, `priority`, `recurrence` (design C1);
`notified_at` was in C1 but is dropped — slice 6 ships client-side toasts
with no column. Don't pre-add — additive migrations land per slice.
