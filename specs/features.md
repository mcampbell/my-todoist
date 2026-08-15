# my-todoist — Features

User-facing feature list. Updated as development proceeds. Technical design
lives in `specs/design.md`; this doc is business-facing only.

## Tasks

- Create, edit, delete a task (title, notes, priority, project, labels).
- Mark a task complete (soft — sets a completed timestamp, doesn't delete).
- Completed tasks history view.
- Due date is optional. When set, time is also optional — a task can be
  due "Feb 20" with no specific time, or "Feb 20 at 2:30pm".
- New task form defaults the date field to today.

## Organization

- Projects: group tasks; one implicit "Inbox" for tasks with no project.
- Labels: tag tasks, many-to-many.
- Priority: P0 (none) through P3, shown as a colored badge.
- Sidebar navigation: Inbox, Today, Upcoming, Completed, project list.

## Date views

- **Today**: overdue tasks, tasks due today, and undated tasks — across all
  projects. An undated task counts as "today" until it's given a date or
  completed.
- **Upcoming**: tasks due in the next 7 days, grouped by date. Excludes
  today and undated tasks (Today already owns those).

## Navigation & entry points

- "New task" button available from every list view (Inbox, per-project,
  Today, Upcoming, Completed), not just Inbox.
- Completing, editing, or deleting a task returns you to the view you acted
  from (Today, Upcoming, Inbox, or a project) instead of always bouncing to
  Inbox.
- Creating a task from Today/Upcoming/Completed returns you to that view.

## Not yet built

- Quick-add single-field entry with natural-language date, priority, and
  `#project` parsing (planned: `specs/slice-4-plan.md`). `@label` parsing via
  quick-add is explicitly deferred past this slice — labels stay on the
  structured form control.
- Recurring tasks (`every` / `every!`).
- Notifications / reminders.
