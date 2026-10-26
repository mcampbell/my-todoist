# app/views/layouts

## Purpose

Page shell for every view: head, flash, sidebar.

## Files

- `application.html.erb` - HTML shell. Has `csrf_meta_tags`, `javascript_importmap_tags`, Bulma + app stylesheets, `#toast-container` (`data-turbo-permanent`), flash loop, navbar render.
- `_navbar.html.erb` - sidebar menu. Links: Today, Inbox (`root_path`), Overdue, Upcoming, Completed, Search, projects, Manage projects, Manage labels. Log out uses `button_to session_path`, method delete.

## Rules for agents

- Keep `#toast-container` with `data-turbo-permanent`. The reminder toasts use it.
- Navbar "New task" passes `return_to: request.path`. Keep it, else redirect falls back to Inbox silently.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
