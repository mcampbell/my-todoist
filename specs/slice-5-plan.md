# Slice 5 — Recurrence engine — Implementation Plan

Goal: `Recurrence` PORO (pure parse + stepping, per design.md's semantics).
Quick-add and the edit form both gain real recurrence support — `every`/
`every!` phrases stop being rejected. Completing a task is reworked around
an immutable `CompletedOccurrence` audit row: recurring tasks advance
`due_at` and stay active; one-off tasks get a final snapshot and are
destroyed. Replaces `Task#completed_at` / `Task.completed` scope from
slice 1 entirely.

Source: `specs/design.md` (Slice 5, "Recurrence semantics" section), grill
session below. Branch off `main` (slice 4 merged, PR #5). Tests interleaved
per step. Runner: `bin/rspec`.

## Grill session (2026-08-15)

Full log: `~/tmp/2026-08-15-slice-5-grill.md`. Summary:

| # | Question | Answer |
|---|----------|--------|
| 1 | Editing/removing recurrence on an existing task, given edit form is otherwise unchanged | Add a recurrence text field to the edit form; reuses `Recurrence.parse` for validation |
| 2 | Recurring completions leave no trace under the slice-1 single-mutable-row model — acceptable? | No — log each completion |
| 3 | Minimal shape for that log | Immutable copy of the original task, not a live FK — audit log, nothing later modifies it or references anything mutable |
| 4 | Which fields to snapshot | Everything (title, project name, priority, labels, due_at, completed_at); Completed view shows the minimal set, with a link to full detail |
| 5 | Does the log apply to every completion or just recurring ones | Every completion — replaces `completed_at`-on-`Task` for one-off tasks too |
| 6 | What happens to the `Task` row for a one-off task once its snapshot exists | Row is destroyed; `CompletedOccurrence` is the sole historical record |
| 7 | Existing completed tasks already in the dev DB | Migration backfills them into `CompletedOccurrence` rows, then deletes the old rows |
| 8 | Visible indicator for recurring tasks on the list row | Small repeat tag next to the due-date tag, same partial-change pattern as the overdue red background |

Q2–Q7 are a substantial scope expansion over design.md's stated
single-mutable-row model — flagging that design.md's Domain section needs a
follow-up edit once this slice lands (not done as part of this plan).

## Locked decisions

- **Four sub-slices, ordered to avoid a broken-window state:**
  1. **5a — Occurrence-log completion** (no recurrence yet). Replaces
     `completed_at`/`Task.completed` with `CompletedOccurrence` for *all*
     completions. Ships and is useful standalone — the Completed view and
     history model improve before recurrence exists at all.
  2. **5b — `Recurrence` PORO**. Pure parse + stepping logic, unit-tested in
     isolation, not wired into anything yet. Small, foundational, no user
     value alone — bundled next because 5c depends on it.
  3. **5c — Wire recurrence end-to-end**: quick-add parsing, edit-form
     field, `Task#complete!` branching (advance vs snapshot+destroy), row
     badge. Parsing and the complete-flow branch **must** ship together —
     landing the ability to *set* recurrence before `complete!` knows to
     honor it would silently destroy a "recurring" task on its first
     completion, which is worse than the current reject-and-explain
     behavior in slice 4.
  4. **5d — Full suite + smoke.**
- **`recurrence` column stores the raw canonical string** (e.g.
  `"every 3 days"`, `"every! monday"`), not a pre-parsed structure —
  matches design.md ("stores recurrence string"). `Recurrence.parse` runs
  against it fresh at complete-time; cheap regex, no need to cache a parsed
  form.
- **Bare shorthand normalized at parse time.** `weekdays`/`workday` (no
  `every` prefix) is stored as the canonical `"every weekday"` — `Recurrence`
  itself only ever has to understand the `every`-prefixed grammar, not the
  shorthand. `workday` is a Chronic-only synonym for date parsing
  (`CHRONIC_SYNONYMS`) and stays distinct from this — it does not appear as
  a `Recurrence` unit.
- **No date token typed alongside a recurrence phrase** (e.g. just
  `"Take pills every day"`): default `due_date` to today (my call, not from
  the grill — small enough not to warrant its own round). Fixed-mode
  stepping needs a starting anchor; today is the least surprising default
  and mirrors "a recurring task starts now" intuition. Rolling mode doesn't
  care (anchor is always completion time).
- **Sub-day recurrence (`every N hours`/`every N minutes`) with no time
  token also defaults `due_time` to now, not just `due_date`.** Without
  this, `compose_due_at` sees a blank `due_time`, sets `all_day: true`,
  and stores `due_at` at midnight — fixed stepping then marches the
  interval from midnight, landing on a non-midnight `due_at` while
  `all_day` stays `true`. Two knock-on effects that default avoids: `due_tag`
  renders date-only for an `all_day?` task (hides the time entirely), and
  slice 6's notifier is spec'd to skip `all_day` tasks — a minute/hour
  recurrence created this way would never fire. Any recurrence unit
  *other* than hour/minute keeps defaulting `due_time` unset
  (`all_day: true` is correct for a daily/weekly/monthly task with no
  stated time).
- **`CompletedOccurrence` has no foreign keys** (Q3) — plain denormalized
  columns (`task_title`, `project_name`, `priority`, `label_names`,
  `due_at`, `completed_at`). `label_names` is a comma-joined string,
  consistent with the rest of the schema's plain-string columns (no new
  serialization dependency for a personal app's label names).
- **Migration does data work with raw SQL** (`connection.execute`/
  `select_all`), not the `Task`/`CompletedOccurrence` AR classes — the same
  migration changes the schema those classes map to, so touching it via AR
  mid-migration is a footgun. Read old completed rows + their
  project/label joins, insert snapshots, delete the rows, drop the column —
  all in one migration (single-user local dev DB; no production-scale
  concern that would justify splitting the schema/data change into
  separate migrations).
- **`Task.active` / `Task.completed` scopes are removed**, not left as
  dead code — once completion always either destroys the row or leaves
  `due_at` advanced, every row in `tasks` is inherently active. Keeping a
  `completed_at`-based scope that can never match anything would misstate
  the model. All `Task.active.*` call sites in `TasksController` become
  plain `Task.*`.
- **Deferred edge case, named not solved:** a task whose `due_at` doesn't
  fall on the weekday a `every <weekday>` recurrence names (e.g. `due_at`
  is a Tuesday but the recurrence string says `every monday`). Design.md
  doesn't specify this; not handled here. `Recurrence`'s weekday-unit
  stepping assumes the anchor already sits on that weekday (true for the
  normal path: quick-add sets both `due_date` and `recurrence` from the
  same submission).
- **`every month`/`every N months` lands on the 1st of the target month**
  (user decision, 2026-08-15, updates design.md) — not
  `due_at.advance(months: N)`, which would clamp a Jan-31 anchor to
  Feb-28 and leave the shortened day persisting on later steps. Stepping
  from `due_at` becomes: take the 1st of `due_at`'s month, then advance
  by N calendar months, N times, until `>= now` (fixed) or `1.month.since
  (now).beginning_of_month` (rolling, one-shot). No clamping ambiguity to
  defer — the day-of-month is discarded entirely as part of the unit's
  definition.

## Step 1 (Slice 5a) — Occurrence-log completion, no recurrence yet

- Migration `CreateCompletedOccurrences` (single file, per the raw-SQL
  decision above):
  - `create_table :completed_occurrences`: `task_title` (string, not null),
    `project_name` (string, nullable), `priority` (integer, not null),
    `label_names` (string, nullable, comma-joined), `due_at` (datetime,
    nullable), `completed_at` (datetime, not null), timestamps. No indexes
    needed yet (small personal dataset; add if the Completed view ever
    needs to page/filter it).
  - Backfill: `select_all` every `tasks` row where `completed_at IS NOT
    NULL`, joined to `projects` (name) and `task_labels`/`labels` (names,
    comma-joined via `GROUP_CONCAT(labels.name)` **ordered by
    `labels.name`** in SQLite — matches the runtime snapshot's
    `labels.pluck(:name).sort.join(", ")` so a multi-label task's
    `label_names` string is identical whether backfilled or completed
    live), insert one `completed_occurrences` row per match using
    `completed_at` as-is.
  - Delete those `tasks` rows (`DELETE FROM tasks WHERE completed_at IS NOT
    NULL`), then `remove_column :tasks, :completed_at`.
- `app/models/completed_occurrence.rb`: plain `ApplicationRecord`, no
  associations (Q3 — nothing it references can change out from under it).
  `validates :task_title, :priority, :completed_at, presence: true`.
- `app/models/task.rb`:
  - Remove `active`/`completed` scopes, `completed?`.
  - `overdue?` drops the `completed?` check (a `Task` row that exists is
    inherently not completed): `due_at.present? && due_at <
    Time.current.beginning_of_day`.
  - `complete!`: wrap in `with_lock` (replaces the current `with_lock {
    return if completed? }` guard — a `Task` row's mere existence is no
    longer sufficient to prove "not already completing," since two
    concurrent `complete!` calls on the same id would otherwise both
    read the row before either destroys it, producing two
    `CompletedOccurrence` snapshots). Inside the lock: reload, build a
    `CompletedOccurrence` snapshot (`task_title: title, project_name:
    project&.name, priority:, label_names: labels.pluck(:name).sort.join(",
    "), due_at:, completed_at: Time.current`), save it, then `destroy`
    self — all inside one transaction (snapshot + destroy must both
    succeed or neither does). A second call against the same id after
    the first completes raises `ActiveRecord::RecordNotFound` on the
    controller's `Task.find` (row is gone) — the natural, sufficient
    idempotency signal once completion always destroys or the row
    persists only in its advanced form.
- `app/controllers/tasks_controller.rb`:
  - `index`/`today`/`overdue`/`upcoming`: `Task.active.*` → `Task.*`.
  - `completed`: `@occurrences = CompletedOccurrence.order(completed_at:
    :desc)` (rename from `@tasks` — the completed view no longer renders
    `Task` rows).
  - `complete`: capture `task_list_path(@task)` *before* calling
    `@task.complete!` (the task, and its `project` association already
    loaded, must still be addressable after destroy for the redirect).
- New route + controller for the detail link (Q4): `resources
  :completed_occurrences, only: :show` in `config/routes.rb`.
  `app/controllers/completed_occurrences_controller.rb#show`: `@occurrence
  = CompletedOccurrence.find(params[:id])`.
- `app/views/tasks/completed.html.erb`: iterate `@occurrences`; keep the
  same two-column title/completed_at rendering, add a "Details" link to
  `completed_occurrence_path(occurrence)`.
- `app/views/completed_occurrences/show.html.erb` (new): render all
  snapshot fields (title, project, priority, labels, due_at, completed_at).
- Tests:
  - `spec/models/task_spec.rb`: `complete!` on a non-recurring task
    destroys the `Task` row and creates a matching `CompletedOccurrence`
    (title/project/priority/labels/due_at/completed_at all correct);
    `overdue?` no longer needs a `completed?` branch test (row not
    completed by construction).
  - `spec/models/completed_occurrence_spec.rb`: presence validations.
  - `spec/requests/tasks_spec.rb`: `PATCH .../complete` on a one-off task
    — task gone from `GET /tasks`, occurrence appears in `GET
    /tasks/completed`.
  - `spec/requests/completed_occurrences_spec.rb`: `GET
    /completed_occurrences/:id` renders the snapshot.
  - Manual: run the migration against the dev DB, confirm existing
    completed tasks became occurrences with correct project/label/priority
    data.
  - **Existing specs to rewrite or remove** (this step's contract makes
    them fail, not just add to — enumerated up front so 5a doesn't leave
    the suite red mid-step):
    - `spec/models/task_spec.rb`: `active`/`completed` scope-partition
      examples and `completed?` examples — removed (scopes gone).
      `complete!` idempotency examples (repeat call preserves the
      original timestamp) — rewritten against the new guard (Step 1's
      `with_lock`): second `complete!` on an already-destroyed row is
      exercised via the controller (`Task.find` raises), not via a
      second in-process `complete!` call on a stale instance.
      `completed_overdue` (via `completed_at`) — removed (`overdue?` no
      longer branches on `completed?`).
    - `spec/requests/tasks_spec.rb`: `GET /tasks/completed` examples and
      fixtures that build `Task` rows via `completed_at` — rewritten to
      build `CompletedOccurrence` rows directly instead.
    - `spec/system/task_flow_spec.rb`: the checkbox-complete system test —
      re-verified, not rewritten; a one-off task disappearing from the row
      list on completion is the same observable behavior under
      destroy-based completion, but the spec's setup may still reference
      `completed_at` and needs updating to match.

## Step 2 (Slice 5b) — `Recurrence` PORO

- `app/models/recurrence.rb`: `Recurrence.parse(string) -> Rule` (`nil` for
  a blank/nil string; raises `Recurrence::InvalidError` for a string that
  doesn't match the grammar — mirrors `compose_due_at`'s rescue pattern for
  the Task validation added in Step 3).
- Grammar (design.md, verbatim): `every`/`every!` + optional `N` + unit
  (`day(s)`/`week(s)`/`month(s)`/`year(s)`/`hour(s)`/`minute(s)`/weekday
  name/`weekday`). `!` = rolling, no bang = fixed.
- `Rule#rolling?`.
- `Rule#next_from(due_at:, now: Time.current)`:
  - rolling: `now + interval` (one shot — `now` is always ahead of any
    prior due date, no stepping needed).
  - fixed: step from `due_at` by the interval, repeatedly re-applying it
    (never jumping straight to `now`), until the result is `>= now`. This
    preserves phase/grid per design.md's invariant.
  - weekday-name unit steps by the same rule as a 1-week interval (see
    deferred edge case above — assumes `due_at` already sits on that
    weekday).
  - `weekday`/`workday` unit (business-day) steps one calendar day at a
    time, skipping Sat/Sun, either as the rolling one-shot or the fixed
    stepping loop.
  - `month`/`N months` unit steps from the 1st of `due_at`'s month (not
    `due_at` itself), discarding day-of-month — see Locked decisions.
- `spec/models/recurrence_spec.rb`: one example per unit (day/week/month/
  year/hour/minute/weekday-name/business-day) × {fixed, rolling}, plus a
  month-unit example anchored on the 31st of a month to confirm it lands
  on the 1st of the next eligible month rather than clamping to the
  28th/30th; the two worked examples from design.md verbatim:
  - `every wednesday`, `due_at` 10 days overdue, completed on a Saturday →
    lands on the coming Wednesday (4 days out from completion).
  - `every 3 days`, `due_at` 8 days overdue → lands 1 day out from
    completion, not on the completion date itself.
  - Invalid string (`"every"` with no unit, `"every 3 potatoes"`) raises.
  - Blank/nil string → `nil` (no rule, not an error — matches how a task
    with no recurrence behaves elsewhere).

## Step 3 (Slice 5c) — Wire recurrence end-to-end

- Migration: `add_column :tasks, :recurrence, :string`.
- `app/models/quick_add.rb`:
  - Remove `RecurrenceNotSupportedError`, `RECURRENCE_ERROR`, and the
    `raise` in `parse`.
  - `RECURRENCE_RE` gains capture groups (bang, count, unit) and is used to
    *extract* a `recurrence:` value and remove the matched span from the
    title — same span-removal pattern as `PROJECT_RE`. Runs first, before
    `date_span` (unchanged reasoning: `every weekday` must not reach
    Chronic as a one-off date).
  - `WEEKDAYS_SHORTHAND_RE` match → `recurrence: "every weekday"`
    (normalized, per Locked decisions), matched span removed from title.
  - Return shape gains `recurrence:` (nil when absent).
- `app/controllers/tasks_controller.rb#create`: `attrs[:recurrence] =
  parsed[:recurrence]`. If `parsed[:recurrence].present? &&
  parsed[:due_date].blank?`, default `due_date` to `Date.current.iso8601`
  (Locked decisions). **If additionally the recurrence unit is hour/minute
  (match the raw string against `/\Aevery!?\s*\d*\s*(hour|minute)/` —
  no PORO predicate needed for this one check) and
  `parsed[:due_time].blank?`, also default `due_time` to
  `Time.current.strftime("%H:%M")`** — keeps `all_day: false` so the
  task carries a real time anchor (Locked decisions). **Delete the `rescue QuickAdd::RecurrenceNotSupportedError
  => e` clause (current lines 65-68)** — Step 3 removes the constant it
  rescues from `quick_add.rb`; leaving the clause in place turns any
  unrelated `StandardError` from `create` into a `NameError` on the
  now-undefined constant, masking the real error.
- `app/models/task.rb`:
  - `validate :recurrence_must_be_parseable` — `Recurrence.parse(recurrence)`
    inside a rescue, `errors.add(:recurrence, "is invalid")` on
    `Recurrence::InvalidError`. Mirrors `compose_due_at`.
  - `complete!` branches (inside the same `with_lock` from Step 1):
    - `recurrence.blank?` → unchanged from Step 1 (snapshot + destroy).
    - `recurrence.present?` → snapshot `CompletedOccurrence` as before
      (this occurrence's `due_at`/`completed_at`), then `update!(due_at:
      Recurrence.parse(recurrence).next_from(due_at: due_at ||
      Time.current, now: Time.current))` — task stays in the table,
      active, rescheduled. No destroy. The `due_at || Time.current`
      guard covers a recurrence set via the edit form on a task with no
      due date (the create-path default only fires on create, not on
      edit) — without it, fixed-mode stepping calls `nil + duration` and
      raises `NoMethodError` instead of failing loud with a validation
      error.
    - **Accepted limitation:** this branch never destroys the row, so
      unlike the one-off path (idempotent via `RecordNotFound` on
      re-find), a double-submit/double-click on a recurring task's
      complete action produces two `CompletedOccurrence` rows and two
      interval advances — `with_lock` serializes the two calls but
      doesn't dedupe them, since a persistent row has no "already
      completed this instant" signal to check against. Not solved here:
      a single-user local app doesn't warrant a request-level
      idempotency token or a transient "last completed at" column for a
      race that's rare, low-consequence, and manually recoverable
      (delete the extra occurrence, step `due_at` back). Revisit only if
      this app ever gains concurrent/multi-device use.
- `app/views/tasks/_form.html.erb` (edit form only, per Q1/Q4-slice-4):
  add a `f.text_field :recurrence` with the same grammar hint style as the
  quick-add placeholder. `task_params` permits `:recurrence`.
- `app/views/tasks/_task.html.erb` (Q8): small tag next to the existing
  `due_tag` when `task.recurrence.present?`, e.g. `<span class="tag
  is-light">↻ <%= task.recurrence %></span>` — raw stored string, no
  humanization helper (nothing needs one yet).
- Tests:
  - `spec/lib/quick_add_spec.rb`: extraction per unit, bang vs non-bang,
    shorthand normalization (`weekdays`/`workday` → `"every weekday"`),
    combined with date/priority/`#project` tokens in one string, residual
    title correctness. Malformed `every`-shaped text that still doesn't
    match the grammar (e.g. `"every potato"`) is *not* extracted — falls
    through to title like today's permissive-parser behavior for anything
    unrecognized (no `RecurrenceNotSupportedError` to raise anymore; if it
    slips through as a `recurrence:` value the model validation catches
    it, but the parser itself should only extract well-formed matches).
  - `spec/models/task_spec.rb`: `complete!` on a recurring task, both
    fixed and rolling, reproducing the two design.md worked examples
    end-to-end through `Task#complete!` (not just the PORO) — task stays
    in the table, `due_at` advances correctly, a `CompletedOccurrence` is
    still created for that occurrence.
  - `spec/requests/tasks_spec.rb`: create with a recurrence phrase
    persists `recurrence`; `PATCH .../complete` on a recurring task keeps
    it out of `GET /tasks/completed` and shows it in `GET /tasks` (or
    `/today`/`/upcoming`) with the new due date; edit form round-trip sets
    and clears `recurrence`; create with `"Water plants every 10 minutes"`
    (no explicit time) persists `all_day: false` and a `due_at` set to the
    current time, not midnight — contrast with `"Water plants every 3
    days"` (no explicit time), which still persists `all_day: true`.
  - `spec/system/task_flow_spec.rb`: type `"Water plants every 3 days"`,
    complete it, task reappears (not in Completed) with an advanced due
    date and the repeat tag visible.

## Step 4 — Full suite + smoke

- `bin/rspec` green, full suite.
- Rubocop clean.
- Manual: create a recurring task via quick-add (fixed and rolling), complete
  it a few times watching `due_at` step; edit an existing task's recurrence
  via the edit form (set, change, clear); confirm the Completed view +
  detail show page for both a fresh completion and a migrated/backfilled
  one; confirm a one-off task still disappears entirely on completion.

## Done when

- `Recurrence.parse`/`next_from` correctly reproduce both design.md worked
  examples and cover every unit in the grammar.
- Quick-add and the edit form both accept `every`/`every!` phrases;
  `every`/`every!` is no longer rejected.
- Completing a recurring task advances `due_at` in place and leaves the
  task active; completing a one-off task destroys it. Both create a
  `CompletedOccurrence` snapshot.
- Completed view reads from `CompletedOccurrence`, with a working detail
  link. Existing dev-DB completed tasks survived the backfill migration.
- `Task.active`/`Task.completed` and `completed_at` are gone — no dead
  scope left behind.
- Full suite green, Rubocop clean.

## Rework / merge cost this slice imposes on later slices

- **Slice 6 (notifications)** — design.md's poll query (`due_at <= now AND
  notified_at IS NULL AND completed_at IS NULL`) needs its `completed_at`
  clause dropped; every row in `tasks` is inherently not completed once
  this slice lands, so the clause is redundant, not just stale.
- **design.md's Domain section** needs a follow-up edit: the "single
  mutable Task row, no template/instance" line no longer fully describes
  the model once `CompletedOccurrence` exists as an immutable instance
  record for finished occurrences. Not done as part of this plan (flagged
  in the grill summary above).
