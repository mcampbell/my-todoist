# Controllers

## Overview

HTML controllers for tasks, projects, labels, completed occurrences, and the login session. Each controller inherits from `ApplicationController`. Routes are in `config/routes.rb`.

## Interface

- `ApplicationController`: includes `Authentication`. Allows modern browsers only.
- `SessionsController`: `new`, `create`, `destroy`. The only actions open without login are `new` and `create`. `create` has a rate limit: 10 tries in 3 minutes.
- `TasksController`: `index`, `new`, `create`, `edit`, `update`, `destroy`, member `complete`, `complete_with_notes`, `skip`, and collection `today`, `upcoming`, `overdue`, `completed`, `search`, `due_since`.
- `ProjectsController`, `LabelsController`: CRUD without `show`.
- `CompletedOccurrencesController`: `show` only.
- `concerns/`: see [concerns](./concerns/EGM.md).

## Scripted Access

Every route except the login form (`GET /session/new`, `POST /session`) needs a login session. A script uses the same login as the browser:

1. Send `GET /session/new` and read the CSRF token from the page.
2. Send `POST /session` with `email_address`, `password`, and `authenticity_token`.
3. Keep the cookie jar for all later requests.
4. Send the `X-CSRF-Token` header on each non-GET request.

- `POST /tasks` (add), `DELETE /tasks/:id` (delete), and `PATCH /tasks/:id/complete` (mark done) answer with a `302` redirect, not JSON.
- A request without a CSRF token gets `422`.
- A missing task gets `404`.
- Full detail: `README.md` section "Scripted access".

## Invariants

- Each new controller requires login. Opt a public action out with `allow_unauthenticated_access`.
- `due_since` is the only JSON action. It needs an ISO 8601 `since` parameter, else it answers `400`.
- `create` and `update` send the title through `QuickAdd.parse`. Reschedule uses the same parser.
- Due dates go through `Task#due_date=` and `Task#due_time=`. Do not write `due_at` directly.
- `return_to` is not inherited. Each view must send it as a hidden field. Without it, the redirect falls back to Inbox.
- `safe_return_to` accepts only internal paths that start with `/` and not `//`. This blocks open redirects.
- A notice escapes the user title, because the layout renders notices through `sanitize`.

## Side Effects

- Writes the `tasks`, `projects`, `labels`, `task_labels`, `completed_occurrences`, and `sessions` tables.
- `complete` makes a `CompletedOccurrence`. Then it deletes a one-off task or moves a recurring task to its next due time.

## Verification

- Run: `bin/rspec spec/requests`
