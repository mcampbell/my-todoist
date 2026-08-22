---
type: Parser
title: Recurrence
description: Parses the "every(!)? (count)? unit" grammar and computes the next due date from a completed occurrence.
resource: file:///home/mcampbell/dev/my-todoist/app/models/recurrence.rb
tags: [grammar, parsing, dates]
timestamp: 2026-08-22T00:00:00Z
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

# Citations

[1] [app/models/recurrence.rb](../../app/models/recurrence.rb)
[2] [specs/every-other-recurrence-grill.md](../../specs/every-other-recurrence-grill.md)
