# Grill: "every other" recurrence feature

Context: extending `app/models/recurrence.rb` grammar. Current grammar:
`every(!)? (count)? unit` where unit = day/week/month/year/hour/minute or a
weekday name or weekday/workday. Weekday-name units currently reject count != 1.

## Q1: Is "every other X" a synonym for "every 2 X"?
A: Yes.

## Q2: Does "every other" apply to weekday names (e.g. "every other monday")?
A: Yes — explicitly called out as most important case, along with "every other weekday".

## Q3: Should this open general numeric counts for weekday/workday units
   (e.g. "every 3 mondays"), or is count:2 special-cased only via "other"?
A: General — "every 3 monday", "every third monday" should work.

## Q4a: Does ordinal-word counting apply to all units, or just weekday units?
A: All units (e.g. "every third week" too).

## Q4b: Ordinal vocabulary bound — fixed list or unbounded via library?
A: Initially "unbounded", reversed to: static list, first through twentieth. No new gem.

## Q5: Add a number-parsing gem for unbounded ordinals?
A: Superseded by Q4b reversal — no gem, static list to 20th.

## Q6: Rolling ("every!") + count on weekday/workday units — does count apply?
A: Yes (b) — "every! other monday" = second Monday from now (skip one),
   consistent with rolling interval units doing now + count*unit.

## Q7: Accept plural weekday names with count > 1 ("every 3 mondays")?
A: Yes — accept both singular and plural.

## Q8: Accept digit-suffix ordinals ("every 2nd monday", "every 21st day")?
A: Yes.

## Design summary (derived, not separately asked)
- "other" is sugar for count:2 at the grammar level; no unit-specific special-casing.
- `UNIT_RE` needs `s?` added to weekday-name alternatives (monday -> mondays?,
  etc.), mirroring the existing days?/weeks?/... plurals, so plural weekday
  names actually match the grammar (Q7). `normalize_unit` already strips a
  trailing `s`, so no change needed there.
- Word-ordinal list (other/first/second/third/.../twentieth) is a static hash,
  analogous to WEEKDAYS, mapping word -> integer, used alongside \d+ and
  \d+(st|nd|rd|th) as alternate count tokens in GRAMMAR.
- `Recurrence.parse` must resolve `match[:count]` via that ordinal hash when
  it's a non-numeric token (word ordinal or "other"), falling back to `.to_i`
  for `\d+` / digit-suffix (`2nd`) tokens. Plain `.to_i` returns 0 for word
  tokens, which would wrongly raise `InvalidError` on `every other monday`.
- Weekday-name and workday count validation (currently `count != 1` raises)
  needs to be relaxed to allow count >= 1 generally.
  This breaks the existing spec `spec/models/recurrence_spec.rb:62-64`
  ("rejects a count on a weekday-name recurrence"), which must be updated
  or replaced to match the new accepted forms (`every 3 monday`, plurals,
  ordinals) as part of implementation.
- advance_weekday / next_occurrence_of_weekday need to step count occurrences
  forward instead of hardcoded single 7-day step, for both fixed (phase-preserving,
  catch-up loop increments by count*7 days) and rolling (count steps from now) modes.
- advance_business_day / next_business_day need analogous count-step generalization
  (count business-day steps instead of 1), for fixed and rolling.
- Interval units (day/week/year/hour/minute) and :month need no stepping changes —
  already generic over `count`.

No unresolved questions remain.
