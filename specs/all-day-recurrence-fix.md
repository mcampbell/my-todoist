# Bug: rolling recurrence stole the time on all-day tasks

## Symptom

An all-day task with a recurrence (especially rolling, `every!`) lost its
all-day status on completion — the next occurrence picked up whatever
clock time the task happened to be completed at.

## Root cause

`Task#complete!` computed `next_due` from
`Recurrence#next_from`, then decided `all_day` for the *next* occurrence
by inspecting whether `next_due`'s clock time was midnight
(`timed = next_due's time != "00:00"`). For **rolling** recurrence,
`Recurrence#next_from` deliberately steps from the *completion* moment
(`now`), not from the original `due_at` — by design, so a rolling
recurrence doesn't drift back toward a stale anchor. But that means
`next_due`'s time-of-day is the completion clock time, which is almost
never midnight — so the old `timed` check reliably flipped `all_day` to
`false` on every rolling-recurrence completion of an all-day task. This
was intentional per a comment in the old code, but wrong: an all-day
task has no time to preserve or "discover" from the completion moment.

## Fix

`Task#complete!` now floors `next_due` to `beginning_of_day` when
`all_day` was true, and simply carries `all_day` forward unchanged
(`update!(due_at: next_due, all_day: all_day)`) — no more `timed`
inspection. The recurrence stepping still determines *which day* the
next occurrence lands on (including, for rolling recurrence, stepping
from the completion date rather than the original due date); an
all-day task just never inherits a time-of-day from that computation.

## Second bug, caught by code review

The first cut of the fix unconditionally floored `next_due` to
`beginning_of_day` whenever `all_day` was true. For a **sub-day**
rolling recurrence (`every! N minutes`/`every! N hours`) attached to an
all-day task, `next_from` computes `now + interval` — a few minutes or
hours ahead of completion — and flooring that back to the same
midnight every time means `due_at` never advances. The task would be
stuck "due today" forever, no matter how many times it's completed.

Not reachable through the normal web UI: `TasksController
#apply_recurrence_anchors!` already forces a `due_time` (making the
task non-all-day) whenever the recurrence unit is hour/minute and no
time was given. But `Task` itself had no equivalent guard, so a
console-created, seeded, or otherwise legacy all-day+sub-day row would
hit the stall.

Fixed by checking the recurrence unit: only floor to `beginning_of_day`
(and keep `all_day`) when the unit isn't `hour`/`minute`. For a sub-day
recurrence on an all-day task — a combination that doesn't make sense
as "all day" in the first place — the task becomes timed instead, same
as the old (buggy) behavior did for that specific case, so it still
advances.

## Testing

`spec/models/task_spec.rb`: rolling all-day day-unit recurrence now
asserts `all_day?` stays `true` and `due_at` lands at
`beginning_of_day` on the completion-advanced date (previously asserted
the opposite — that test encoded this exact bug).
`spec/system/recurrence_flow_spec.rb`: same fix for a rolling
weekday-name (`every! monday`) recurrence, reached via a different
`Recurrence#next_from` branch (`advance_weekday`) than the day/week/
year/hour/minute interval branch the model spec exercises.
