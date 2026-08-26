# CLAUDE.md

Goal: work in this Rails app the way its existing patterns already work.

Success means:
- `bin/rspec` and `bin/rubocop` pass on every change
- New grammars follow the `extract_*!` pattern in `quick_add.rb`
- Scope stays local-only: single machine, single user

Stop when: tests are green, lint is clean, and the change fits the patterns
below.

## App

Local single-user Todoist clone. Rails 8.1, Ruby 3.4, SQLite, ERB, RSpec.
Wholly LLM-coded — follow this file and `specs/` as the style reference.
Single machine, single user, no network exposure: treat auth/authz/security
work as out of scope for this app. Load only Active Record, Action
Controller, Action View, and Active Model; add another Rails framework
(Active Job, Solid Queue, Active Storage, Action Mailer, Action Cable) only
when a specific feature needs it. Keep due reminders client-side (a JS
poll shows in-page toasts) unless a feature requires a background job.
Serve assets via Propshaft + Importmap; this project has no Node tooling.

## Commands

| Command | Purpose |
|---|---|
| `bundle install && bin/rails db:prepare` | first-time setup |
| `bin/rails server` | run app (localhost:3000) |
| `bin/rspec` | full suite |
| `bin/rspec spec/lib/quick_add_spec.rb` | single file |
| `bin/rspec spec/lib/quick_add_spec.rb:42` | single example |
| `bin/rubocop` | lint (omakase) |
| `bin/rubocop -A` | lint + autocorrect |
| `bin/brakeman` | security scan |
| `bin/bundler-audit` | dependency vuln scan |

Run `bin/rubocop` and `bin/rspec` locally before finishing — `.github/` has
only `dependabot.yml`, so no CI runs them for you.

## Architecture

Three grammars parse free text into structured data. Each lives in its own
class and computes independently of ActiveRecord:

- **`app/models/quick_add.rb`** (`QuickAdd.parse`): title ->
  `{ title:, priority:, due_date:, due_time:, project_name:, recurrence: }`.
  Run a fixed sequence of `extract_*!` methods; each mutates the title
  string in place and returns its own piece of data. Order matters —
  later extractors scan whatever text earlier ones left behind. Guard
  each extractor against overwriting an earlier result (see `date_span`,
  which runs `if !due_date`). To add a grammar: define a regex constant,
  write a `private_class_method` extractor, wire it into `self.parse`,
  and document the wiring point inline.
- **`app/models/recurrence.rb`** (`Recurrence.parse` / `#next_from`):
  parses the `every(!)? (count)? unit` grammar (see README for examples).
  Fixed recurrence steps forward in whole intervals from the original due
  date, preserving phase. Rolling recurrence (`!`) steps from completion
  time. Treat this as pure computation — no DB, no state; `Task#complete!`
  calls it.
- Reach for Chronic (the gem) only inside `quick_add.rb`'s `date_span`, for
  free-text date/time phrases ("next monday", "3pm"). Give the recurrence
  and `in X unit` grammars their own regex and duration math instead —
  see `specs/in-x-unit-design.md` for the reasoning.

Route all due-date writes through `Task` (`app/models/task.rb`): set
`due_date=`/`due_time=` (virtual setters), and let `compose_due_at`
(`before_validation`) combine them into `due_at` and derive `all_day`
(true when no time was given). Check `due_time` for `nil` to detect an
all-day due date — midnight is a valid clock time, not a signal by itself.

Read `specs/` (not `spec/`, the RSpec suite) for design docs, slice plans,
and grill Q&A before changing a grammar; each new grammar gets its own
`<feature>-grill.md` + `<feature>-design.md` pair. Skip work estimates —
this project has no team to size work for.

## Conventions

- Write array literals with interior spaces: `[ a, b ]`, per
  `Layout/SpaceInsideArrayLiteralBrackets`.
- Write a failing spec first for every code change (TDD), then make it
  pass.

## Miscellaneious Notes

- There is no Jira tracking, so any PR's created should not worry about Jira
  ticket, team, or parent.
