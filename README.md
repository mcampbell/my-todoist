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

To put it on the internet, see [Deployment](#deployment).

## Deployment

### Development (your own machine)

No environment variables needed. Runs at the root path, plain HTTP:

```
bundle install
bin/rails db:prepare
 bin/rails user:create EMAIL=you@example.com PASSWORD='12+ chars'
bin/rails server            # http://localhost:3000
```

### Production behind nginx at `{HOST}/todo`

The app runs with `rails s -p 3500` in a tmux session on the host. nginx
(already serving `{HOST}` over HTTPS) forwards `{HOST}/todo` to port 3500. Replace `{HOST}` with your
host name (for example `unixgeek.com`) everywhere below.

**1. Environment file.** Create `/etc/my-todoist.env` (`chmod 600`, owned
by the user that runs the app):

```sh
RAILS_ENV=production
APP_HOST={HOST}
RAILS_RELATIVE_URL_ROOT=/todo
SECRET_KEY_BASE=<output of: bin/rails secret>
```

- `APP_HOST` must equal the host name browsers use. Rails answers 403
  to any other `Host` header, and refuses to boot when it is unset.
- `RAILS_RELATIVE_URL_ROOT=/todo` makes every link, form, asset, and JS
  request start with `/todo`. Without it, the app serves `/` and nothing
  under `/todo` works.
- `SECRET_KEY_BASE` signs the login cookie. Keep it stable: a new value
  logs you out.

**2. First-time setup** (in the app directory):

```sh
set -a; . /etc/my-todoist.env; set +a
bundle config set without "development test"
bundle install
bin/rails db:prepare
bin/rails assets:precompile
 bin/rails user:create EMAIL=you@example.com PASSWORD='12+ chars'
```

The leading space keeps the password out of shell history (bash with
`HISTCONTROL=ignorespace`).

**3. Start the app in tmux:**

```sh
tmux new -s todo
cd /path/to/my-todoist
set -a; . /etc/my-todoist.env; set +a    # RAILS_ENV=production etc.
rails s -p 3500
```

Detach with `Ctrl-b d`. Reattach with `tmux attach -t todo`. tmux does not
survive a reboot: start it again after one.

- Load the env file first. Without `RAILS_ENV=production`, `rails s`
  starts in development, which rejects the `{HOST}` host name.
- **Close port 3500 to the internet.** In production, `rails s` listens on
  every network interface, so anyone can reach `http://{HOST}:3500`
  directly. That skips TLS (the password crosses the network in clear
  text) and skips nginx's login limit. Do one of these:
  - block the port: `sudo ufw deny 3500` (or your firewall's equivalent)
  - or listen on loopback only: `rails s -p 3500 -b 127.0.0.1`

**4. nginx changes.** Your nginx already forwards `{HOST}/todo` to port 3500.
Check that block, add a login rate limit, then reload.

a. **Check the existing `/todo` location** (inside the `server { ... }`
   block for `{HOST}`, the one with `listen 443 ssl`). It must look like
   this; change any line that differs:

   ```nginx
   location = /todo { return 301 /todo/; }

   location /todo/ {
       proxy_pass http://127.0.0.1:3500;
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

   | Line | Why | Symptom when wrong |
   |---|---|---|
   | `proxy_pass http://127.0.0.1:3500;` — **no** path after the port | nginx passes `/todo/...` unchanged; the app expects the prefix | trailing `/` (or `/todo/`) strips the prefix: 404s or links without `/todo` |
   | `proxy_set_header Host $host;` | Rails accepts only `APP_HOST` | 403 "Blocked hosts: 127.0.0.1" in the Rails log |
   | `X-Forwarded-For` | real client IP for Rails' login limit | every client shares one limit (nginx's IP) |
   | `X-Forwarded-Proto` | tells Rails the request was HTTPS | harmless today (Rails assumes HTTPS); keep it |

b. **Add the login rate limit** (optional, recommended). The zone must be
   in the `http` context, so put it in its own file,
   `/etc/nginx/conf.d/my-todoist.conf`:

   ```nginx
   limit_req_zone $binary_remote_addr zone=todo_login:10m rate=5r/m;
   ```

   Then add this next to the `/todo/` location from step a:

   ```nginx
   # Login form POST: slow down password guessing.
   location = /todo/session {
       limit_req zone=todo_login burst=5 nodelay;
       proxy_pass http://127.0.0.1:3500;
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

   Rails also limits logins (10 tries per 3 minutes per IP); this stops
   floods before they reach Rails.

c. Test and reload:

   ```sh
   sudo nginx -t && sudo systemctl reload nginx
   ```

**5. Check:**

```sh
curl -sI https://{HOST}/todo/ | grep -i -E '^HTTP|^location'
# HTTP/2 302, location: https://{HOST}/todo/session/new
```

Then open `https://{HOST}/todo/` and sign in.

**Good to know:**

- The app sends HSTS for `{HOST}` (browsers then use HTTPS only for that
  host, for 2 years). Subdomains are not affected. Every site on `{HOST}`
  itself must already be HTTPS-only.
- HTTP to HTTPS redirects are nginx's job. Rails assumes every request
  arrived over HTTPS.
- Login lasts until you log out. There is no email password reset. To
  reset: `bin/rails runner 'User.first.update!(password: ENV.fetch("PASSWORD"))'`
  with the env file loaded and `PASSWORD` set.

**Update to a new version:**

```sh
tmux attach -t todo        # Ctrl-c to stop the server
git pull
bundle install
bin/rails db:migrate
bin/rails assets:precompile
rails s -p 3500
```

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
