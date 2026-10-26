# app/views/tasks

## Purpose

Task lists, task forms, search, completed history.

## Files

- `index.html.erb` - Inbox or one project (`@project`).
- `today.html.erb`, `overdue.html.erb`, `upcoming.html.erb` - dated lists.
- `completed.html.erb` - completed history. Uses `_completed_result` and `_pager`.
- `search.html.erb` - GET search form (`search_tasks_path`).
- `new.html.erb` - renders `quick_add_form`.
- `edit.html.erb` - renders `form`.
- `complete_with_notes.html.erb` - completion-notes form. Hidden `return_to`.
- `_task.html.erb` - one task row. Complete, skip, edit, delete, in-progress buttons.
- `_form.html.erb` - full task form.
- `_quick_add_form.html.erb` - quick-add text form (parsed by `QuickAdd`).
- `_page_header.html.erb` - title, "New task" button. Locals: `title`, `return_to`, `mute_toggle`.
- `_completed_result.html.erb` - one completed row.
- `_pager.html.erb` - First/prev/next links for completed.

## Rules for agents

- Both forms emit `hidden_field_tag :return_to` when `params[:return_to]` is present. Keep it, else redirect falls back to Inbox silently.
- Every link that opens new/edit/complete_with_notes passes `return_to: request.path` (see `_task`, `_page_header`).
- `return_to` is validated by `safe_return_to` in `TasksController`. Do not read `params[:return_to]` raw in a redirect.
- A new list view must render `page_header` and pass `return_to`.
- Write due dates through `Task` setters (`due_date`, `due_time`), not `due_at`.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
