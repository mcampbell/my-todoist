# Helpers

## Overview

View helpers for date display, priority badges, project tints, and links in notes.

## Interface

- `ApplicationHelper#seconds_until_midnight(now)`: seconds to the next midnight in the app zone. The layout sends it to the JS midnight reload.
- `ProjectsHelper#project_tint(project)`: a pastel color from a CRC32 hash of the project name. `nil` for Inbox.
- `TasksHelper`: `format_time`, `time_of_day`, `due_tag`, `recurrence_limit_text`, `priority_label`, `priority_badge`, `overdue_class`, `notes_preview`, `linkify`, `priority_select_options`.

## Invariants

- `QuickAdd::PRIORITY_TOKENS` is the one source for the `p1`..`p4` display mapping.
- `linkify` links only `http` and `https` URLs. It never makes a `javascript:` link.
- Show the year only when it is not the current year.

## Side Effects

- None. Helpers read data and return strings or HTML.

## Verification

- Run: `bin/rspec spec/helpers`
