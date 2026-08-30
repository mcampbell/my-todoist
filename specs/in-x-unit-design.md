# Design: "in X unit" date-pinning grammar

Single deployable unit — one regex, one parse branch, one date computation.
Not sliced (see `specs/in-x-unit-grill.md` for resolved Q&A this design is
based on).

## Grammar

`in <count> <unit>` where:
- `count` = digits (`\d+`) or `a`/`an` (-> 1). No ordinal words, no
  spelled-out cardinals.
- `unit` = `day(s)`, `hour(s)`, `minute(s)`, `week(s)`, `month(s)`, `year(s)`
  (singular/plural, case-insensitive).

Examples: `in 3 days`, `in 15 minutes`, `in a week`, `in 2 hours`.

## Parse integration

New constant `IN_UNIT_RE` in `app/models/quick_add.rb`, structurally parallel
to `RECURRENCE_RE` (quick_add.rb:11):

```ruby
IN_UNIT_RE = /\bin\s+(?:(?<count>\d+)|an?)\s+(?<unit>days?|hours?|minutes?|weeks?|months?|years?)\b/i
```

New method `extract_due_offset!(title)`, parallel to `extract_recurrence!`
(quick_add.rb:80-96):
- `title.match(IN_UNIT_RE)` — scans anywhere in the title (mid-title or end),
  not anchored to start.
- On match: strip the matched span plus trailing sentence punctuation via
  `recurrence_span_end`, same as `extract_recurrence!`.
- Resolve count: `match[:count]&.to_i || 1`.
- Compute offset: `count.public_send(match[:unit].downcase)` (see "Due date
  computation" below).
- Return `due_date`/`due_time` strings — same keys and formats `self.parse`
  already returns (quick_add.rb:68-75): `due_date` as `"YYYY-MM-DD"`, and
  `due_time` as `"HH:MM"` or `nil` per the precision rule below. This mirrors
  how `date_span` populates these same local variables in `self.parse`
  (quick_add.rb:47-57), so no new keys are added to the return hash and
  `Task#compose_due_at` picks up the offset the same way it picks up any
  other parsed date.
- Return `nil` when no match.

Call `extract_due_offset!` from `self.parse` (quick_add.rb:38-57) as its own
case, checked **before** the general `date_span` scan — same ordering
rationale as `RECURRENCE_RE` (avoids the general scanner misinterpreting a
week/month/year unit as a bare `DATE_WORD_RE` match once `in` is stripped —
e.g. `in 2 weeks` leaving `2 weeks`; `days`/`hours`/`minutes` are not in
`DATE_WORD_RE` and are not at risk here).

Wiring in `self.parse`: capture the offset's result before the `date_span`
check, e.g. `due_date, due_time = extract_due_offset!(title)`, replacing the
plain `due_date = nil` / `due_time = nil` initialization at quick_add.rb:44-45.
Guard the existing `date_span` branch with `unless due_date` (quick_add.rb:47)
so a matched offset takes precedence and `date_span` never overwrites it —
mirrors how `extract_recurrence!` and `extract_priority!` are already run
unconditionally ahead of it with no clobbering, since each owns disjoint
title text.

## Due date computation

```ruby
offset = count.public_send(unit) # e.g. 3.days, 15.minutes
target = Time.current + offset
due_date = target.to_date.iso8601
due_time = offset < 1.day ? target.strftime("%H:%M") : nil
```

No Chronic involvement — direct Ruby/ActiveSupport duration math only
(Q5). Mirrors `Recurrence#interval` (`app/models/recurrence.rb`) in style,
not in code (different feature, no shared logic to extract — YAGNI).

## Precision rule

- `offset < 1.day` (minute/hour units) -> `due_time` set to the exact clock
  time (`all_day: false` results downstream).
- `offset >= 1.day` (day/week/month/year units) -> `due_time` nil, date
  only (`all_day: true` results downstream via `Task#compose_due_at`,
  `app/models/task.rb:74-91`, the same way `date_span`'s bare-date matches
  already produce `all_day: true` today).

## Precedence with existing grammar

- Runs before `RECURRENCE_RE`/`date_span` in `self.parse`, but does not
  conflict with them — different trigger word (`in` vs `every`), disjoint
  regex.
- Does not touch `DATE_WORD_RE` (Q4) — day/hour/minute remain ungated bare
  words; only the `in <count> <unit>` phrase is recognized.

## Extension: "next week/month/year" (2026-08-30)

`NEXT_UNIT_RE = /\bnext\s+(?<unit>weeks?|months?|years?)\b/i`, handled in the
same `extract_due_offset!` as a count-1 offset. Reason: Chronic parses
"next <period>" to the *middle* of that period ("next year" -> Jul 2), which
surprised a user. Now "next week" == "in 1 week", etc.

- Weekday names ("next monday") and "next weekday" stay with Chronic /
  `date_span` -- the `\b` after the unit keeps the regex off "weekday".
- Scope: week/month/year only. "next day/hour/minute" are not period words
  people use for a task date; Chronic's "tomorrow" already covers the day
  case.

## Deferred / explicitly out of scope

- Spelled-out cardinal words (`in three days`) — Q7.
- Ordinal-word counts, apostrophe/digit-suffix ordinals — Q6.
- Chronic-based fallback parsing — Q1/Q5 superseded.

## Test plan (TDD — failing specs first)

`spec/lib/quick_add_spec.rb`:
- Each of the 6 units, digit count: `in 3 days`, `in 2 hours`, `in 15
  minutes`, `in 1 week`, `in 6 months`, `in 1 year`.
- `a`/`an` -> count 1, for at least one unit each.
- Phrase mid-title and at end of title; verify title strips cleanly
  (no leaked `in`, no double space, trailing punctuation absorbed).
- Precision: minute/hour -> `due_time` present (exact clock time); day+ ->
  `due_time` nil (date only, no time-of-day).
- No match: plain titles unaffected (e.g. "review 3 days worth of logs" —
  no `in` prefix, must not match; regression guard for Q4 decision).
- No accidental interaction with `RECURRENCE_RE`/`every` grammar in the same
  title.
- Positive coexistence: both grammars present in one title (e.g.
  `every monday in 3 days clean desk`) — both `recurrence` and `due_date`
  are set correctly, title strips cleanly.

## Estimate

Single slice, no merge-conflict/rework concerns (isolated to
`quick_add.rb` + its spec file, no shared code with the open
`every-other-recurrence` PR). Recorded in `specs/estimates.md`: **easy**
(1 point) — one regex, one parse branch, direct duration math, no new
dependencies.
