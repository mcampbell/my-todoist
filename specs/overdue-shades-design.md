# Overdue shades design

Goal: an overdue row gets redder as it gets older. Three shades.

Single slice (one deployable unit, no slicing).

## Change

- `TasksHelper#overdue_class(task)`: nil when not overdue, else a Bulma
  background class by age (age = now - `due_at`):

  | Age                      | Class                        |
  |--------------------------|------------------------------|
  | under 1 week             | `has-background-danger-light` (shade 90, as today, 6.68:1) |
  | 1 week up to 1 month     | `has-background-danger-85` (5.59:1) |
  | 1 month or more          | `has-background-danger-80` (4.68:1) |

- `tasks/_task.html.erb`: row class calls `overdue_class(task)` in place of the
  inline `"has-background-danger-light" if task.overdue?`. In progress still
  wins.

## Decisions

- Bulma 1.0.2 shade helpers, no new CSS. Shades 90/85/80 keep text contrast at WCAG AA (4.5:1) or better in light mode; 75 (3.94:1) and 70 (3.37:1) fail.
- Dark mode: every danger shade, today's too, gives about 1:1 contrast with dark-scheme text. Exists already; out of scope.
- Boundaries: exactly 1 week -> middle shade; exactly 1 month -> darkest.
- Month = calendar month (`1.month.ago`). The 30-day flat month belongs to the
  recurrence grammar only; this is display.
- All-day task: age counts from its due date midnight (`due_at`), the same
  value `overdue?` uses.
- Lives in the helper: presentation only, `Task#overdue?` stays the one source
  of "is overdue".
- One slice: no merge conflicts or rework, so estimates.md gets no entry.

## Tasks

- [x] Branch `overdue-shades`
- [x] Red: helper spec - not overdue, each bucket, both boundaries
- [x] Red: request spec - row carries the shade for an old overdue task
- [x] Green: helper + row partial
- [x] `bin/rspec`, `bin/rubocop` green
- [x] code-reviewer pass
- [x] Commit
