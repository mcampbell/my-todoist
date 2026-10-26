# app/views/labels

## Purpose

Manage labels: list, create, edit, delete.

## Files

- `index.html.erb` - table of labels. Has New, Edit, Delete (`button_to`, method delete) controls.
- `new.html.erb` - new label page. Renders `form`.
- `edit.html.erb` - edit label page. Renders `form`.
- `_form.html.erb` - shared `form_with model: label`. Shows errors. Cancel goes to `labels_path`.

## Rules for agents

- Pass the record as a local: `render "form", label: @label`.
- This form has no `return_to`. Cancel and save go to the labels index. If you add `return_to`, make it a hidden field, else redirect falls back to Inbox silently.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
