# CLAUDE.md (app/controllers)

## Purpose
HTTP entry points. Each controller maps one resource to its views.

## Files
- `application_controller.rb`: base class. Includes the `Authentication` concern.
- `tasks_controller.rb`: task lists (index, completed, today, overdue, upcoming, search), create, update, complete, skip, and reschedule. Largest controller.
- `completed_occurrences_controller.rb`: `show` for one completed occurrence.
- `labels_controller.rb`: label CRUD.
- `projects_controller.rb`: project CRUD.
- `sessions_controller.rb`: login (`new`, `create`) and logout (`destroy`).
- `concerns/`: see `concerns/CLAUDE.md`.

## Rules for agents
- Every controller requires login. Opt out with `allow_unauthenticated_access`. Only sessions controller opts out.
- JSON requests get 401, not a redirect.
- Redirect targets must use `safe_return_to` (see `tasks_controller.rb`). A missing `return_to` falls back to Inbox silently.
- Route due-date writes through `Task` setters. Do not set `due_at` here.

## Verification
- `bin/rspec spec/requests`
- `bin/rubocop`
