# Design: "starting" suffix for recurring tasks

Grill Q&A: `~/tmp/2026-09-01-recurrence-starting-grill.md`.

## Problem

A **recurring** task title can carry a suffix:

```
starting [on] <date>
starting in <N> <unit>
```

It sets where the **first** occurrence lands: the first occurrence of the
rule that is **on or after** the resolved anchor date. The recurrence rule
string is unchanged. `count` (`every 3 thursdays`) does **not** apply to
the first occurrence -- only to later steps.

| phrase (today = Tue Sep 1 2026) | first occurrence |
|---|---|
| `every wednesday starting in 2 days` | anchor Sep 3; first Wed on/after = Sep 2? no -> Sep 9. Wait: Sep 3 is Thu -> first Wed on/after Sep 3 = **Sep 9** |
| `every monday starting Feb 20` | Chronic rolls `Feb 20` to 2027-02-20 (a Sat) -> first Mon on/after = **2027-02-22** |
| `every 3 thursdays, starting on Wed` | anchor = next Wed (Sep 2); first Thu on/after = **Sep 3**; then every 3rd Thursday |
| `every monday` (no starting) | first Mon on/after today = **Sep 7** (latent fix: today is a Tue) |

## Behaviour decisions (from the grill)

1. **Recurring only.** On a non-recurring title, `starting ...` is left in
   the title verbatim (QuickAdd permissive default).
2. **A recurring title with any date/offset phrase but no `starting`
   keyword -> 422.** `errors[:due_at]` = "use 'starting' to set when a
   recurring task begins". This retires the current
   `every monday in 3 days` coexistence (see "Test impact").
3. **Anchor is a date only.** Any time the anchor phrase carries
   (`starting in 3 hours`, `starting monday at 9am`) is discarded. A time
   that belongs to the recurrence itself (`every ... at 3pm`) stays on the
   task.
4. **Past anchor is literal.** `starting last monday` -> a
   possibly-overdue first occurrence. No clamping.
5. **`count` never applies to the first occurrence.**
6. **`every!` (rolling) + starting:** the anchor sets the first
   `due_date`; rolling stepping takes over after the first completion.
7. **Inclusive:** anchor exactly on an occurrence -> that occurrence is
   the first.
8. **Monthly stays on the 1st.** `every month starting Feb 20` -> Mar 1
   (Feb 1 is before the anchor), then Apr 1, ...
9. **Anchor parse failure -> 422**, `errors[:due_at]` "couldn't read the
   starting date".

## New pure method: `Recurrence#first_occurrence(on_or_after:)`

`on_or_after:` a `Date`. Returns a `Time` in the app zone (the caller
takes `.to_date.iso8601`). Pure, no DB, no state. `count` and `rolling?`
are ignored. Per unit:

| unit | first occurrence on/after `d` |
|---|---|
| weekday name (`:monday`..`:sunday`) | `d` if `d.wday` matches, else the next matching weekday |
| business day (`:weekday`) | `d` if Mon-Fri, else the next Monday |
| interval (`:day/:week/:year/:hour/:minute`) | `d` itself (the anchor becomes the phase). Sub-day (`:hour`/`:minute`): `d` at the current clock time, mirroring the existing sub-day bootstrap |
| `:month` | the 1st of the month on/after `d` |
| `:anchored` | walk years from `d.year`; the first `occurrence_in(year)` that is `>= d` |

The weekday / business-day branches are the existing private helpers
(`next_occurrence_of_weekday`, `next_business_day`) minus the
"strictly-after" bump (`delta = 7 if delta.zero?`). Extract a shared
`*_on_or_after` core; keep `next_from` behaviour byte-identical (its own
tests guard that).

## Parsing (`app/models/quick_add.rb`)

New return key: `recurrence_start` (a `"YYYY-MM-DD"` string, or nil).
New key: `starting_error` (string, or nil) -- surfaced like `due_error`.

In `self.parse`, after `extract_recurrence!`, **only when `recurrence`
present**:

```ruby
if recurrence
  recurrence_start, starting_error = extract_recurrence_start!(title)
end
```

`extract_recurrence_start!(title)`:
1. `STARTING_RE = /,?\s*\bstarting\s+(?:on\s+)?/i`. If no match -> `[nil, nil]`.
2. Take the tail from the match to end of string. Resolve it, in order:
   `extract_due_offset!(tail_dup)` (for `in <N> <unit>`), then
   `date_span(tail_dup)` (for `feb 20`, `wed`, `next monday`).
3. On success: strip the whole `starting ... <resolved span>` from
   `title`; return `[resolved.to_date.iso8601, nil]`.
4. Tail present, nothing resolves -> `[nil, "couldn't read the starting date"]`.

**Guard the 422-without-starting rule in `self.parse`:** when `recurrence`
is present and, after `extract_recurrence_start!`, a `due_date` still gets
set by `extract_due_offset!` / `date_span` / `extract_point_in_time!` -->
that is a bare date on a recurring task with no `starting` -> set
`starting_error = "use 'starting' to set when a recurring task begins"`
and drop the `due_date`. (Simplest: after the date-extraction block, if
`recurrence && due_date && recurrence_start.nil?` -> convert to the
error.)

## Controller wiring (`TasksController`)

`create` already calls `apply_recurrence_anchors!(attrs, parsed[:recurrence], nil)`
when `parsed[:recurrence].present?`, and handles `parsed[:due_error]` by
rendering `:new` 422 with the message on `errors[:due_at]`. Add the same
handling for `parsed[:starting_error]`.

In `apply_recurrence_anchors!`, replace the bootstrap branch:

```ruby
if attrs[:due_date].blank? && bootstrapping
  rule = Recurrence.parse(recurrence)
  anchor = parsed_start ? Date.parse(parsed_start) : Date.current
  first = rule.first_occurrence(on_or_after: anchor)
  attrs[:due_date] = first.to_date.iso8601
  # sub-day rules still need a real clock time; first_occurrence gives it
  attrs[:due_time] ||= first.strftime("%H:%M") if recurrence_is_sub_day?(recurrence)
end
```

`parsed_start` is threaded in as a new argument to
`apply_recurrence_anchors!` (mirrors how `recurrence` is passed). This
subsumes the current `:anchored` special-case and the plain "today" case.

`recurrence_start` is **not** a permitted param -- it never reaches
`update`. Editing a recurrence later does not re-run "starting".

## Not doing

- No schema change.
- `update` / the edit form: no "starting" field. It is a create-time,
  quick-add-only grammar.
- Monthly day-of-month recurrence (rejected in the grill).
- Clamping a past anchor.

## Test impact

- `spec/lib/quick_add_spec.rb`:
  - "coexists with a recurrence phrase in the same title"
    (`water plants every 3 days next week`) -> now expects
    `starting_error`, no `due_date`.
  - "coexists with recurrence grammar in the same title"
    (`every monday in 3 days clean desk`) -> same.
  - New: each unit family with `starting`, the `count`-not-applied case,
    the anchor-on-occurrence case, the parse-failure case, the
    non-recurring pass-through, time-discard.
- `specs/in-x-unit-design.md`: revise the "Positive coexistence" note --
  `in <N> <unit>` no longer coexists with a recurrence; `starting` is the
  path now.
- `spec/models/recurrence_spec.rb`: new `describe "#first_occurrence"`
  block, every unit family, inclusive boundary.
- `spec/requests/tasks_spec.rb`: create with a `starting` phrase (happy +
  422 paths); the bare-date-plus-recurrence 422.
- Grep the request/system specs for any task created via quick-add with
  `every ... <date>` -- none found in the scout pass, but re-check.

## Decisions

- Method name: `Recurrence#first_occurrence(on_or_after:)` -> returns a Date.
- `QuickAdd` keys: `recurrence_start`, `starting_error`.
- One PR, not sliced.

## Also changed (in scope, small)

- `QuickAdd::RECURRENCE_RE` now accepts plural weekday names
  (`every 3 thursdays`), matching `Recurrence::UNIT_RE`. The user's
  example 3 needs it.
- The plain bootstrap for a dateless recurring task now uses
  `first_occurrence(on_or_after: today)` for every unit -- so
  `every monday` created on a Tuesday lands on the next Monday (was:
  today), and `every month` created mid-month lands on the next 1st
  (was: today). Latent fix, endorsed in the grill. One system spec
  ("lands a month recurrence on the 1st") updated to the new dates.
