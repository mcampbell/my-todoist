# Task search

## Grill

Q: Scope — active tasks only, or also completed history?
A: Active `Task`s by default. A checkbox ("include completed tasks",
default off) also searches `CompletedOccurrence.task_title`.

Q: How do mixed active/completed results render?
A: One table, same shape as Inbox. Completed rows reuse `priority_badge`/
`due_tag` (both duck-type on `priority`/`due_at`/`all_day?`, so they work
against a `CompletedOccurrence` unchanged) but render read-only — no
complete/edit/delete buttons, since there's no live `Task` to act on —
with a "Completed" tag and muted (`has-text-grey`) styling.

Q: Match field?
A: Title only (`Task#title` / `CompletedOccurrence#task_title`).

Q: Route?
A: `GET /tasks/search?q=...&include_completed=1` — collection route on
`tasks`, same pattern as `due_since`/`today`/`overdue`/`upcoming`. GET
keeps results bookmarkable/shareable.

Q: Blank query?
A: Render the form only — no table, no "0 results" noise.

Q: Cancel button?
A: Fixed target, `root_path` (Inbox).

Q: Ordering?
A: Active matches via the existing `Task.ordered` scope (due_at asc,
NULLs last) — same as every other list view. Completed matches appended
after, ordered `completed_at desc`.

Q: Nav?
A: Added to `_navbar.html.erb` alongside Inbox/Overdue/Today/Upcoming/
Completed.

## LIKE, not ILIKE

This app is SQLite, not Postgres — no `ILIKE`. SQLite's `LIKE` is already
case-insensitive for ASCII by default, so a plain `LIKE '%...%'` already
gives the "ilike"-style match that was asked for; no `COLLATE NOCASE`
needed.

User-typed `%` and `_` are LIKE wildcards — escaped (along with a literal
backslash) before being interpolated into the pattern
(`TasksController#escape_like`), with an explicit `ESCAPE '\'` clause, so
a search for a literal `%` or `_` matches only that literal character.

## Testing

`spec/requests/tasks_spec.rb` ("GET /tasks/search"): blank-query render,
case-insensitive substring match, completed-occurrence exclusion/
inclusion by checkbox, wildcard-escaping, ordering, Cancel target.
`spec/requests/navigation_spec.rb`: Search link present.
