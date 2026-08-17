# Grill: specific-date pinning grammar

Input asked for: "Aug 15", "15-aug-2026", "noon", "1pm", "14:35", "the 24th".

## Q1: which of these already work today?
Read `quick_add.rb`'s `date_span` (quick_add.rb:141-172). It scans for a word
matching `DATE_WORD_RE` or `TIME_ANCHOR_RE`, extends the span across
neighboring anchor words, and hands the joined text to Chronic.

- "Aug 15" — `aug` matches `DATE_WORD_RE`, `15` absorbed as `NUMBER_RE`.
  Chronic parses `"aug 15"`. **Already works.**
- "noon", "1pm", "14:35" — all match `TIME_ANCHOR_RE` directly. **Already
  work** (as bare times, rolled to today/tomorrow via `roll_bare_time`).
- "15-aug-2026" — single whitespace-free token. `DATE_WORD_RE`/`TIME_ANCHOR_RE`
  are `\A...\z` anchored per-word, so a hyphenated compound never matches.
  **Does not work.**
- "the 24th" — `24th` matches `NUMBER_RE`, not `DATE_WORD_RE`, so it never
  triggers the scan's anchor word (`NUMBER_RE` only gets absorbed backward
  into an already-triggered span). **Does not work.**

Decision: scope this feature to the two gaps only. No new code for the four
formats that already pass.

## Q2: how should "15-aug-2026" be recognized?
Add a `COMPACT_DATE_RE` anchor: `\d{1,2}[-\/](?:jan|feb|...|dec)(?:[-\/]\d{2,4})?`,
case-insensitive, whole-word. Treat a match as a date anchor (same as
`DATE_WORD_RE`) so it enters the existing scan/absorb/Chronic pipeline
unchanged. Normalize `-`/`/` to spaces in `chronic_word` before handing the
token to Chronic (`"15-aug-2026"` -> `"15 aug 2026"`) — Chronic already
parses that spaced form.

Rejected: writing a separate `Date.parse` branch. Reusing Chronic means one
normalization step instead of a second date-parsing code path.

## Q3: how should "the 24th" be recognized?
Chronic already understands `"the 24th"` (next occurrence of that
day-of-month) when handed the phrase directly — the gap is only that the
scanner never starts a span there. Add ordinal-day (`\A\d{1,2}(?:st|nd|rd|th)\z`)
to the anchor check, and special-case a leading `"the"` immediately before an
ordinal-day word so it's absorbed into the span (Chronic needs the "the" to
disambiguate from a bare recurrence-style ordinal).

Rejected: custom day-of-month roll-forward math. Chronic already does this;
duplicating it would violate the project's own Chronic-scope note (only
custom regex/math for *non-free-text* grammars like recurrence/in-X-unit —
this is free text).

## Q4: does year-less "15-aug" need to work?
Yes — `COMPACT_DATE_RE`'s year group is optional, Chronic defaults to the
current year same as "Aug 15" already does.

## Q5: slash separator ("15/aug/2026")?
Included for free — same regex handles `-` and `/`. Not separately tested
beyond one example; no reason to expect divergent behavior since both
normalize to a space before Chronic.

## Q6: numeric month-slash dates ("15/8/2026", "8/15/2026")?
Out of scope. Not in the requested format list, and day/month order is
ambiguous without a stated convention (US vs. rest-of-world) — a follow-up
decision if requested, not a default to guess at.

## Q7: does either new anchor collide with existing grammars?
No. `RECURRENCE_RE`/`WEEKDAYS_SHORTHAND_RE`/`IN_UNIT_RE`/`PRIORITY_RE`/
`PROJECT_RE` all match different trigger words or `#`/`p#` tokens; compact
dates and ordinal-day words don't overlap any of them.

## Resolved: two independently deployable slices
1. Compact dash/slash date token (`COMPACT_DATE_RE`).
2. Bare ordinal day-of-month (`"the 24th"`).

Both touch `date_span`'s anchor-detection helpers in the same file region —
see design doc for the resulting merge-conflict note.
