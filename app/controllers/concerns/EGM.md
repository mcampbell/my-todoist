# Controller Concerns

## Overview

Holds `Authentication`, the Rails 8 generator login concern. `ApplicationController` includes it, so every controller requires a login session.

## Interface

- `Authentication` (`authentication.rb`): adds `before_action :require_authentication` and the helper `authenticated?`.
- `allow_unauthenticated_access(**options)`: class method. Skips the login check for the named actions.
- Private methods for controllers: `start_new_session_for(user)`, `terminate_session`, `after_authentication_url`, `resume_session`.

## Invariants

- A JSON request without a session gets `401`, not a redirect. The reminder poll must never become the post-login destination.
- Only a GET request is stored as the return target after login.
- The session cookie is `todo_session_id`: signed, permanent, `httponly`, `same_site: :lax`, and `secure` in production.
- This app has no password reset by email. Use `bin/rails user:modify` (see `../../../lib/tasks/EGM.md`).

## Side Effects

- Reads and writes the `sessions` table and the signed `todo_session_id` cookie.
- Sets `Current.session`.

## Verification

- Run: `bin/rspec spec/requests/authentication_spec.rb spec/system/login_flow_spec.rb`
