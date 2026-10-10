# Auth for internet deploy - grill

Request: add authentication so app can deploy on internet without bad actors getting in.

## Context found
- No auth today. `specs/tech.md:21`: "No auth. Single user. Local `bin/dev`."
- CLAUDE.md: auth/authz/security out of scope; local-only, single user. Request changes this premise.
- `bcrypt` commented out in Gemfile. Frameworks: AR, AC, AV, AM only.
- JS polls `fetch(...)` (notifications.js:34, :79) - must work behind auth.
- `OsNotificationsController` -> `OsNotifier.notify` fires OS notification on host. On remote server: useless, maybe unsafe.
- `bin/create-backup.sh` exists for SQLite backups.

## Decisions

1. Gate layer: in-app auth (Rails). Network gate (Tailscale/Cloudflare Access) rejected by user.
2. Identity: Rails 8 auth generator (User email+password, Session table, login rate limit). Remove password reset + mailer. Create the one user via rake task/console. Reset password via console. (2026-10-10: superseded by `bin/rails user:modify EMAIL=... PASSWORD=...`, which also ends every login.)
3. TLS: nginx terminates TLS in front of Rails. Production sets `config.assume_ssl = true` + `config.force_ssl = true` (secure cookies, HSTS). nginx must send `X-Forwarded-Proto https`.
4. Scope: all routes require login (generator `Authentication` concern in ApplicationController). Only login page public. `OsNotifier` no-op on Linux server - no change.
5. Session TTL: generator default (permanent signed cookie, Session row until logout). Revoke by deleting Session rows.
6. Brute force: keep generator `rate_limit` (10/3min per IP). Add nginx `limit_req` on `POST /session` in deploy doc. nginx must send `X-Forwarded-For`; nginx on localhost is a trusted proxy by default, so `request.remote_ip` = client IP.
7. Docs premise: update CLAUDE.md + specs/tech.md - single user, internet-exposed behind nginx + login; auth/security in scope, multi-user out.

Own decisions (not asked):
- `config.hosts` from `APP_HOST` env var in production (blocks Host-header attacks).
- Signed-in spec helper (`sign_in_as`) in `spec/support`, used by all request/system specs.
- Login page uses existing layout; navbar gets a "Log out" button.

## Slices

Sliced: 3 slices. S1 and S2 run in parallel; S3 after both.

### S1 - Login wall (app)
- `bin/rails generate authentication`; uncomment `bcrypt`.
- Delete `PasswordsController`, its views, `PasswordsMailer`, mailer routes. No Action Mailer.
- `lib/tasks/user.rake`: `user:create EMAIL=... PASSWORD=...`.
- `sign_in_as` helper; update request/system specs to sign in. New specs: unauthenticated GET/POST -> redirect to login; JS `fetch` endpoints (`due_since`, `os_notification`) -> redirect/401 when logged out; login rate limit.
- Navbar "Log out".
- Value: app safe to expose on any HTTPS host.

### S2 - Production hardening + deploy doc
- `config/environments/production.rb`: `assume_ssl`, `force_ssl`, `config.hosts = [ ENV.fetch("APP_HOST") ]`.
- `design/deploy-nginx.md`: nginx server block (TLS, `X-Forwarded-Proto`, `X-Forwarded-For`, `limit_req` on `POST /session`), `SECRET_KEY_BASE` (no `config/master.key` exists, so `RAILS_MASTER_KEY` has nothing to decrypt), `db:prepare`, `bin/create-backup.sh` cron.
- Value: correct HTTPS behind nginx. Deployable alone (no code paths change in dev/test).

### S3 - Docs premise
- CLAUDE.md, specs/tech.md, README.md, and `.okf/` (single-user-scope decision, decisions index, architecture) per decision 7. Details: design/s3-plan.md.
- After S1 and S2 so docs match the code and `design/deploy-nginx.md` exists.

## Conflicts / rework
- C1: S1 + S2 both touch `config/` (S1: routes; S2: production.rb). Different files - no textual conflict. 0.
- R1: S1 changes sign-in for every existing request/system spec. A global `before` hook in rails_helper covers them, so no per-file edits. trivial, 0.5 point.
- C2: S1 and any in-flight branch (e.g. `schedule-next-week-button`) both edit request specs - merge conflict on spec setup lines. trivial, 0.5.

Deferred edge cases: password reset by email, session idle expiry, multi-user, 2FA.

## Unresolved questions
- (resolved) `APP_HOST` = `unixgeek.com`.
- (resolved) Merge `schedule-next-week-button` before S1 - done.
