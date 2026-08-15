# my-todoist — Tech Decisions

Cross-cutting technical/library/architecture decisions that apply across
slices. Feature-level design lives in `specs/design.md`; per-slice
implementation detail lives in `specs/slice-N-plan.md`. This doc is the
place decisions land when they're a standing rule, not a one-slice detail.

## Stack

- Rails 8, Ruby. SQLite3 (dev + "prod" are same local DB).
- Views: builtin ERB. Assets: Propshaft + Importmap (no Node build).
- CSS: **Bulma** (pure-CSS drop-in via importmap/vendored stylesheet).
- Jobs: Solid Queue (SQLite-backed) — added slice 6 when notifications need a
  scheduler; not present before then (removed from slice 1 as unused).
- Tests: rspec-rails.
- Date NLP: `chronic` gem (one-off dates, slice 4). Recurrence (slice 5):
  custom parser (PORO), no gem.
- Fuzzy string matching (slice 4, `#project` typo detection): Ruby's bundled
  `did_you_mean` gem (`DidYouMean::SpellChecker`) — no new dependency.
- No auth. Single user. Local `bin/dev`.

## Standing rules

- **Server-rendered Ruby is the default; JS is a tiebreaker loss, not a ban.**
  Given roughly equal implementation cost, choose server-side rendering over
  client-side JS (established slice 1: "no-JS complete control"; reaffirmed
  slice 4 grill, 2026-08-15). This is a *preference between comparable
  options*, not an absolute constraint — don't contort a design to avoid JS
  when JS is genuinely the simpler or more correct tool for a given piece of
  interactivity. When the two approaches are close, ship the ERB version.
- **New dependencies climb the ladder before landing**: stdlib/bundled-gem
  first (`did_you_mean`), then an already-used gem's capability, only then a
  new gem (`chronic` — justified because Ruby has no good NLP date parser in
  stdlib). Don't add a gem for what a few lines of Ruby can do.
- **SQLite throughout** — dev and "prod" are the same local DB file; no
  Postgres/MySQL migration is planned (single-user local app).
- **`NULLS LAST` ordering** (`Task.ordered` scope, `Arel.sql("due_at ASC
  NULLS LAST, created_at DESC")`) is the standing pattern for any future
  nullable-sort-key scope — SQLite-specific syntax, noted here so it isn't
  reinvented per-slice.

## Deferred tech (named, not adopted)

- Node/JS build pipeline — Importmap covers current needs; revisit only if a
  future slice genuinely needs a JS package with no CDN/vendor-able form.
- Postgres/MySQL — single-user local app has no multi-writer or hosting
  driver forcing this; SQLite stays.
