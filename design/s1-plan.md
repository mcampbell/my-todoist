# S1 - Login wall: implementation plan

Parent: design/auth.md (decisions 1, 2, 4, 5, 6). Branch from latest `main`.
TDD: write each failing spec before its code.

## Steps

1. **Failing specs first** - `spec/requests/authentication_spec.rb`:
   - Signed out: `GET /` -> redirect to `new_session_path`.
   - Signed out: `GET /tasks/due_since.json` -> not 200 JSON (redirect).
   - Signed out: `POST /os_notification` -> redirect, `OsNotifier.notify` not called.
   - `POST /session` good creds -> redirect to root; then `GET /` 200.
   - `POST /session` bad creds -> redirect to login with alert, no session.
   - `DELETE /session` -> session row gone, `GET /` redirects.
   - Rate limit: 11th `POST /session` within 3 min -> "Try again later".
     `rate_limit` binds its store at class load, so a per-example
     `Rails.cache` swap does nothing. Set `config.cache_store =
     :memory_store` in `config/environments/test.rb` and add
     `config.before { Rails.cache.clear }` in `rails_helper.rb` - the
     clear also stops the global sign-in hook (step 7) from tripping the
     limit across examples.
   - `spec/system/login_flow_spec.rb` (rack_test): visit `/` -> login form;
     fill in, submit -> Inbox; click "Log out" -> login form.
   - `spec/lib/tasks/user_rake_spec.rb` (or similar): `user:create` creates a
     User; fails loudly without EMAIL/PASSWORD.

2. **Generator** - `bin/rails generate authentication`.
   - Uncomments/adds `bcrypt` in Gemfile; `bundle install`.
   - Creates `User`, `Session`, `Current`, `SessionsController`,
     `concerns/authentication.rb`, migrations, `sessions/new` view,
     `include Authentication` in `ApplicationController`.
   - `bin/rails db:migrate`; commit `db/schema.rb`.

3. **Remove password reset** (Action Mailer not loaded - decision 2):
   - Delete `PasswordsController`, `app/views/passwords/`. Generator
     skips mailer files when Action Mailer is not loaded; delete any
     that appear anyway.
   - Remove `resources :passwords` from routes.
   - Remove "Forgot password?" link from `sessions/new`.
   - Check: `bin/rails zeitwerk:check` passes (no dangling mailer constant).

4. **Login page** - restyle `sessions/new` with existing Bulma classes
   (match `tasks/new` form markup). Uses `application` layout. Hide the
   navbar when `!authenticated?` (navbar queries `Project`, fine either way,
   but links are useless before login).

5. **Log out** - navbar: `button_to "Log out", session_path, method: :delete`
   at the bottom of `_navbar.html.erb`, inside its own `menu-list`.

6. **Rake task** - `lib/tasks/user.rake`:
   `user:create` reads `ENV.fetch("EMAIL")`, `ENV.fetch("PASSWORD")`,
   `User.create!`. Raise on missing env or invalid record (fail loud).

7. **Spec sign-in helper** - create `spec/support/authentication_helpers.rb`;
   uncomment the `spec/support` glob in `rails_helper.rb`.
   - `sign_in_as(user)`: request specs -> `post session_path, params: {
     email_address:, password: }`; system specs -> visit login, fill, submit.
   - Global hooks: `config.before(type: :request)` and
     `config.before(type: :system)` create one user and sign in, unless
     example has `:signed_out` metadata.
   - Hooks key on `type:` metadata; `infer_spec_type_from_file_location!`
     is off, so every new spec declares `type: :request` / `type: :system`
     (existing specs already do).
   - Result: existing request/system specs need no edits (shrinks R1).
     `authentication_spec.rb` / `login_flow_spec.rb` tag `:signed_out`.

8. **JS polls** - no change. Signed out, `fetch("/tasks/due_since.json")`
   follows the redirect to HTML; `response.json()` throws; existing
   `catch` logs it. `notifyOs` already ignores failures.
   ponytail: noisy console when signed out; add JSON 401 in
   `request_authentication` if it bothers.

9. **Verify** - `bin/rspec`, `bin/rubocop`, `bin/brakeman`.
   Manual: `bin/rails user:create EMAIL=... PASSWORD=...`, `bin/rails s`,
   log in/out in browser, toasts still fire when signed in.

## Files touched
Gemfile, Gemfile.lock, config/routes.rb, db/migrate/*, db/schema.rb,
app/models/{user,session,current}.rb, app/controllers/application_controller.rb,
app/controllers/sessions_controller.rb, app/controllers/concerns/authentication.rb,
app/views/sessions/new.html.erb, app/views/layouts/{application,_navbar}.html.erb,
lib/tasks/user.rake, config/environments/test.rb, spec/rails_helper.rb,
spec/support/authentication_helpers.rb, new specs above.
Deleted (generated then removed): app/controllers/passwords_controller.rb,
app/views/passwords/.

## Done when
All routes except `GET/POST /session` need login; specs + rubocop green;
no mailer code remains.

## Unresolved
- Hide navbar on login page, or show it? (plan: hide)
