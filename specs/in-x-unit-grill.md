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
A: Open — not yet answered.

## Design summary (derived, not separately asked)
- Dedicated regex for the whole `in <count-or-a/an> <unit>` phrase, all six
  units, one span including the leading `in` — checked as its own case in
  `QuickAdd.parse` (quick_add.rb:38-57) ahead of the general `date_span` scan,
  mirroring how `RECURRENCE_RE` is already checked as its own case.
- If Q5 resolves to direct computation: `Time.current + count.unit(s)`,
  mirroring `Recurrence#interval` (`app/models/recurrence.rb`).
- Follow-on question, not yet asked: should count parsing (numeric/word-ordinal/
  apostrophe forms) reuse `Recurrence::ORDINAL_WORDS`/`resolve_count`
  (`app/models/recurrence.rb` lines ~17-33), or stay independent? `in X unit`
  is a count/duration concept; `Recurrence` ordinals are positional — the
  semantics may not map cleanly.

Unresolved: Q5, and the ordinal-reuse follow-on once Q5 lands.
