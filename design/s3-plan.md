# S3 - Docs premise: implementation plan

Parent: design/auth.md (decision 7). Start after S1 and S2 merge (docs must
match code; tech.md links S2's deploy doc). Docs only - no spec needed (TDD rule covers code changes).

## Steps

1. **`CLAUDE.md`**:
   - Line 8 success bullet: "Scope stays local-only: single machine,
     single user" -> "Scope: single user, one server, exposed to the
     internet behind nginx + login".
   - Line 15: "Local single-user Todoist clone" -> "Single-user Todoist
     clone". (`specs/design.md:3` stays: dated original design record.)
   - Line 17 paragraph: replace "Single machine, single user, no network
     exposure: treat auth/authz/security work as out of scope" with:
     single user, internet-facing behind nginx (TLS) and a login wall;
     auth and security are in scope; multi-user/authz stays out of scope.
   - Add to Architecture: all controllers require login via the
     `Authentication` concern; public actions opt out with
     `allow_unauthenticated_access`. Specs sign in by default
     (`spec/support/authentication_helpers.rb`); tag `:signed_out` to opt out.
   - Add Commands row: `bin/rails user:create EMAIL=... PASSWORD=...`.
   - Framework list: unchanged (no mailer added).

2. **`specs/tech.md`** line 21: "No auth. Single user. Local `bin/dev`."
   -> "Auth: Rails 8 generator (email + password, DB sessions), no
   password reset. Single user. Deployed behind nginx; see
   design/deploy-nginx.md."

3. **`README.md`**:
   - Line 5: drop "Local".
   - Lines 10-11: replace "runs on one machine ... never faces the
     network. No authentication ..." with single user, login required,
     deploy behind nginx (link design/deploy-nginx.md).
   - Line 36: "needs no login" -> create a user with
     `bin/rails user:create EMAIL=... PASSWORD=...`, then log in.

4. **`.okf/` bundle** (OKF skill; run `okf:validate` after):
   - `.okf/decisions/single-user-scope.md`: retitle "Single-user scope,
     login required"; rewrite lines 4 and 11-12 - auth in scope,
     multi-user/authz out. Note the decision changed 2026-10-10 and why
     (internet deploy).
   - `.okf/decisions/index.md:3`: match new title/summary.
   - `.okf/architecture/my-todoist-app.md:4,6,12-16`: drop "local",
     "no auth", "no network exposure"; say single user behind nginx +
     login.

5. **Verify** - reread each edited section against S1 code (helper names,
   rake task name). `bin/rubocop` unaffected.

## Files touched
CLAUDE.md, specs/tech.md, README.md,
.okf/decisions/single-user-scope.md, .okf/decisions/index.md,
.okf/architecture/my-todoist-app.md.

## Done when
No doc says "no auth" or "out of scope" for security; docs name the
login concern, spec helper, and rake task as built in S1.
