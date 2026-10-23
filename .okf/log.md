# Update Log

## 2026-10-23
* **Sync**: [Task](models/task.md) - the edit form's Recurrence field accepts a time ("every workday at 4pm").
* **Sync**: Added [Clickable URLs](features/clickable-urls.md) (`TasksHelper#linkify` on task row title and notes preview).

## 2026-10-19
* **Supersession**: [Browser notifications replace the server notifier](decisions/browser-notification-api.md) supersedes [OS notification triggered client-side](decisions/os-notification-client-triggered.md) (PR #56).
* **Deprecation**: [OsNotifier](models/os-notifier.md) - code deleted in PR #56; concept kept for history.
* **Regeneration**: Migrated the bundle from OKF v0.1 to v0.2 (`okf_validate.py --migrate`: `timestamp` to `generated.at`, `# Citations` to `sources`).

## 2026-10-10
* **Sync**: [Scope decision](decisions/single-user-scope.md) names the `user:modify` password-change task.
* **Sync**: Reversed [scope decision](decisions/single-user-scope.md) - app now internet-facing behind nginx + login wall; updated [my-todoist](architecture/my-todoist-app.md) and the decisions index.

## 2026-09-01
* **Sync**: Added [Project tints](features/project-tints.md) (deterministic CRC32-HSL project colour, eager-loaded `:project` on task indexes), captured PR #34.

## 2026-08-22
* **Creation**: Initial bundle produced from the codebase (`app/models`,
  `app/controllers`, `specs/*-design.md`) — [my-todoist](architecture/my-todoist-app.md),
  [QuickAdd](models/quick-add.md), [Recurrence](models/recurrence.md),
  [Task](models/task.md), [OsNotifier](models/os-notifier.md),
  [Project and Label](models/project-and-label.md),
  [CompletedOccurrence](models/completed-occurrence.md),
  [Task search](features/task-search.md),
  [Keyboard shortcuts](features/keyboard-shortcuts.md),
  [Due reminders](features/due-reminders.md), and five
  [decisions](decisions/index.md).