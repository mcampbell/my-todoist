# Design: "ending" suffix for recurring tasks

Grill Q&A: `specs/recurrence-ending-grill.md`.

Goal: a recurring task stops coming back after an end date/time or after N
completions. Completing the final occurrence logs it and deletes the task,
like a one-off task.

```
ending [on] <date>[ <time>]
ending after <N> {time|times|occurrence|occurrences|occurrance|occurrances}
```

Sliced: 2 slices. Run S1, then S2 (see Conflicts for the parallel option).

## Shared rules

- **Recurring only.** On a plain task, `ending ...` stays in the title
  verbatim (same as `starting`).
- **Grammar home:** `QuickAdd`, `ENDING_RE = /,?\s*\bending\s+/i`, a new
  `extract_recurrence_end!(title)` called in `self.parse` right after
  `extract_recurrence_start!`, only when `recurrence` is present. It strips
  the clause from the title. Either order with `starting` works, because
  each extractor strips its own clause by regex, not by position.
- **New parse keys:** `recurrence_count`, `recurrence_ends_at`,
  `ending_error`. `TasksController#create` adds `ending_error` on `due_at`
  and renders 422, the same path as `starting_error`.
- **Limit lives on the task**, not in `recurrence`. `Recurrence` and its
  parser do not change.
- **Check point:** `Task#complete!` and `#skip!`, inside the existing
  `with_lock`, before `advance_to_next_occurrence!`. If the rule says
  "final", `destroy!` instead of advancing. `complete!` still writes its
  `CompletedOccurrence` first.
- **Clearing the recurrence clears the limit** (`Task` `before_validation`).
- **Edit form:** each slice adds one field next to Recurrence. Blank =
  no limit.

## S1 - "ending after N times"

Value: "do this 5 more times" tasks end on their own.

- Migration: `tasks.recurrence_remaining` (integer, null). `nil` = no limit.
- Parse: `after (\d+) (times?|occurrences?|occurrances?)`. N < 1: 422
  "end count must be at least 1".
- Meaning: completions left, counting the current occurrence.
  `after 5 times` stores 5.
- `complete!`: `remaining == 1` -> final (destroy). Else advance and
  `remaining -= 1`.
- `skip!`: advances, count unchanged (user call: skips do not count).
- Validation: `recurrence_remaining` nil or >= 1.
- Edit form: "Times left" number field (`min: 1`), permitted in
  `task_params`.
- Row tag: `↻ every day · 3 left`.
- Specs: QuickAdd (parse, words, N = 0, plain-task passthrough, with
  `starting`), Task model (count down, final destroy + log, skip keeps
  count, clear recurrence clears it), request (create 422, edit set/clear,
  row tag).

## S2 - "ending on <date>[ time]"

Value: "until the end of the term" tasks end on their own.

- Migration: `tasks.recurrence_ends_at` (datetime, null).
- Parse: the tail after `ending [on]` resolves like `starting`
  (`resolve_start_anchor`: offset grammar, then Chronic via `date_span`),
  extended to keep a time when the phrase has one. Date only -> end of that
  day in the app zone. Bad phrase: 422 "couldn't read the ending date".
- Both clauses on one title: 422 "use one ending: a date or a count".
- End before the first occurrence: 422 "the task ends before it starts"
  (`TasksController#create`, after `apply_recurrence_anchors!` sets the
  first due date).
- `complete!` and `skip!`: compute the next due (`rule.next_from`, already
  done inside `advance_to_next_occurrence!`); if it is after
  `recurrence_ends_at` -> final (destroy). Skip past the end also destroys,
  with no completion log.
- Rolling (`every!`): same check; the next due comes from completion time.
- Reschedule moves one occurrence; the limit does not change.
- Validation: a task cannot carry both `recurrence_ends_at` and
  `recurrence_remaining` (edit-form guard for the 422 rule).
- Edit form: "Ends on" date + time fields.
- Row tag: `↻ every monday · ends Dec 31`.
- Specs: as S1, plus inclusive end-of-day, timed end for sub-day rules,
  rolling, skip past end, both-clauses 422, ends-before-start 422.

## Deferred edge cases

- Ending on a phrase Chronic rolls into next year (`ending on feb 20` in
  October means next Feb). Accepted as Chronic behavior, as with `starting`.
- An end date earlier than today on edit: allowed; the next completion
  ends the task.

## Conflicts and rework

- C1 (only if S1 and S2 run in parallel): both edit `QuickAdd.parse`, the
  parse return hash, `Task#complete!`/`#skip!`, `db/schema.rb`, `_form`,
  `_task` tag, and `task_params`. Small, mechanical conflicts.
- R1: S2 adds the "both clauses" 422 and the one-limit validation, which
  touch S1's parse branch and model validation.
- Recommendation: run serially (S1 then S2). C1 then does not happen; R1
  stays.

## Tasks

- [ ] S1 branch `recurrence-ending-count`
- [ ] S1 red: QuickAdd, Task, request specs
- [ ] S1 green: migration, parse, complete!/skip!, form, tag
- [ ] S1 `bin/rspec`, `bin/rubocop`; code-reviewer; commit
- [ ] S2 branch `recurrence-ending-date` (from S1 merged)
- [ ] S2 red: QuickAdd, Task, request specs
- [ ] S2 green: migration, parse, complete!/skip!, form, tag, both-clauses 422
- [ ] S2 `bin/rspec`, `bin/rubocop`; code-reviewer; commit
