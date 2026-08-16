# my-todoist

My LLM coded clone of todoist.

Local single-user Todoist clone. Rails 8, SQLite, builtin ERB views, RSpec.
See `specs/` for the design, estimates, and per-slice implementation plans.

## Scope

This app runs on one machine, for one user, and never faces the network.
No authentication, no authorization, and no other security controls are
required. Do not add them. Keep the framework surface small: the app loads
only Active Record, Action Controller, Action View, and Active Model. Do not
add Active Job, Solid Queue, Active Storage, Action Mailer, Action Cable, or a
deployment stack unless a real feature needs it. Slice 6's due reminders are
client-side (a JS poll shows in-page toasts); no background job stack.

## How to Run

Requirements: Ruby 3.4 (see `.ruby-version`). No Node — assets use Propshaft
plus Importmap.

First time:

```
bundle install
bin/rails db:prepare
```

Start the app:

```
bin/rails server
```

Open <http://localhost:3000>. The app is single-user and needs no login.

## Recurrence

Recurring tasks use a small text grammar, parsed by `Recurrence.parse`
(`app/models/recurrence.rb`):

```
every(!)? (count)? unit
```

- `every` schedules the next occurrence from the original due date, in whole
  intervals, preserving phase (never resets to now). `every!` (rolling)
  schedules from the completion time instead.
- `unit` is one of: `day(s)`, `week(s)`, `month(s)`, `year(s)`, `hour(s)`,
  `minute(s)`; a weekday name (`monday`..`sunday`, plural accepted); or
  `weekday`/`workday` (next business day, skipping Saturday/Sunday).
- `count` is optional and defaults to 1. It accepts:
  - a plain number (`every 3 days`)
  - a digit-suffix ordinal (`every 2nd monday`, `every 21st day`)
  - a word ordinal, `first` through `twentieth` (`every third week`)
  - `other`, sugar for count 2 (`every other monday`)
- On weekday-name and business-day units, `count` steps that many
  occurrences per advance (`every 3 monday` skips two Mondays each cycle;
  `every! other monday` lands on the second Monday from now).
- `every month` / `every N months` lands on the 1st of the target month,
  discarding day-of-month (no short-month clamping drift).

Examples: `every day`, `every 3 days`, `every other monday`,
`every! third monday`, `every 2 weekday`, `every! month`.

## Test

```
bin/rspec
```
