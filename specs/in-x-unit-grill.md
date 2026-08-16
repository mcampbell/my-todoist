# Grill: "in X unit" date-pinning grammar

Context: new one-off due-date pin for `QuickAdd` (`app/models/quick_add.rb`),
distinct from `Recurrence`'s repeating grammar. Examples: `in 3 days`,
`in 15 minutes`, `in a week`.

## Q1: Reuse Chronic, or hand-roll a parser?
A: Reuse Chronic where reliable. Chronic already parses `in <digit> unit`
correctly for day/hour/minute/week/year. It returns `nil` for `in a/an unit`.
(Superseded in part by Q5 — final computation bypasses Chronic entirely.)

## Q2: Does `a`/`an` -> count 1 apply to all units, or just the ones Chronic fails on?
A: Uniformly across all six units (day/hour/minute/week/month/year). One
generic rule, not per-unit special cases.

## Q3: How to absorb the leading `in` so it doesn't leak into the saved title?
A: `QuickAdd.date_span` only absorbs a leading bare number backward
(quick_add.rb:128), not a trigger word. Extend backward-absorption to also
eat one `in` immediately before the number/count token.

## Q4: Should day/hour/minute be added bare to `DATE_WORD_RE` like week/month/year?
A: No. Bare `"3 days"`/`"2 weeks"` already misparse via Chronic (today /
past-dated) — an existing quirk for week/month/year. Day/hour/minute are far
more common in ordinary task titles (e.g. "review 3 days worth of logs") and
would introduce a much bigger false-positive surface. Gate day/hour/minute
behind a required `in` prefix; they never become bare `DATE_WORD_RE` anchors.

## Q5: Compute the due date via direct Ruby duration math, or hand off to Chronic after `a`/`an` normalization?
A: Direct Ruby math — `Time.current + count.unit(s)`, mirroring
`Recurrence#interval` (`app/models/recurrence.rb`). Deterministic, fewer
moving parts, no dependence on Chronic's unreliable bare-relative-phrase
handling.

## Q6: Should count parsing reuse `Recurrence::ORDINAL_WORDS`/`resolve_count`, or stay independent?
A: Stay independent, plain-cardinal only. `in X unit` is a duration count,
not a position ("in third day" isn't natural English). Reusing ordinal
machinery for a non-ordinal case would invite confusion for no user benefit.

## Q7: Cardinal number format — digits only, or also spelled-out words (`in three days`)?
A: Digits + `a`/`an` -> 1 only. No spelled-out cardinal-word parser exists in
the codebase (only `Recurrence`'s *ordinal* words, ruled out by Q6). Adding
one is disproportionate scope; digits cover the realistic quick-add typing
pattern.

## Q8: Precision — exact timestamp vs. date-only, and by what rule?
A: Duration-based split. If the computed offset is less than 1 day (minute/
hour units), set an exact `due_at` timestamp and `all_day: false`. If the
offset is 1 day or more (day/week/month/year units), set `all_day: true` and
drop the time component — matches existing bare-date-word behavior
(`Task#due_at` is `datetime`; `all_day` flag lives on `Task`,
`app/models/task.rb`).

## Design summary
- Dedicated regex for the whole `in <count-or-a/an> <unit>` phrase, all six
  units, one span including the leading `in` — checked as its own case in
  `QuickAdd.parse` (quick_add.rb:38-57) ahead of the general `date_span` scan,
  mirroring how `RECURRENCE_RE` is already checked (quick_add.rb:81).
- Match scans anywhere in the title (`title.match(RE)`, not anchored to
  start), mirroring `extract_recurrence!` (quick_add.rb:80-96) — phrase may
  sit mid-title or at the end. Strip the matched span plus trailing sentence
  punctuation the same way `recurrence_span_end` does.
- Count: digits (`\d+`) or `a`/`an` -> 1. No ordinal words, no spelled-out
  cardinals.
- Due date: `Time.current + count.unit(s)` (e.g. `count.days`, `count.hours`).
- Precision: offset < 1.day -> exact `due_at`, `all_day: false`. Offset >=
  1.day -> `all_day: true`, time dropped.

Status: all questions resolved. Ready for `/mc-design` implementation plan.
