# Slice 3 — Date views (Today / Upcoming) — Implementation Plan

Goal: Today view (overdue + due-today + undated tasks, any project). Upcoming
view (grouped by date, next 7 days; excludes today and undated, since Today
already owns both). Dates still set via the structured form (no NLP yet —
slice 4). Adds Today/Upcoming nav links. No recurrence or notifications
(later slices).

Source: `specs/design.md` (Slice 3), `specs/slice-2-plan.md` (deferred
`_task` partial, `task_list_path`, `ordered` scope this slice reuses).
Branch off `main` (slice 1 + 2 merged). Tests interleaved per step.
Runner: `bin/rspec`. Carry forward: SQLite `NULLS LAST` ordering, Ruby 3.4.7
via `.mise.toml`.

## Locked decisions

- **An undated task counts as "today."** It carries no due date to exclude
  it from "now," so it's in scope for Today until it's given a date or
  completed — design.md Slice 3 states this explicitly. It's the opposite of
  the earlier draft, which dropped undated tasks for free via SQL range
  comparison; that free-drop was a bug (silently invisible from any date
  view), not a feature.
- **Today = overdue ∪ due-today ∪ undated, one flat list, no separate
  "Overdue" header.** `where("due_at <= ? OR due_at IS NULL", end_of_today)`
  on active tasks. `Task.ordered`'s `NULLS LAST` puts undated rows after
  dated ones in the list — dated-and-due-sooner surfaces first, undated still
  visible below it.
- **Upcoming excludes both today and undated** — tomorrow through today+6 (7
  days), grouped by date only. Today view already owns "today" (which now
  includes undated), so Upcoming re-including either would render a task
  twice across the two pages. `UPCOMING_DAYS = 7` is a controller constant,
  not user-configurable this slice.
- **Both views span all projects + Inbox** (no `project_id` filter) — that's
  the reason these views exist, orthogonal to slice 2's per-project cut.
- **Routes as `TasksController` collection actions** (`GET /tasks/today`,
  `GET /tasks/upcoming`), matching the existing `GET /tasks/completed`
  pattern already in routes.rb. No new controller.
- **Extract `tasks/_task.html.erb` now.** Slice 2 deferred this on purpose
  until a second, structurally different consumer showed up (its plan doc
  names this exact trigger). Upcoming's date-grouped list is that consumer:
  Inbox/project index, Today, and each Upcoming date group all render one
  task row via the same partial. Locals: `task:`.
- **Model scopes, not controller-inline SQL** — `Task.due_today_or_undated`/
  `Task.due_between` live next to `Task.ordered` so the date math has one
  home and is unit-testable without a controller round-trip.

## Step 1 — Task model scopes

```ruby
scope :due_today_or_undated, -> { where("due_at <= ? OR due_at IS NULL", Time.current.end_of_day) }
scope :due_between, ->(range) { where(due_at: range) }
```

`Task.active.due_today_or_undated.ordered` = Today.
`Task.active.due_between(1.day.from_now.beginning_of_day..7.days.from_now.end_of_day).ordered`
= Upcoming (grouped by date in the controller, see Step 3).

**Tests** (append `spec/models/task_spec.rb`). Wrap this block in
`travel_to Time.zone.local(2026, 1, 15, 12, 0, 0)` (a fixed noon, away from
any day boundary) — these scopes are day-boundary-sensitive by design, and
building "due-today"/"due-tomorrow" fixtures off live `Time.current` makes
them flaky within the minutes around real midnight:

- `due_today_or_undated`: an overdue task, a due-today task, and an undated
  task all match; a due-tomorrow task does not.
- `due_between`: a task due tomorrow matches a 1..7-day range; a task due
  today does not; a task due on day 8 does not; a nil-`due_at` task does not
  (undated never appears in Upcoming — it's Today's, per the locked
  decision).
- `bin/rspec spec/models/task_spec.rb`

## Step 2 — Extract `tasks/_task.html.erb`

Pull the `<tr>` body out of `tasks/index.html.erb` verbatim (complete
button, priority badge, title, due tag, label tags, edit/delete buttons) into
`app/views/tasks/_task.html.erb`, taking `task:` as its only local.
`index.html.erb` becomes:

```erb
<tbody>
  <%= render @tasks %>
</tbody>
```

(`render @tasks` implicitly uses `_task` partial per Rails convention — no
`partial:`/`locals:` needed for a plain collection.)

**Tests:** no new tests — this step is a pure refactor. Existing
`spec/requests/tasks_spec.rb` (index-related examples) must stay green
unchanged; that's the check.

- `bin/rspec spec/requests/tasks_spec.rb`

## Step 3 — Routes + controller actions

```ruby
# routes.rb — inside resources :tasks
collection do
  get :completed
  get :today
  get :upcoming
end
```

```ruby
# tasks_controller.rb
UPCOMING_DAYS = 7

def today
  @tasks = Task.active.due_today_or_undated.ordered.includes(:labels)
end

def upcoming
  range = 1.day.from_now.beginning_of_day..UPCOMING_DAYS.days.from_now.end_of_day
  @groups = Task.active.due_between(range).ordered.includes(:labels)
                .group_by { |t| t.due_at.to_date }
end
```

`@groups` is a `Date => [Task]` hash; `Task.ordered` already sorted
`due_at ASC`, and `group_by` preserves insertion order in Ruby, so iterating
`@groups` yields dates in ascending order for free — no separate sort step.

**Fix carried into this slice: `complete`, `update`, and `destroy` must all
return to Today/Upcoming.** These three actions redirect to
`task_list_path(@task)` (the task's project or Inbox) — none has a notion of
Today/Upcoming, so acting on a task from either new view bounces the user off
it. Since `_task.html.erb` (Step 2) is now shared across all four views and
renders Complete, Edit, and Delete on every row, this is a real papercut
introduced by giving Today/Upcoming those buttons, not a pre-existing one —
it applies identically to all three actions, not just `complete`. Fix: swap
all three to `redirect_back_or_to`, which returns to the referring page
(Today, Upcoming, Inbox, or the project) when present and falls back to
`task_list_path(@task)` otherwise (e.g. a direct PATCH/DELETE with no
referer, as in request specs). `update`'s invalid branch is unaffected — it
still `render :edit` on validation failure; only its success redirect changes.

```ruby
def update
  if @task.update(task_params)
    redirect_back_or_to task_list_path(@task), notice: "Task updated."
  else
    render :edit, status: :unprocessable_content
  end
end

def destroy
  @task.destroy
  redirect_back_or_to task_list_path(@task), notice: "Task deleted."
end

def complete
  @task.complete!
  redirect_back_or_to task_list_path(@task), notice: "Task completed."
end
```

**Tests** (append `spec/requests/tasks_spec.rb`, one block per action —
`PATCH /tasks/:id`, `DELETE /tasks/:id`, `PATCH /tasks/:id/complete`):

- With `HTTP_REFERER` set to `today_tasks_path`, the action redirects back to
  `today_tasks_path` (not `task_list_path`).
- With `HTTP_REFERER` set to `upcoming_tasks_path`, same.
- With no referer (existing behavior), the action still falls back to
  `task_list_path(@task)` — locks the pre-slice-3 request-spec behavior.
- `bin/rspec spec/requests/tasks_spec.rb`

**Tests** (`spec/requests/tasks_spec.rb`, new `describe "GET /tasks/today"` /
`describe "GET /tasks/upcoming"` blocks):

- Today: 200; shows an overdue task, a due-today task, and an undated task;
  hides a due-tomorrow task and a completed task.
- Today spans projects: a task assigned to a project still appears (proves no
  `project_id` scoping).
- Upcoming: 200; a task due tomorrow appears under tomorrow's date; an
  undated task does **not** appear (Today owns it); a task due today does
  **not** appear (Today owns it); a task due on day 8 does not appear; an
  overdue task does not appear.
- Upcoming groups correctly: two tasks on the same future date render under
  one date heading; dates render in ascending order.
- `bin/rspec spec/requests/tasks_spec.rb`

## Step 4 — Views

`app/views/tasks/today.html.erb`:

```erb
<h1 class="title">Today</h1>
<% if @tasks.empty? %>
  <p class="has-text-grey">Nothing due today.</p>
<% else %>
  <table class="table is-fullwidth is-hoverable is-vcentered">
    <tbody><%= render @tasks %></tbody>
  </table>
<% end %>
```

`app/views/tasks/upcoming.html.erb`:

```erb
<h1 class="title">Upcoming</h1>
<% if @groups.empty? %>
  <p class="has-text-grey">Nothing due in the next <%= TasksController::UPCOMING_DAYS %> days.</p>
<% else %>
  <% @groups.each do |date, tasks| %>
    <h2 class="subtitle"><%= date.strftime("%A, %b %-d") %></h2>
    <table class="table is-fullwidth is-hoverable is-vcentered">
      <tbody><%= render tasks %></tbody>
    </table>
  <% end %>
<% end %>
```

**Tests:** covered by Step 3's request specs (response body assertions on
rendered HTML) — no separate view-spec step.

## Step 5 — Nav links

`layouts/_navbar.html.erb`, top `menu-list` (before Completed):

```erb
<li><%= link_to "Today", today_tasks_path %></li>
<li><%= link_to "Upcoming", upcoming_tasks_path %></li>
```

**Tests** (append `spec/requests/navigation_spec.rb`):

- Sidebar renders Today and Upcoming links pointing at the new paths.
- `bin/rspec spec/requests/navigation_spec.rb`

## Step 6 — Full suite + smoke

- `bin/rspec` whole suite green.
- `rubocop` clean.
- Manual smoke via `bin/rails server`: an overdue task, a today task, and an
  undated task all show on Today; a task due in 3 days shows on Upcoming
  under its date heading, grouped correctly with same-day tasks; the undated
  task does **not** show on Upcoming (it's Today's); a task due in 10 days
  shows on neither; completing, editing, or deleting a task from
  Today/Upcoming returns to that view (not Inbox/project).

## Done when

- Today view lists overdue + due-today + undated tasks across all projects.
- Upcoming view shows tasks due in the next 7 days (excluding today and
  undated) grouped by date, ascending.
- `tasks/_task.html.erb` is the single row-rendering source for Inbox,
  per-project, Today, and Upcoming.
- Sidebar has Today + Upcoming links.
- Full RSpec suite green. No NLP, recurrence, or notifications.

## Rework / merge cost this slice imposes on later slices

- **`_navbar.html.erb`** — already flagged in slice 2's plan (design conflict
  C2) as a shared-edit point; this slice is the second editor. No further
  slices touch it until slice 4/6 (neither currently plans to).
- **Active-task filtering** — design's Rework item 3: slice 5 (recurrence)
  changes what "next occurrence" means on complete, which will touch the
  `due_today_or_undated`/`due_between` scopes' assumptions (a completed-then-
  reopened recurring task re-enters Today/Upcoming via its new `due_at`). No
  code changes needed now; noted so slice 5 knows to re-check Today/Upcoming
  against its rescheduling behavior.
- No new merge conflicts beyond the one design.md already named (C2). No
  changes needed to `estimates.md` — slice 3's 1-day/small estimate and C2's
  cost are already recorded there.
