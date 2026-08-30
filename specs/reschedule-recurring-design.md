# Reschedule a recurring task's next occurrence — design

## Problem

"Reschedule to" rejects any recurring task. Goal: let it move **only the
next occurrence**. The recurrence rule and its phase stay fixed and resume
exactly on completion.

**Invariant (user):** a free-text reschedule affects the next occurrence
only. The recurrence model is retained in all cases. The only thing that
changes recurrence is editing the recurrence field itself.

`Recurrence` (the class) must not change.

## Why a stored anchor is required

`Recurrence#next_from(due_at:, now:)` re-derives the *date* from the rule
but takes *time-of-day* from `due_at`; for interval rules
(`every N days/weeks/years/hours/minutes`) and `every N months` (N>1) it
takes the *phase* from `due_at` too. So moving `due_at` and leaving
`recurrence` alone leaks the change into every future occurrence.

To keep the pattern exact, `complete!` must step from the pre-reschedule
`due_at` + `all_day`, not from the rescheduled values. Store them.

## Schema

Migration: add to `tasks`, both nullable, no default:

- `recurrence_anchor_at` : datetime
- `recurrence_anchor_all_day` : boolean

Non-null only between a recurring reschedule and the next completion.

## Flow

### `TasksController#apply_reschedule!` (rewrite)

Drop the "reject any recurrence" guard. Keep, unchanged:

- **Picker guard** — `picker_changed?(attrs)` -> reject. The calendar
  picker and this field cannot both be used, ever. One, the other, or
  neither.
- **Recurrence-change guard** — reject when the submitted `recurrence`
  differs from `@task.recurrence` (mirror `picker_changed?`; an unchanged
  re-post of the same string is fine). Editing the rule and rescheduling
  are separate saves.
- **Parse guard** — phrase must yield a `due_date`.

Then:

```
parsed = QuickAdd.parse(phrase)
attrs[:due_date] = parsed[:due_date]
attrs[:due_time] = parsed[:due_time]

if @task.recurrence.present? && @task.due_at.present?
  attrs[:recurrence_anchor_at]      = @task.recurrence_anchor_at || @task.due_at
  attrs[:recurrence_anchor_all_day] = @task.recurrence_anchor_all_day.nil? ? @task.all_day : @task.recurrence_anchor_all_day
end
```

- Anchor recorded once — a second reschedule before completion keeps the
  first anchor, only `due_at` moves again.
- Dateless recurring task: `@task.due_at` nil -> no anchor; there is no
  phase to protect; `complete!` steps from the rescheduled `due_at`.
- `apply_reschedule!` now fully owns the due fields for a reschedule
  save, so `update` must **not** also call `apply_recurrence_anchors!`
  when a reschedule was applied (use the existing `elsif`-style branch).

### `task_params`

No new permitted keys. `recurrence_anchor_at` / `recurrence_anchor_all_day`
are set only by `apply_reschedule!` and cleared only by the model.

### `Task#complete!` (one change)

```
anchor         = recurrence_anchor_at || due_at || Time.current
anchor_all_day = recurrence_anchor_at ? recurrence_anchor_all_day : all_day

rule     = Recurrence.parse(recurrence)
next_due = rule.next_from(due_at: anchor, now: Time.current)
sub_day  = rule.unit.in?(%i[hour minute])
next_due = next_due.beginning_of_day if anchor_all_day && !sub_day
update!(due_at: next_due,
        all_day: anchor_all_day && !sub_day,
        recurrence_anchor_at: nil,
        recurrence_anchor_all_day: nil)
```

The `CompletedOccurrence` snapshot keeps using `due_at` / `all_day` (the
rescheduled values) — that is when the task was actually due.

### `TasksController#update` — clear the anchor when the schedule is redefined

No Rails callback. In `update`, before `@task.update(attrs)`, when this is
**not** a reschedule save:

```
if attrs[:recurrence].to_s != @task.recurrence.to_s || attrs[:due_date].blank?
  attrs[:recurrence_anchor_at] = nil
  attrs[:recurrence_anchor_all_day] = nil
end
```

Covers the edit form (the only UI path). A console edit that changes the
rule without clearing the anchor is out of scope (single-user app; accept
it rather than add a callback). On a reschedule save `apply_reschedule!`
has already set the anchor keys, so this branch is skipped.

## Semantics (fixed by the invariant, no open choice)

- Reschedule earlier, complete before the original slot: the moved slot
  is the one completed; next = `next_from(anchor)` = one full cycle past
  the original. The original slot does not also fire.
- Reschedule later, complete after regular slots passed: `next_from`
  skips them, same as completing any recurring task late.
- Flip all-day <-> timed for the occurrence: allowed; the next
  occurrence returns to `recurrence_anchor_all_day`.
- Remove the recurrence: `recurrence` blank -> anchor cleared; the
  rescheduled `due_at` stays as a one-off.

## Slices

One slice. Migration + `apply_reschedule!` rewrite + one `complete!`
change + one `before_save` + view help text. Single deployable unit — no
sub-slicing, no estimates.md (single user, no team).

## TDD checklist

Request specs (`spec/requests/tasks_spec.rb`):

- `every 3 days`, anchored Mon: reschedule to Wed -> `due_at` Wed,
  `recurrence` unchanged, `recurrence_anchor_at` = original Mon.
  `complete!` -> next = original Mon + N*3d on the original phase; anchor
  nulled.
- `every monday`: reschedule to "wednesday 3pm" -> occurrence timed;
  `complete!` -> next Monday back at the original clock time / all-day.
- `every 2 months`: reschedule shifts only the next; series resumes.
- all-day `every week`: reschedule to "tomorrow 3pm" ->
  `recurrence_anchor_all_day` true; next occurrence all-day again.
- Second reschedule before completion keeps the first anchor.
- Editing the `recurrence` string clears the anchor.
- Clearing the due date clears the anchor.
- Picker changed + reschedule -> 422 (recurring and non-recurring).
- Recurrence string changed + reschedule -> 422.
- Dateless recurring task: reschedule sets `due_at`, no anchor.

Model specs (`spec/models/task_spec.rb`): `complete!` with
`recurrence_anchor_at` / `recurrence_anchor_all_day` set — steps from the
anchor, nulls both, floors by the anchor's all-day.

## Decisions

- Column names: `recurrence_anchor_at` / `recurrence_anchor_all_day`.
- Anchor cleared in `TasksController#update`, not a Rails callback.
  Console edits that redefine the rule without clearing the anchor are
  out of scope.
