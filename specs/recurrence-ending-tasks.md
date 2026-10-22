# Tasks: Recurrence ending

Design: `specs/recurrence-ending-design.md`

## Slice 1: "ending after N times"

- [x] **T1.1: Count limit on the task model**
  - Why: Slice 1 value. A recurring task stops after its last counted completion, logged like a one-off.
  - Where: new `db/migrate/*_add_recurrence_remaining_to_tasks.rb`, `db/schema.rb`, `app/models/task.rb` (`complete!`, `skip!`, validations, `before_validation`), `spec/models/task_spec.rb`
  - What: Add nullable integer `tasks.recurrence_remaining`. In `complete!`, inside `with_lock` and after the `CompletedOccurrence` snapshot: `remaining == 1` -> `destroy!`; else advance and decrement. `skip!` advances without touching the count. Validate nil or >= 1. Clear it in `before_validation` when `recurrence` is blank.
  - Options: Decrement inside `advance_to_next_occurrence!`'s `update!` (one write) rather than a second save.
  - Done when: `bin/rspec spec/models/task_spec.rb` passes with specs for: 3 -> 2 on complete; 1 -> task destroyed and one `CompletedOccurrence` written; skip leaves the count; 0 is invalid; clearing `recurrence` sets it to nil; nil count advances forever (unchanged behavior).

- [x] **T1.2: Parse "ending after N times" in QuickAdd**
  - Why: Slice 1 value. Quick-add sets the limit in the same phrase as the recurrence.
  - Where: `app/models/quick_add.rb` (`ENDING_RE`, new `extract_recurrence_end!`, `self.parse` return hash), `spec/lib/quick_add_spec.rb`
  - What: After `extract_recurrence_start!`, only when `recurrence` is present, match `,?\s*\bending\s+after\s+(\d+)\s+(?:times?|occurrences?|occurrances?)\b`, strip it, return `recurrence_count`. N < 1 -> `ending_error` "end count must be at least 1". Add `recurrence_count` and `ending_error` keys (nil by default). Document the wiring point inline.
  - Options: none
  - Done when: `bin/rspec spec/lib/quick_add_spec.rb` passes with specs for: each accepted word (time, times, occurrence, occurrences, occurrance, occurrances); title stripped; `every day ending after 0 times` -> `ending_error`; plain task `read ending after 5 times` keeps the words in the title with no count; works with `starting monday` before or after it.

- [x] **T1.3: Wire count into create, edit, and the task row**
  - Why: Slice 1 value. The limit is set on create, shown on the row, and editable.
  - Where: `app/controllers/tasks_controller.rb` (`create` at the `due_error || starting_error` check, `task_params`), `app/views/tasks/_form.html.erb` (after the Recurrence field), `app/views/tasks/_task.html.erb` (the `↻` tag), `spec/requests/tasks_spec.rb`
  - What: `create` passes `parsed[:recurrence_count]` as `recurrence_remaining` and adds `ending_error` to the 422 check. Permit `:recurrence_remaining` in `task_params`. Add a "Times left" number field (`min: 1`, blank = no limit). Append `· N left` to the `↻` tag when set.
  - Options: none
  - Done when: `bin/rspec spec/requests/tasks_spec.rb` passes with specs for: create with `every day ending after 3 times` stores 3; `ending after 0 times` -> 422 with the message; edit sets and clears the count; row shows `3 left`. Then `bin/rspec` and `bin/rubocop` are clean.

- [x] **T1.4: README examples for "ending after N times"**
  - Why: Slice 1 value. A reader finds the new clause and its rules in the README (user request, 2026-10-22).
  - Where: `README.md` ("Recurring tasks with an end", after the "starting" section)
  - What: Add the section with count examples, the accepted words, skip rule, and the edit field. Also fix the stale "Due reminders" bullet (server OS notification, removed in PR #56) and note Completed paging.
  - Options: none
  - Done when: `README.md` shows the section with 3 examples (count, with `starting`, rejected 0).

## Slice 2: "ending on <date>[ time]"

- [x] **T2.1: Date limit on the task model**
  - Why: Slice 2 value. A recurring task stops when its next occurrence would fall after the end.
  - Where: new `db/migrate/*_add_recurrence_ends_at_to_tasks.rb`, `db/schema.rb`, `app/models/task.rb`, `spec/models/task_spec.rb`
  - What: Add nullable datetime `tasks.recurrence_ends_at`. In `complete!` and `skip!`, compute the next due (move the `rule.next_from` step out of `advance_to_next_occurrence!` so both callers see it); next due > `recurrence_ends_at` -> `destroy!` (complete still logs first; skip logs nothing). Validate that a task does not carry both limits. Clear it with the recurrence.
  - Options: Return the next due from a small private method and keep `advance_to_next_occurrence!` taking it as an argument.
  - Done when: `bin/rspec spec/models/task_spec.rb` passes with specs for: next due on the end day (end of day) advances; next due after the end destroys and logs once; skip past the end destroys with no log; rolling `every!` uses completion time; timed end for an hourly rule; both limits invalid; clearing `recurrence` clears it.

- [x] **T2.2: Parse "ending on <date>[ time]" in QuickAdd**
  - Why: Slice 2 value. Quick-add sets the end date in the same phrase.
  - Where: `app/models/quick_add.rb` (`extract_recurrence_end!`, `resolve_start_anchor` or a sibling that keeps the time, `date_span`), `spec/lib/quick_add_spec.rb`
  - What: When `ending` is not followed by `after N`, resolve the tail after `ending [on]` with the offset grammar, then `date_span`. Date only -> end of that day (app zone); `span[:time_anchor]` -> that exact time. Return `recurrence_ends_at` (ISO 8601). Unresolvable -> `ending_error` "couldn't read the ending date". Both a count and a date in one title -> `ending_error` "use one ending: a date or a count".
  - Options: Reuse `resolve_start_anchor` with a flag to keep the time, or add `resolve_end_anchor`; pick the one with less duplication.
  - Done when: `bin/rspec spec/lib/quick_add_spec.rb` passes with specs (under `travel_to`) for: `ending on dec 31` -> Dec 31 23:59:59; `ending dec 31 at 5pm` -> 17:00; `ending in 2 weeks`; `ending on blah` -> error; both clauses -> error; plain task keeps the text.

- [x] **T2.3: Wire end date into create, edit, and the task row**
  - Why: Slice 2 value. The end is set on create, checked against the first occurrence, shown, and editable.
  - Where: `app/controllers/tasks_controller.rb` (`create`, `task_params`, `update`), `app/views/tasks/_form.html.erb`, `app/views/tasks/_task.html.erb`, `spec/requests/tasks_spec.rb`
  - What: `create` stores `parsed[:recurrence_ends_at]`; after `apply_recurrence_anchors!` sets the first due, an end before it -> 422 "the task ends before it starts". Edit form: "Ends on" date + time fields composed into `recurrence_ends_at` (blank = no limit). Row tag adds `· ends <date>` (with time when not end-of-day).
  - Options: Compose the two edit fields in `Task` virtual setters, like `due_date=`/`due_time=`, rather than in the controller.
  - Done when: `bin/rspec spec/requests/tasks_spec.rb` passes with specs for: create stores the end; ends-before-start 422; both-clauses 422; edit sets and clears the end; row shows `ends Dec 31`. Then `bin/rspec` and `bin/rubocop` are clean.

- [x] **T2.4: README examples for "ending on <date>[ time]"**
  - Why: Slice 2 value. A reader finds the date form and its rules in the README (user request, 2026-10-22).
  - Where: `README.md` ("Recurring tasks with an end")
  - What: Add date and date-time examples, inclusive end-of-day, skip past the end, the both-clauses and ends-before-start rejections, and the "Ends on" edit field.
  - Options: none
  - Done when: the section shows examples for `ending on <date>`, `ending <date> at <time>`, and both rejections.

## Questions and answers

- Q (general): Does a skip use up one of the N times?
  A: No. Only completions count.
- Q (general): Can one task carry both clauses?
  A: No. 422.
- Q (general): How is the limit edited after create?
  A: Two edit-form fields, "Ends on" and "Times left". Blank removes the limit.
