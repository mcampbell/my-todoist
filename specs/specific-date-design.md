# Design: specific-date pinning grammar

Grill Q&A: `specs/specific-date-grill.md`.

Four of the six requested formats ("Aug 15", "noon", "1pm", "14:35") already
parse via the existing `date_span`/Chronic pipeline (quick_add.rb:141-172) —
confirmed by reading the current anchor regexes, not assumed. No code
changes for those. Remaining two formats are gaps, sliced by input format.

## Slice 1: compact dash/slash date token

Formats: `15-aug-2026`, `15-aug`, `15/aug/2026`.

- New constant `COMPACT_DATE_RE` in `quick_add.rb`, alongside `DATE_WORD_RE`:
  ```ruby
  COMPACT_DATE_RE = /\A\d{1,2}[-\/](?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)(?:[-\/]\d{2,4})?\z/i
  ```
- `date_word?` (quick_add.rb:192) becomes `DATE_WORD_RE.match?(word) || COMPACT_DATE_RE.match?(word)` — the token now qualifies as a scan-start anchor and as an absorbable neighbor, no other pipeline change.
- `chronic_word` (quick_add.rb:187) normalizes separators before Chronic sees it: `word.tr("-/", " ")`, applied whenever `COMPACT_DATE_RE` matches (checked before the existing `CHRONIC_SYNONYMS` lookup, since a compact-date token is never a synonym key).
- No change to `self.parse`, `extract_due_offset!`, or any other extractor — this slice is entirely inside `date_span`'s helper methods.

Deploys and is usable alone: users can type `15-aug-2026` today, `the 24th` still doesn't work until slice 2 ships.

## Slice 2: bare ordinal day-of-month

Format: `the 24th`, `24th` (no "the").

- `NUMBER_RE` (quick_add.rb:25) already matches `24th`; reuse it as the anchor test instead of adding a new constant — `anchor_word?`/scan-start both call `date_word?(bare) || time_anchor?(bare)`, so change the scan-start condition (quick_add.rb:143-145) to also accept `NUMBER_RE.match?(bare) && bare.match?(/(?:st|nd|rd|th)\z/i)` (an ordinal, not a bare cardinal — a bare `24` alone stays non-triggering, unchanged behavior).
- Leading `"the"` needs absorbing into the Chronic-bound span (Chronic parses `"the 24th"` but not reliably `"24th"` alone). Add a one-word lookback next to the existing `NUMBER_RE` backward-absorb loop (quick_add.rb:150): if the word immediately before the ordinal is exactly `"the"` (case-insensitive), extend `k` one further back.
- No new top-level constant beyond the ordinal-suffix check inline; everything else (Chronic call, `time_anchor`/`date_anchor` flags, span removal) is unchanged.

Deploys and is usable alone, independent of slice 1 — different anchor path, no shared conditional.

## Deferred / explicitly out of scope

- Numeric month-slash dates (`15/8/2026`) — ambiguous day/month order, not
  in the requested format list (grill Q6).
- Any Chronic-bypassing custom date math — both slices stay inside the
  existing Chronic call, per the project's Chronic-scope note.
- Disambiguating "the Nth" as a date vs. a plain ordinal reference (e.g.
  "the 2nd item") — flagged in code review as a known false-positive risk;
  accepted trade-off, not solved, since Chronic-scope rules out extra
  custom parsing logic here.

## Merge-conflict note

Both slices edit `date_span`'s neighboring helper methods
(`date_word?`, scan-start condition, backward-absorb loop, `chronic_word`) in
the same ~30-line region of `quick_add.rb`. Whichever slice lands second
rebases past trivial line-adjacency, not logic conflicts — the two anchor
checks are additive `||` conditions, not shared state. Recorded as C4 in
`specs/estimates.md`.

## Test plan (TDD — failing spec first)

`spec/lib/quick_add_spec.rb`:
- Slice 1: `15-aug-2026`, `15-aug` (current year), `15/aug/2026`; mid-title
  placement; title strips cleanly (no leaked separator, no double space).
- Slice 2: `the 24th` rolls to this month if the 24th hasn't passed, next
  month if it has (freeze time in spec, same pattern as existing
  `roll_bare_time` coverage); bare `24th` without "the" — confirm current
  behavior is unchanged (still non-triggering, since it's not in the
  requested format list).
- Regression: confirm the four already-working formats stay covered by
  existing specs (`Aug 15`, `noon`, `1pm`, `14:35`) — no new specs needed,
  named here only to record that they were checked, not written blind.

## Order

No dependency between slices — either first. Both are single-sitting,
easy-scale changes (no new deps, no schema change, no controller change).
