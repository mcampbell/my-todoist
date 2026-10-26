# CLAUDE.md (app/helpers)

## Purpose
View formatting helpers. No database writes.

## Files
- `application_helper.rb`: `ApplicationHelper`. `seconds_until_midnight`.
- `projects_helper.rb`: `ProjectsHelper`. `project_tint`.
- `tasks_helper.rb`: `TasksHelper`. Time and date formatting (`format_time`, `time_of_day`), due tags, recurrence limit text, priority label and badge, overdue CSS class, notes preview, `linkify`, priority select options, year suffix.

## Rules for agents
- Keep helpers pure. Take inputs, return strings or markup.
- `linkify` and `notes_preview` handle user text. Keep escaping in place.

## Verification
- `bin/rspec spec/helpers`
- `bin/rubocop`
