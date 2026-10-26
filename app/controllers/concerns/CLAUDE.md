# CLAUDE.md (app/controllers/concerns)

## Purpose
Shared controller behavior: login gate and session handling.

## Files
- `authentication.rb`: `Authentication` module. Adds `before_action :require_authentication`. Provides `allow_unauthenticated_access`, `authenticated?`, `start_new_session_for(user)`, `terminate_session`, and cookie lookup (`find_session_by_cookie`).

## Rules for agents
- Do not remove the `before_action`. It guards every controller.
- Opt out per action with `allow_unauthenticated_access`. Use it for public actions only.
- Session rows are the source of truth. `user:modify` deletes them to end all logins.

## Verification
- `bin/rspec spec/requests`
- `bin/rubocop`
