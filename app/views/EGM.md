# Views

## Overview

ERB templates with Bulma CSS. One subdirectory for each controller, plus `layouts/`.

## Interface

- `layouts/application.html.erb`: renders the `script-name` and `seconds-until-midnight` meta tags, flash notices, and the navbar.
- `tasks/`: list views (`index`, `today`, `upcoming`, `overdue`, `completed`, `search`), forms, and the `_task` row partial.
- `projects/`, `labels/`, `sessions/`, `completed_occurrences/`: forms and pages for each controller.

## Invariants

- Each create or reschedule form must send `return_to` as a hidden field. See the search view for the pattern. Without it, the redirect goes to Inbox.
- Build URLs with route helpers. Never write a bare `"/..."` path.

## Side Effects

- None.

## Verification

- Run: `bin/rspec spec/system spec/requests`
