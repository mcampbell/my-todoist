# Slice 2 — Organization (projects, labels, priority) — Implementation Plan

Goal: add projects, labels, and priority to tasks. Project + Label CRUD.
Bulma sidebar nav (Inbox + project list). Inbox and per-project task views.
Priority badge + label tags on task rows. No NLP, recurrence, notifications,
or date views (later slices).

Source: `specs/design.md` (Slice 2), `specs/todo-app-grill.md` (Q4).
Branch off `main` (slice 1 merged). Tests interleaved per step.
Runner: `bin/rspec`. Carry slice-1 gotchas forward:
`status: :unprocessable_content` (NOT `:unprocessable_entity` — deprecated in
Rack) and SQLite `NULLS LAST` ordering (SQLite sorts NULLs first by default).

## Locked decisions (resolve the design's underspecified bits)

- **Inbox = `tasks.project_id IS NULL`.** No Inbox row (design C-note). Root
  `tasks#index` now scopes to nil-project active tasks. This is a **behavior
  change** vs slice 1 (was "all active"). Slice-1 request specs stay green —
  their fixtures have no project, so nil → still Inbox.
- **priority = raw integer `0..3`**, column `null: false, default: 0`. `3` =
  most urgent. Guarded by `validates :priority, inclusion: { in: 0..3 }` **and**
  a DB check constraint. **No Rails enum** — an enum invents a third vocabulary
  (`none/low/medium/high`) that matches neither the design (`0..3`) nor
  Todoist's `p1..p4`, so slice 4's quick-add parser would map `p1 → high → 3`
  instead of `p1 → 3`. Display names come from a helper, not the schema.
- **P0 renders no badge.** Baseline (unprioritized) is the common case; a tag
  on every row is noise. Badge only for 1..3 (Todoist behavior).
- **Per-project view = nested route reusing `tasks#index`.** No
  `ProjectsController#show`. One action + one view serve Inbox *and* project
  (branch on `params[:project_id]`), and is the natural seam for slice 3's
  Today/Upcoming. This is what makes the redirect helper (below) clean.
- **`task_list_path(task)` redirect helper.** After create/update/complete,
  and on the form Cancel link, return to the task's *own* list
  (`project_tasks_path(task.project)` or `tasks_path`), never always-Inbox.
  Without it, completing a task inside a project bounces you to Inbox — a
  daily papercut.
- **Project delete → nullify.** DB FK `on_delete: :nullify` **plus** model
  `dependent: :nullify`. Tasks fall back to Inbox, never deleted (belt-and-
  suspenders: console/SQL deletes also fall back).
- **No per-label view** (Q6 lists only Today/Upcoming/Inbox/Per-project).
  Labels are assign + display (+ later filter). `resources :labels, except: :show`.
- **No task-row partial yet, no navbar rename.** Under the shared-`index`
  routing there is exactly one row template — nothing to de-duplicate, so
  extracting `tasks/_task.html.erb` is premature; do it in slice 3 when the
  date-grouped views become a second, structurally-different consumer. Keep the
  filename `layouts/_navbar.html.erb` (design C-note names it as the shared nav
  seam for slices 2+3); put the sidebar markup **inside** it.

> Debate note: two partners converged here. The four decisions above marked as
> judgement calls (raw-int vs enum, nested-route vs `#show`, defer partial,
> keep `_navbar` name) were genuine near-ties — both are defensible; the plan
> takes the lower-churn / fewer-files side of each. If a reader prefers the
> conventional `ProjectsController#show`, it is a safe substitution, but then
> the redirect helper and slice-3 reuse cost slightly more.

## Step 0 — Branch + migration order

- `git checkout main && git pull && git checkout -b slice-2-organization`.
- Four migrations, generated **in this order** so FK targets exist first and
  timestamps serialize (design merge-conflict note 1):
  1. `CreateProjects`
  2. `CreateLabels`
  3. `AddOrganizationToTasks` (project_id + priority, one file)
  4. `CreateTaskLabels`
- **Highest-risk line in the slice:** Rails 8 makes `belongs_to` required by
  default, so nil-project (Inbox) tasks fail validation unless
  `belongs_to :project, optional: true`. Gets an explicit test (Step 2).

## Step 1 — Project + Label models (+ join)

Migrations:

```ruby
# CreateProjects
create_table :projects do |t|
  t.string :name, null: false
  t.timestamps
end
add_index :projects, :name, unique: true

# CreateLabels — same shape as projects

# CreateTaskLabels (generated AFTER AddOrganizationToTasks so its timestamp is later)
create_table :task_labels do |t|
  t.references :task,  null: false, foreign_key: true
  t.references :label, null: false, foreign_key: true
  t.timestamps
end
add_index :task_labels, [:task_id, :label_id], unique: true
```

Models:

```ruby
class Project < ApplicationRecord
  has_many :tasks, dependent: :nullify
  validates :name, presence: true, uniqueness: true
end

class Label < ApplicationRecord
  has_many :task_labels, dependent: :destroy
  has_many :tasks, through: :task_labels
  validates :name, presence: true, uniqueness: true
end

class TaskLabel < ApplicationRecord
  belongs_to :task
  belongs_to :label
  validates :label_id, uniqueness: { scope: :task_id }  # model echo of the DB unique index
end
```

**Tests** (`spec/models/project_spec.rb`, `spec/models/label_spec.rb`):

- Project invalid without name; invalid on duplicate name.
- Label invalid without name; invalid on duplicate name.
- Deleting a Project with tasks **nullifies** `task.project_id` (task
  survives → lands in Inbox) — locks `dependent: :nullify`.
- Deleting a Label removes its `task_labels` rows but **not** the tasks.
- `bin/rspec spec/models/project_spec.rb spec/models/label_spec.rb`

## Step 2 — Task associations + priority + ordered scope

Migration `AddOrganizationToTasks`:

```ruby
add_reference :tasks, :project, null: true, foreign_key: { on_delete: :nullify }
add_column :tasks, :priority, :integer, null: false, default: 0
add_check_constraint :tasks, "priority BETWEEN 0 AND 3", name: "priority_range"
```

Task model (expect a merge here in slices 5/6 — they add columns too):

```ruby
belongs_to :project, optional: true          # Rails 8: without this, EVERY Inbox task fails to save
has_many :task_labels, dependent: :destroy
has_many :labels, through: :task_labels
validates :priority, inclusion: { in: 0..3 }
scope :ordered, -> { order(Arel.sql("due_at ASC NULLS LAST, created_at DESC")) }
```

- **Extract `:ordered` now.** Inbox view, project view, and slice-3
  Today/Upcoming all reuse the same NULLS-LAST clause — one scope kills three
  copies of the Arel string. Slice-1 `tasks#index` switches to
  `Task.active.where(project: @project).ordered` (a separate `:inbox` scope is
  redundant — `where(project: nil)` reads as `project_id IS NULL`).

**Tests** (append `spec/models/task_spec.rb`):

- Inbox task (nil project) is **valid** — proves `optional: true`.
- Task belongs to a Project; `project.tasks` returns it.
- Assigning `label_ids` associates labels; `task.labels` returns them.
- `priority: 5` **invalid**; `priority: -1` invalid; `0..3` valid; default 0.
- `Task.ordered` keeps the slice-1 NULLS-LAST + `created_at DESC` contract —
  re-assert with a projected task mixed in.
- `bin/rspec spec/models/task_spec.rb`

## Step 3 — Projects CRUD

- `resources :projects, except: :show` (per-project task view is a nested
  route, Step 6 — not `#show`).
- `ProjectsController`: index, new, create, edit, update, destroy.
  `before_action :set_project, only: %i[edit update destroy]`. Strong param
  `:name`. Invalid create/update re-render **`:unprocessable_content`**.
  Destroy → `projects_path` with flash (tasks nullified by the model).
- Views (Bulma): `projects/index` (table + New link + Edit/Delete, Delete via
  Turbo `button_to` with confirm), `_form`, `new`, `edit`.

**Tests** (`spec/requests/projects_spec.rb`):

- GET /projects 200 lists names; GET new/edit 200 pre-filled.
- POST valid → redirect; blank name → **422**, no row; **duplicate → 422**
  (locks the uniqueness index/validation).
- PATCH valid updates; PATCH invalid → **422**.
- DELETE removes project and **nullifies** its tasks' `project_id`
  (request-level proof of the model behavior).
- Missing project edit/update/destroy → 404.
- `bin/rspec spec/requests/projects_spec.rb`

## Step 4 — Labels CRUD

- `resources :labels, except: :show`. Same controller shape + 422 discipline.
- Views: `labels/index`, `_form`, `new`, `edit`.

**Tests** (`spec/requests/labels_spec.rb`):

- GET /labels 200 lists names.
- POST valid → redirect; blank → 422; duplicate → 422.
- PATCH valid/invalid.
- DELETE removes label + its `task_labels`; tasks survive.
- Missing label → 404.
- `bin/rspec spec/requests/labels_spec.rb`

## Step 5 — Task form gains project, priority, labels

`tasks/_form` additions (all native, no JS):

```erb
<%= f.collection_select :project_id, Project.order(:name), :id, :name,
      { include_blank: "Inbox" }, class: "select" %>
<%= f.select :priority, (0..3).map { ["P#{it}", it] } %>
<%= f.collection_check_boxes :label_ids, Label.order(:name), :id, :name %>
```

- `collection_check_boxes` (not a multi-select) — small label set, selections
  visible, no ctrl-click, easy to test. It emits a hidden empty field, so
  deselecting all clears labels.
- Cancel link → `task_list_path(@task)` (defined Step 6).
- Strong params:
  `params.require(:task).permit(:title, :notes, :due_at, :project_id, :priority, label_ids: [])`
  — `label_ids: []` **last** and array-typed or Rails drops it.

**Tests** (append `spec/requests/tasks_spec.rb`):

- POST with `project_id` → task appears under that project, **not** Inbox.
- POST `priority: 3` persists.
- POST `label_ids: [a, b]` associates both.
- POST blank `project_id` → Inbox (nil).
- PATCH changing project + priority + labels persists all three.
- **Empty checkbox submit clears labels** (locks the `label_ids: []` reset — a
  form that omits the key would silently keep stale labels).
- Edit form pre-selects current project/priority and **pre-checks** current
  labels.
- `bin/rspec spec/requests/tasks_spec.rb`

## Step 6 — Inbox + per-project views + return-to-list redirect

Routes:

```ruby
get "projects/:project_id/tasks", to: "tasks#index", as: :project_tasks
```

Controller:

```ruby
def index
  @project = Project.find(params[:project_id]) if params[:project_id]
  @tasks   = Task.active.where(project: @project).ordered   # nil → Inbox
end

private

def task_list_path(task)
  task.project ? project_tasks_path(task.project) : tasks_path
end
```

- `create`/`update`/`complete` redirect to `task_list_path(@task)` — use the
  saved task, not submitted params, so a newly-assigned project decides the
  destination.
- `index.html.erb` heading = `@project&.name || "Inbox"`.
- Rows render priority badge + label tags **inline** (no partial this slice):

```ruby
# TasksHelper
PRIORITY_TAG = { 1 => "is-info", 2 => "is-warning", 3 => "is-danger" }.freeze
def priority_badge(task)
  cls = PRIORITY_TAG[task.priority]           # 0 → nil → no badge
  cls && tag.span("P#{task.priority}", class: "tag #{cls}")
end
```

Labels inline: `task.labels.order(:name).map { tag.span(it.name, class: "tag is-light") }`.

**Tests** (append `spec/requests/tasks_spec.rb`):

- GET /tasks (Inbox) shows nil-project active tasks only; **hides** projected.
- GET /projects/:id/tasks shows that project's active tasks only; heading =
  project name; hides other projects' and Inbox tasks.
- P3 row renders `is-danger`; a **P0 row renders no `tag is-info/-warning/
  -danger`**.
- Each assigned label name renders.
- **Completing a project task redirects to `project_tasks_path`; completing an
  Inbox task redirects to `tasks_path`** (locks `task_list_path`).
- Both views hide completed tasks (still `Task.active`).
- Missing project → 404.
- `bin/rspec spec/requests/tasks_spec.rb`

## Step 7 — Bulma sidebar (inside `layouts/_navbar.html.erb`)

- `application.html.erb`: wrap body in Bulma columns — `columns` >
  `column is-narrow` (sidebar) + `column` (yield). Keep
  `stylesheet_link_tag "bulma.min", "application"` and flash notifications.
  On small viewports Bulma stacks the columns (no JS).
- `_navbar.html.erb` becomes a Bulma `menu`:
  - **Views** → Inbox (`root_path`), Completed (`completed_tasks_path`).
  - **Projects** → `Project.order(:name)` each → `project_tasks_path(p)`, plus
    Manage projects (`projects_path`), Manage labels (`labels_path`), New task.
- `ponytail:` sidebar re-queries `Project.order(:name)` per render — fine at
  single-user local scale; add a counter-cache only if a project list ever
  gets long.

**Tests** (update `spec/requests/navigation_spec.rb`):

- Root renders sidebar with Inbox + Completed links.
- Sidebar lists existing project names linking to `project_tasks_path`.
- Sidebar has Manage projects / Manage labels links.
- Bulma stylesheet still linked (keep the slice-1 assertion).
- `bin/rspec spec/requests/navigation_spec.rb`

**No new system spec.** Slice 2 adds no new Turbo/JS surface — Complete/Delete
`button_to` wiring is already proven by slice 1's `spec/system/task_flow_spec.rb`;
checkboxes and selects are plain form submits covered by request specs.

## Step 8 — Full suite + smoke

- `bin/rspec` whole suite green (slice-1 21 examples still pass).
- `rubocop` clean (autocorrect layout as in slice 1).
- Manual smoke via `bin/rails server`: create a project; create a label;
  create a task in the project with P3 + a label (badge + tag show on row);
  a no-project task shows only under Inbox; open the project view (only its
  tasks); **complete a project task → land back on that project, not Inbox**;
  rename the project; delete the project (its tasks reappear in Inbox); delete
  the label (task survives, tag gone).

## What to expect once this slice is deployed

**What changed:**

- **Root URL now shows Inbox** (nil-project active tasks), not "all active".
  Tasks assigned to a project leave the root list and appear under that
  project's view. Existing slice-1 tasks stay in Inbox (they have no project).
- Every existing task gets `priority: 0` (no badge) and no labels — no backfill
  job needed, the column default handles it.
- The top navbar is replaced by a **left sidebar** listing Inbox, Completed,
  and every project, plus Manage projects / Manage labels.
- The task form gains a **Project dropdown** (blank = Inbox), a **Priority
  dropdown** (P0–P3), and **Label checkboxes**.
- Task rows show a **priority badge** (P1–P3 only) and a **tag per label**.
- **Completing or editing a task returns you to its own list** (its project, or
  Inbox), not always Inbox.
- Deleting a project is **safe** — its tasks fall back to Inbox, never deleted.

**What did NOT change:** task create/edit/complete/history mechanics, soft-
complete, the completed-history view, due-date ordering (NULLS LAST), the
Turbo Complete/Delete wiring.

**Verification checklist (day one):**

1. `bin/rspec` full suite green (21 slice-1 + new examples); `rubocop` clean.
2. Fresh `bin/rails db:drop db:create db:migrate` runs clean, in FK-safe order.
3. An Inbox task (no project) **saves** — proves `belongs_to optional: true`.
4. Deleting a project nullifies its tasks (they reappear in Inbox), zero task
   rows lost.
5. Duplicate project/label name → 422, no row.
6. Deselecting all label checkboxes on edit **clears** the task's labels.
7. `priority` outside 0..3 is rejected at both the model and the DB.
8. Completing a task inside a project lands you back on that project's list.

## Done when

- Project + Label CRUD works in the browser.
- Sidebar lists Inbox + projects; Inbox and per-project views scope correctly.
- Task rows show priority badge (P1–P3) + label tags; the task form sets
  project, priority, and labels.
- Deleting a project sends its tasks to Inbox (no data loss).
- Full RSpec suite green. No date views, NLP, recurrence, or notifications.

## Rework / merge cost this slice imposes on later slices

- **Task model + schema** — slices 5 (recurrence) and 6 (in-page toasts) each
  touch the Task model; only slice 5 adds a column + migration — slice 6's
  planned `notified_at` was dropped (client-side toasts, no column). Serialize
  migrations by timestamp; expect a Task model-file merge (design C-note 1). This slice keeps its Task edits
  small (associations + one scope + one validation) to minimize that merge.
- **`_navbar.html.erb`** — slice 3 (Today/Upcoming links) edits the same
  sidebar partial. Kept as a partial (not inlined into the layout) for exactly
  this reason.
- **`tasks#index`** — slice 3 reuses this action/view for date views (branch on
  a date param the way this slice branches on `project_id`); slice 4 reworks
  the `create` path to parse a single quick-add field (design Rework 2). The
  `task_list_path` redirect and `ordered` scope survive both.
- **Defer `tasks/_task.html.erb`** — extract the row partial in slice 3 when the
  date-grouped Upcoming view becomes a second, structurally-different consumer
  of the row. Extracting now would be indirection with a single caller.

## Schema left extensible for later slices

`tasks` will still gain `recurrence` (slice 5). Slice 6's originally-planned
`notified_at` column was dropped — toasts are client-side, no column. Don't
pre-add — additive migrations land per slice (design C1).
