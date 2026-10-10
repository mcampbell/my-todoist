# my-todoist

My LLM coded clone of todoist.

Single-user Todoist clone. Rails 8, SQLite, builtin ERB views, RSpec.
See `specs/` for the design, estimates, and per-slice implementation plans.

## Scope

This app serves one user. It can face the internet behind nginx (TLS) and
a login wall; see `design/deploy-nginx.md`. Multi-user support and
authorization are out of scope. Keep the framework surface small: the app loads
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

Create the one login user (12+ character password), then open
<http://localhost:3000> and sign in:

```
 bin/rails user:create EMAIL=you@example.com PASSWORD='...'
```

To deploy on the internet behind nginx, follow `design/deploy-nginx.md`.

## Features

- **Login.** Every page needs a login, except the sign-in form. One user,
  created with `user:create`. The navbar has a "Log out" button. To reset
  the password, use `bin/rails runner`; there is no email reset. Login
  tries are rate-limited.
- **Views** (navbar): Inbox, Today, Overdue, Upcoming, Completed, Search,
  and one view per project. Overdue rows show red. A new task always
  lands on Today.
- **Task row buttons:**
  - checkbox: complete (a recurring task moves to its next date)
  - skip: skip this occurrence
  - **P**: mark in progress (grey row, sorted to the top); press again to clear
  - **T**: schedule tomorrow
  - **W**: schedule next week
  - edit, delete
- **Edit form:** "Reschedule to" takes the same phrases as quick add
  (`tomorrow`, `next wed`, `in 2 months`, ...).
- **Projects and labels:** create, rename, and delete them from "Manage
  projects" and "Manage labels". `#name` in quick add creates a project.
  If the name is close to an existing one, the app asks "Did you mean ...?".
- **Completed:** lists finished occurrences, each with a details page.
- **Keyboard:** `q` new task, `/` search, `Esc` cancel (on the new-task
  and search pages).
- **Due reminders:** an open tab checks every 30 seconds. A due task shows
  an in-page toast with a beep. The app also tries an OS notification on
  macOS or WSL, and does nothing elsewhere (for example, a Linux server).
  You get no reminder unless a tab is open.
- **Midnight refresh:** the page reloads at midnight, so date views roll over.

## Quick add

The quick-add box parses one line of free text into a task
(`app/models/quick_add.rb`). Unrecognised words stay in the title, so you
can always just type a plain title. Tokens may appear in any order.

From simplest to most complex:

| You type | Title | What else it sets |
|---|---|---|
| `Buy milk` | Buy milk | — |
| `Submit report p1` | Submit report | priority (`p1` urgent … `p4` none) |
| `Call plumber #home` | Call plumber | project `home` (created if new) |
| `Pack bags 9am` | Pack bags | time today (rolls to tomorrow once 9am passes) |
| `Dentist tomorrow` | Dentist | all-day date |
| `Standup friday 9:30am` | Standup | date + time |
| `Renew licence in 2 weeks` | Renew licence | date = today + 2 weeks (`in <n> days/weeks/months/years/hours/minutes`, or `in a week`) |
| `Plan trip next month` | Plan trip | date = one month from today (`next week` / `next month` / `next year`) |
| `Ship 10/15/2026` | Ship | date (`MM/DD/YYYY` or `MM-DD-YYYY`, one separator per date) |
| `Ship 15-aug-2026` | Ship | date (day-month-year with a month name) |
| `Pay rent the 24th` | Pay rent | the next 24th of a month |
| `Board meeting first monday in june` | Board meeting | the next such date (rolls a year if it has passed) |
| `Taxes 3rd friday in april at 5pm` | Taxes | anchored date + time |
| `File report #work p2 next tuesday 4pm` | File report | project, priority, date and time together |

### Recurring tasks

| You type | Recurrence | First occurrence |
|---|---|---|
| `Water plants every day` | `every day` | today |
| `Bins every! day` | rolling — next is scheduled from when you complete it | today |
| `Pay rent every month` | `every month` (every 30 days, not the calendar 1st) | today |
| `Team sync every monday` | `every monday` | the next Monday (on or after today) |
| `Sprint demo every 2 fridays` | every second Friday | the next Friday |
| `Payroll every weekday` | every business day (skips Sat/Sun) | the next business day |
| `Newsletter every third thursday in june` | yearly, 3rd Thursday of June | the next such date |
| `Anniversary every sep 20` | yearly on 20 September | the next 20 September |

### Recurring tasks with a start date

Add `starting [on] <date>` or `starting in <n> <unit>` to say when the
series should begin. The first occurrence is the first date the rule
allows **on or after** your start date; the rule itself is unchanged. A
recurring task may only get its first date this way — a bare date with no
`starting` is rejected.

| You type | First occurrence |
|---|---|
| `Gym every monday starting in 2 days` | first Monday on or after today + 2 days |
| `Book club every wednesday starting feb 20` | first Wednesday on or after 20 February |
| `Review every 3 thursdays, starting on wed` | anchor = the next Wednesday; then the first Thursday on or after it; then every third Thursday |
| `Standup every monday in 3 days` | rejected — write `starting in 3 days` |

## Recurrence

Recurring tasks use a small text grammar, parsed by `Recurrence.parse`
(`app/models/recurrence.rb`):

```
every(!)? (count)? unit
```

- `every` schedules the next occurrence from the original due date, in whole
  intervals, preserving phase (never resets to now). `every!` (rolling)
  schedules from the completion time instead.
- `unit` is one of: `day(s)`, `week(s)`, `month(s)`, `quarter(s)`,
  `year(s)`, `hour(s)`, `minute(s)`; a weekday name (`monday`..`sunday`,
  plural accepted); or `weekday`/`workday` (next business day, skipping
  Saturday/Sunday). `quarter(s)` is sugar for 3 months (`every 2 quarters`
  == `every 6 months`).
- `count` is optional and defaults to 1. It accepts:
  - a plain number (`every 3 days`)
  - a digit-suffix ordinal (`every 2nd monday`, `every 21st day`)
  - a word ordinal, `first` through `twentieth` (`every third week`)
  - `other`, sugar for count 2 (`every other monday`)
- On weekday-name and business-day units, `count` steps that many
  occurrences per advance (`every 3 monday` skips two Mondays each cycle;
  `every! other monday` lands on the second Monday from now).
- `every month` / `every N months` is a flat count*30-day interval from
  the anchor, same as day/week/year units (no calendar-month anchoring).

Examples: `every day`, `every 3 days`, `every other monday`,
`every! third monday`, `every 2 weekday`, `every! month`.

## Test

```
bin/rspec
```
