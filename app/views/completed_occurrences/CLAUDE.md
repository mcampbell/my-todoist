# app/views/completed_occurrences

## Purpose

Read-only detail page for one completed task occurrence.

## Files

- `show.html.erb` - table of occurrence fields (title, notes, project, priority, labels, due, completed time). Links back to `completed_tasks_path`.

## Rules for agents

- Render the header with `render "tasks/page_header"`.
- Escape notes with `simple_format(h(...))`. Keep it.
- No form here. If you add one, pass `return_to` as a hidden field, else redirect falls back to Inbox silently.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
