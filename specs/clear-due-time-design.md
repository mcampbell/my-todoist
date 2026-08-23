# Clear due time (revert to all-day)

## Problem

On the edit-task screen, a task with a due time had no reasonable way to
go back to all-day: the server/model side already handled it correctly
(`Task#compose_due_at` sets `all_day = true` whenever `due_time` comes
back blank on update — verified directly against the model, no bug
there), but the HTML5 `<input type="time">` control's native "clear"
affordance is inconsistent across browsers and easy to miss.

## Fix

Added an explicit "Clear time" button next to the due-time field in
`_form.html.erb` (`id="clear-due-time"`), wired to a plain click
listener in `application.js` that empties the field by its default
Rails-generated id (`task_due_time` — left un-overridden so the
`<label for="task_due_time">` association stays intact; code review
caught a first draft that gave the input a custom id and broke that
association) — following the same pattern as the existing `q`/`/`/`Esc`
listeners: no framework, document-level listener, one job.

Submitting the form with the (now-empty) time field goes through the
existing, already-correct `compose_due_at` logic — nothing on the model
or controller side changed.

## Testing

`spec/requests/tasks_spec.rb`: asserts the "Clear time" button renders
on the edit page. No JS spec — same rack_test constraint as
`q-shortcut-design.md`/`esc-shortcut-design.md`; the click handler
itself isn't exercised by RSpec.
