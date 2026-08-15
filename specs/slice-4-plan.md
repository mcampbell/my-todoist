# Slice 4 — Quick-add NLP (one-off) — Implementation Plan

Goal: replace the structured create form with a single free-text field,
parsed server-side (chronic gem for date/time; hand-rolled token parser for
priority and `#project`). `@label` parsing and recurrence (`every`/`every!`)
are explicitly out of scope — see Locked decisions. Edit form is unchanged.

Source: `specs/design.md` (Slice 4), grill session below. Branch off `main`
(slices 1-3 merged, `slice-3-date-views` PR'd). Tests interleaved per step.
Runner: `bin/rspec`.

## Grill session (2026-08-15)

Full log: `~/tmp/2026-08-15-slice-4-grill.md`. Summary of resolved branches:

| # | Question | Answer |
|---|----------|--------|
| 1 | `pN` token vs internal `0..3` priority scale | Todoist-style: `p1`->3, `p2`->2, `p3`->1, `p4`->0 |
| 2 | `#project` no-match handling | Fuzzy-match existing names first; only auto-create on no near-miss |
| 3 | `@label` parsing | Out of scope this slice — stays on structured form control |
| 4 | Edit form once create is quick-add-only | Unchanged — keeps date picker / project dropdown / priority select |
| 5 | `every`/`every!` typed before slice 5 exists | Detect syntax, reject submission ("Recurrence not supported yet") |
| 6 | No date token typed | Undated — slice-3's "default to today" is dropped for quick-add; carve-out: bare time token alone implies today/tomorrow (see design.md) |
| 7 | Fuzzy-match confirm UX | Inline re-render (validation-error style), no new endpoint/JS/state |

Note on Q7: "avoid JS" is a tiebreaker between roughly-equal options, not an
absolute — server-rendered Ruby wins ties, it's not worth heroics to dodge JS
outright. Inline re-render was already the simpler choice on its own merits.

## Locked decisions

- **Slice by input type**, not one monolithic parser landing at once. Each
  sub-slice ships real value on its own (typing `p1` works before date
  parsing exists), and orders cheapest/lowest-risk first:
  1. **4a — Priority token** (`p1..p4`). No new gem, no schema change, purely
     additive to the existing structured form. Cheapest possible first slice.
  2. **4b — Date/time token** (chronic gem). Adds the one new dependency this
     slice needs. Additive — structured date field still present and still
     works for whatever the text didn't specify.
  3. **4c — `#project` token**, with fuzzy-match-confirm. Most complex:
     find-or-create semantics, typo detection, and the one new UI state
     (confirm banner). Ships last because it's the riskiest piece.
  4. **4d — Field removal**. Once 4a-4c cover priority/date/project, the quick-add
     text field is single source for all three — remove the now-redundant
     structured Project dropdown and Due-date field from the *create* form.
     Priority `<select>` is also removed (quick-add covers it). Label
     checkboxes **stay** (Q3). Edit form is untouched throughout (Q4).
- **Quick-add is additive until 4d**: unrecognized text remains in the title.
  A user who never learns the `pN`/date/`#project` syntax loses nothing until
  4d ships — at which point structured due-date/project entry is genuinely
  gone and quick-add syntax is the only way to set them on create.
- **No date token and no time token -> no due_date** (Q6 + design.md
  carve-out), effective from 4b onward. No default. A bare time token
  alone implies a date: today if the time hasn't passed, tomorrow if it
  has (design.md Slice 3 carve-out; Step 2 roll rule).
- **`every`/`every!` detection is a static regex reject in the parser**
  (Q5), not deferred to a later slice — ships as part of 4b (date/time
  parsing owns the phrase-recognition surface where "every" would otherwise
  get misread as a date fragment).
- **Fuzzy-match**: Ruby's bundled `did_you_mean` gem (`DidYouMean::SpellChecker`)
  against existing project names, scoped to the create request — no new
  Gemfile dependency, no background job, no persisted "pending project"
  state (Q7). Note: Rails 8 does not auto-require `did_you_mean`; add
  `require "did_you_mean"` in `config/application.rb` or at the controller
  where it's used. Confirm banner re-render carries the raw quick-add text +
  a hidden `force_create_project: true` field the user's second submit sets
  by clicking "Create anyway."

## Step 1 (Slice 4a) — Priority token

- `spec/lib/quick_add_spec.rb`: `p1` ->
  `priority: 3` ... `p4` -> `priority: 0`; no token -> unchanged/default;
  malformed (`p5`, `p0`) -> left as literal text, not an error (parser is
  permissive — unrecognized tokens fall through to the title, no validation
  failure for "not a token I understand").
- `QuickAdd` PORO (`app/models/quick_add.rb` or `app/lib/`): `parse(text) ->
  { title:, priority: }`. Strips the first `pN` match (N in 1..4), leaves
  everything else as title.
- Wire into create form as an *additional* field alongside the existing
  structured ones for this sub-slice only (title text input triggers the
  parse; structured priority `<select>` still present and still wins if the
  user sets both — text-parsed priority only applies when the structured
  field is left at its default). This is throwaway UI, replaced in 4d.
- `spec/requests/tasks_spec.rb`: POST with `p2` in title sets priority 2.

## Step 2 (Slice 4b) — Date/time token + recurrence-phrase rejection

- Add `chronic` to Gemfile, `bundle install`.
- `QuickAdd#parse` gains `due_date:`/`due_time:` derived from chronic's
  parse of date-shaped substrings. Extraction: scan text for tokens (priority
  `pN`, date phrases via chronic trial-parse); collect matched spans;
  residual = text minus all matched spans = title. No date and no time
  match -> both nil (Q6). **Time-presence rule (critical):** chronic fills
  hour 12:00
  for bare dates (`tomorrow`, `next monday`, `aug 20` — verified on chronic
  0.10.2); that default must NOT leak into `due_time`, or the model's
  due_time-presence rule (task.rb `compose_due_at`: due_time present ->
  `all_day=false`, due_at at that time; blank -> `all_day=true`, due_at
  beginning-of-day) would mark a bare date as a noon-timed task, contradicting
  design "no time entered is all_day: true, stored at beginning-of-day".
  Set `due_time` ONLY when the matched phrase contains an explicit time token
  chronic recognizes as **time** (not date): digit forms (`3pm`, `15:00`,
  `3:30`, `3 pm`) AND word-time forms (`noon`, `midnight`, `3 o'clock`) — e.g.
  `noon`, `wed 3pm`, `tomorrow noon` set `due_time`; a bare date phrase
  (`tomorrow`, `next monday`, `aug 20`) yields `due_date` only, `due_time: nil`.
  A bare digit (e.g. `3`, `15`) is NOT a date/time token despite chronic
  parsing it as 3pm today (`Chronic.parse("3")` -> today 15:00, verified) —
  it is ambiguous and unintentional (a typo, a count, part of a project name).
  The parser must NOT trial-parse bare digits as dates; keep them in the
  title verbatim, no `due_date`/`due_time`. Spec: `"Call dentist 3"` ->
  title `"Call dentist 3"`, no due.
  **Past-bare-time roll (verified chronic gap):** chronic returns *today* for a bare time word even when that time has passed (or is now)
  (`noon` at 16:00 -> today 12:00, `3pm` at 16:00 -> today 15:00 — both past;
  `3pm` now -> today 15:00 — equal). When the matched phrase is a **bare time
  word with no date token** and the parsed `due_at` is **earlier than OR
  equal to now**, advance `due_date` one day (keep the time) so the task
  lands tomorrow, not today-past-or-now. Only a `due_at` strictly in the
  future stays today. Phrases
  with an explicit date token (`tomorrow noon`, `wed 3pm`, `aug 20 noon`) are
  NOT rolled — the date is honored as typed. Task model derives `all_day`
  from `due_time` presence; QuickAdd does not return it.
- Regex-detect recurrence phrases *before* handing remaining text to chronic
  (chronic parses `every weekday` as a one-off date, so rejection must run
  first). Reject set: `every`/`every!` followed by a day, unit, weekday, or
  N-unit count per design's recurrence grammar (design's "frequency
  indicator" + "modifier forms"); plus the bare shorthand `weekdays`/
  `workday` (design: shorthand for `every weekday` — recurrence that does
  not start with `every`). A title merely containing "every" with no
  recurrence shape (e.g. "clean every room") is NOT rejected — anchor on the
  grammar, not bare `every\s`. Match -> raise/return a parse error the
  controller renders as a validation failure: "Recurrence not supported yet."
- `spec/lib/quick_add_spec.rb`: timed date phrase -> correct `due_date`/
  `due_time` and title extraction (e.g., input `"Call dentist wed 3pm"` ->
  `title: "Call dentist"`, `due_date:` the Wednesday, `due_time:` 15:00);
  **word-time token** -> `due_time` set (e.g. `"Call dentist noon"` ->
  `due_time:` 12:00) — `noon`/`o'clock` are explicit time, NOT dropped to
  all_day; `midnight`'s date resolution is ambiguous in chronic and is not
  specced (user won't type it; whatever chronic returns is accepted);
  **bare date phrase** -> `due_date` only, `due_time: nil` (e.g. `"Call
  dentist tomorrow"` -> `due_date:` tomorrow, `due_time: nil` -> model marks
  `all_day: true`, `due_at` beginning-of-day — the 12:00 chronic default must
  NOT appear as `due_time`); `"Call dentist next monday"` likewise all_day;
  **bare digit** -> kept in title, no due (`"Call dentist 3"` ->
  title `"Call dentist 3"`, `due_date:` nil, `due_time:` nil);
  **past-bare-time roll** -> `"Call dentist noon"` typed when now is after
  noon -> `due_date:` tomorrow, `due_time:` 12:00 (not today, which chronic
  returns in the past — verified); `"Call dentist noon"` typed at exactly
  noon -> `due_date:` tomorrow too (equal to now rolls); `"Call dentist
  noon"` typed before noon -> `due_date:` today; `"Call dentist wed noon"`
  (explicit date) -> the Wednesday's noon, NOT rolled;
  `every wednesday` / `every! 10 minutes` / `weekdays` / `workday` -> rejected,
  error surfaced; a title merely containing "every" with no recurrence shape
  (e.g. "clean every room") is NOT rejected — regex must anchor on the
  recurrence grammar design.md defines (`every day`, `every <weekday>`, `every
  N <unit>`, `every! ...`), not the bare word. `next monday` is a valid one-off
  date (chronic-parseable, verified) and must NOT be rejected; `weekdays`/
  `workday` are recurrence shorthand (design) and ARE rejected — chronic
  parses `weekdays` as a one-off date (verified), so rejecting avoids a silent
  recurrence->one-off misparse; `workday` isn't chronic-parseable but is still
  recurrence shorthand, so reject it rather than leave it as literal title.
- `spec/requests/tasks_spec.rb`: quick-add date token sets `due_at`; recurrence
  phrase -> 422/re-render with error, no task created.

## Step 3 (Slice 4c) — `#project` token + fuzzy-match confirm

- `QuickAdd#parse` gains `project_name:` (raw `#Token`, NOCASE+trim-normalized
  per slice-2 identity rule).
- Controller: normalized exact match -> use existing project. No match ->
  `suggestions = DidYouMean::SpellChecker.new(dictionary: Project.pluck(:name)).correct(name)`.
  If `suggestions.any?` (close hit found) and no `force_create_project`
  param -> re-render quick-add form with the confirm banner (title/tokens
  preserved so the user doesn't retype), offering "Use existing" (set
  `project_name:` to first suggestion and re-submit) and "Create anyway"
  (send `force_create_project=true`). If `suggestions.empty?` (no near-miss),
  or `force_create_project=true` present -> create the project.
- `spec/requests/tasks_spec.rb`: exact match reuses project; clean no-match
  (no suggestions from SpellChecker) creates it directly; near-miss
  (e.g. `#Wrok` vs existing `#Work`, suggestions = ["Work"]) re-renders with
  banner and creates nothing; resubmit with `project_name:` set to first
  suggestion creates task in the suggested project; resubmit with
  `force_create_project=true` creates `#Wrok` as its own project.
- `spec/system/task_flow_spec.rb`: happy path — type `#Work`, task lands in
  Work project. (No system-spec coverage of the confirm banner branch;
  request-spec coverage is sufficient for a server-rendered form re-render.)

## Step 4 (Slice 4d) — Field removal, quick-add becomes the only create UI

- `_form.html.erb` (create only): extract a `_quick_add_form.html.erb`
  separate from the edit form (create renders quick-add only; edit renders
  the original structured form unchanged). Remove from quick-add form:
  Project `<select>`, Due-date `date_field`/`time_field`, priority `<select>`.
  Single text input (title) + label checkboxes (Q3) + submit remain. Notes
  textarea is **dropped** from create (quick-add is a fast capture tool;
  extended detail is deferred to edit).
- Remove the throwaway parallel-field wiring from Step 1.
- `TasksController#new`/`#create`: `new` no longer needs `due_date:
  Date.current.iso8601` default (superseded, Q6/design.md note). `create`
  runs the full `QuickAdd.parse` pipeline (priority + date + project) instead
  of `task_params`'s structured fields for those three attributes; title is
  parsed from the quick-add text (residual text after token extraction),
  `label_ids` stays as direct params.
- Update/remove now-stale request specs asserting the structured create
  fields (`due_date`, `due_time`, `notes`, `project_id`, `priority` as
  direct POST params on create — edit keeps them, only create changes).
- `spec/system/task_flow_spec.rb`: full quick-add happy path — type
  `"Call dentist #Health p2 wed 3pm"`, task lands in Health project, priority
  2, dated wed 3pm, **with title "Call dentist"** (tokens extracted, title is
  residual text). Task appears in the right list view. **Bare-date variant:**
  type `"Call dentist tomorrow"` -> task is `all_day: true`, `due_at` at
  beginning-of-day (no 12:00 leak), title `"Call dentist"`. **Word-time
  variant:** type `"Call dentist noon"` -> task is `all_day: false`, `due_at`
  at noon today (or tomorrow if typed at/after noon), title `"Call dentist"` —
  the explicit `noon` time is preserved, NOT dropped to beginning-of-day.
## Step 5 — Full suite + smoke

- `bin/rspec` green, full suite.
- Rubocop clean.
- Manual: create via quick-add from Today/Upcoming/Inbox; confirm each of
  priority/date/project/recurrence-rejection/fuzzy-confirm branches by hand
  once; confirm edit still uses the untouched structured form (Q4).

## Done when

- Create form is a single quick-add text field (+ label checkboxes).
- `p1..p4`, date/time phrases, and `#project` all parse correctly, translate
  per the locked mappings, and combine in one submission.
- `every`/`every!` phrases are rejected with a clear error, not silently
  absorbed or half-applied.
- `#project` near-misses trigger a confirm banner; exact/no-match matches
  don't.
- No date token and no time token -> task is undated (no silent default).
- Edit form, `@label` handling, and recurrence itself are all unchanged from
  slice 3 — this slice doesn't touch them.
- Full suite green, Rubocop clean.

## Rework / merge cost this slice imposes on later slices

- **Slice 5 (recurrence)** removes the `every`/`every!` rejection added in
  Step 2 and replaces it with real parsing — same regex-detection surface,
  different handler. Named in design.md's existing rework table entry for
  slice 5 replacing "next occurrence" logic; this adds one more touch point
  (the quick-add parser) to that same rework.
- **A future `@label` quick-add slice** re-opens `QuickAdd#parse` and the
  Step 4 form partial to add `@token` parsing and (per this slice's Q3 note)
  decide its own auto-create semantics — deferred, not designed here.
