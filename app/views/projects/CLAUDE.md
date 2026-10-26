# app/views/projects

## Purpose

Manage projects: list, create, edit, delete.

## Files

- `index.html.erb` - table of projects. Has New, Edit, Delete (`button_to`, method delete) controls.
- `new.html.erb` - new project page. Renders `form`.
- `edit.html.erb` - edit project page. Renders `form`.
- `_form.html.erb` - shared `form_with model: project`. Shows errors. Cancel goes to `projects_path`.

## Rules for agents

- Pass the record as a local: `render "form", project: @project`.
- This form has no `return_to`. Cancel and save go to the projects index. If you add `return_to`, make it a hidden field, else redirect falls back to Inbox silently.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
