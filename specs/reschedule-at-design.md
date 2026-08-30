# Reschedule-at freeform field — design

## Problem

Edit page. Add a freeform text field "Reschedule to". User types a point in
time ("tomorrow", "next wed", "in 2 months"). On save, task due date/time is
set from the parsed value. Calendar `date_field` / `time_field` stay.

## Reuse

`QuickAdd.parse` already parses every needed phrase:
- "in 2 months" -> `extract_due_offset!`
- "tomorrow", "next wed", "3pm" -> `date_span` (Chronic)

Call `QuickAdd.parse(text)`, take only `due_date` + `due_time`, drop
`priority` / `project_name` / `recurrence`.

## Behaviour

Field name: `task[reschedule_to]` (not an AR attribute, read from raw params
in `update`).

When `reschedule_to` is blank: ignore, normal update.

When present, in `TasksController#update`, before `@task.update`:

1. **Recurring guard.** If `@task.recurrence` present OR submitted
   `task[recurrence]` present -> reject. Flash / error: "Can't reschedule a
   recurring task; clear the recurrence first." Re-render `:edit` 422.
2. **Picker-conflict guard.** If the submitted `task[due_date]` differs from
   `@task.due_date` OR submitted `task[due_time]` differs from
   `@task.due_time` -> reject. "Use either the date pickers or Reschedule
   to, not both." The pickers render pre-filled, so only a *changed* value
   counts as "using" them.
3. **Parse.** `parsed = QuickAdd.parse(reschedule_to)`. If
   `parsed[:due_date]` nil -> reject. "Couldn't read a date from
   '<text>'." (QuickAdd never raises; no due_date == parse failure.)
4. Success: set `attrs[:due_date] = parsed[:due_date]`,
   `attrs[:due_time] = parsed[:due_time]`. `compose_due_at` derives
   `due_at` + `all_day` as normal. A date-only parse blanks any prior
   time (allowed). Overrides the pre-filled picker params.

Errors surface via `@task.errors.add(:base, ...)` then `render :edit` (form
already renders `task.errors.full_messages`). Keep the typed text on
re-render via `@reschedule_to` ivar + `value:` on the field.

## Not doing (YAGNI)

- No "clear"/"none" keyword. Removing a date happens by parsing a
  date-only phrase over a timed task, or is done with the existing pickers.
- No new PORO. One private method `apply_reschedule!(attrs)` in the
  controller, mirroring `apply_recurrence_anchors!`.
- No JS. Server-side guard only.

## Slices

One slice. One controller method + one view field + reuse of QuickAdd.
Single deployable unit -> no slicing, no estimates.md entry.

## Resolved

- Label: "Reschedule to".
- Changed picker + blank reschedule_to: works normally (guard only runs
  when reschedule_to present).
- `apply_reschedule!(attrs, phrase)` takes the phrase as an arg;
  `update` owns the `@reschedule_to` view ivar.
- Parse-failure message drops the raw phrase (keep it short).
