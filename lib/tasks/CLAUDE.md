# lib/tasks/

## Purpose
Rake tasks for the single login user.

## Files
- `user.rake` - `user:create` (EMAIL, PASSWORD) makes the user. `user:modify` changes the password and destroys all sessions in one transaction.
- `.keep` - placeholder.

## Rules for agents
- Read inputs with `ENV.fetch`. A missing var must raise.
- Keep `user:modify` transactional: password change and `sessions.destroy_all` stand or fall together.
- Never print the password.
- Run the tasks with a leading space in the shell, to keep the password out of history.

## Verification
- `bin/rails user:create EMAIL=... PASSWORD=...` (dev DB only)
- `bin/rails user:modify EMAIL=... PASSWORD=...`
- `bin/rspec`
- `bin/rubocop`
