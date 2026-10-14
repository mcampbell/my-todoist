# Completed notes design

Goal: completing a task keeps its notes in the completed log.

Single slice (one deployable unit, no slicing).

## Change

- Migration: add `notes` (text, nullable) to `completed_occurrences`.
- `Task#complete!`: copy `notes` into the `CompletedOccurrence` snapshot.
- `completed_occurrences/show`: add a Notes row. Render with `simple_format(h(notes))`
  (`h` escapes HTML so notes show as typed; `simple_format` alone only
  sanitizes; line breaks kept). Blank notes show "-", like Labels.

## Decisions

- No backfill. Notes on past completions are gone (user accepts this).
- Recurring task: notes stay on the live task (advance is in place) and copy
  into each snapshot. No change.
- Completed search matches `task_title` only. Notes search stays out (YAGNI).
- No merge conflicts or rework: one slice, so estimates.md gets no entry.

## Tasks

- [x] Branch `completed-notes`
- [x] Red: model spec - `complete!` snapshots notes
- [x] Red: request spec - details page shows notes, keeps line breaks, escapes HTML
- [x] Green: migration + `complete!` + view
- [x] `bin/rspec`, `bin/rubocop` green
- [x] code-reviewer pass
- [x] Commit
