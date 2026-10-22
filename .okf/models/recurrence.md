---
type: Parser
title: Recurrence
description: Parses the "every(!)? (count)? unit" grammar and computes the next due date from a completed occurrence.
resource: file:///home/mcampbell/dev/my-todoist/app/models/recurrence.rb
tags: [grammar, parsing, dates]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-22T00:00:00Z
sources:
  - resource: "../../app/models/recurrence.rb"
    title: "app/models/recurrence.rb"
  - resource: "../../specs/every-other-recurrence-grill.md"
    title: "specs/every-other-recurrence-grill.md"
---

# Overview

`Recurrence.parse(text)` returns a value object; `#next_from(due_at:,
now:)` computes the next due date. Pure computation — no DB, no state.
`Task#complete!` (see [Task](/models/task.md)) calls it on completion.

Two recurrence modes, selected by a trailing `!`:

- **Fixed** (`every 2 weeks`) — steps forward in whole intervals from the
  *original* due date, preserving phase (e.g. always lands on the same
  weekday).
- **Rolling** (`every! 2 weeks`) — steps from *completion time* instead,
  so a late completion doesn't compound.

# Ending a series

`Recurrence` has no notion of an end: a rule steps forever. The limit
("ending after N times", "ending on <date>") lives on the task, in
`recurrence_remaining` / `recurrence_ends_at`, and `Task#complete!` /
`#skip!` check it. See [Task](/models/task.md) and
[QuickAdd](/models/quick-add.md). This keeps `Recurrence` pure computation.
