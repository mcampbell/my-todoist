---
type: Parser
title: QuickAdd
description: Parses free-text task titles into structured attributes (priority, due date/time, project, recurrence).
resource: file:///home/mcampbell/dev/my-todoist/app/models/quick_add.rb
tags: [grammar, parsing, chronic]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

`QuickAdd.parse(text)` -> `{ title:, priority:, due_date:, due_time:,
project_name:, recurrence: }`. Runs a fixed sequence of `extract_*!`
private class methods; each mutates the title string in place (stripping
its own token) and returns its own piece of data. **Order matters** —
later extractors scan whatever text earlier ones left behind. Each
extractor guards against overwriting an earlier result (e.g. `date_span`
only runs `if !due_date`).

Reaches for the Chronic gem only inside `date_span`, for free-text
date/time phrases ("next monday", "3pm"). The `every (N)? unit`
recurrence grammar and the `in X unit` grammar each get their own regex
and duration math instead of Chronic — see
[Recurrence](/models/recurrence.md) and
[in-X-unit grammar decision](/decisions/in-x-unit-own-grammar.md).

To add a new grammar: define a regex constant, write a
`private_class_method` extractor, wire it into `self.parse`, and
document the wiring point inline.

# Schema

| Field | Type | Description |
|-------|------|-------------|
| `title` | String | Remaining text after every extractor has stripped its token |
| `priority` | Integer or nil | `p1`..`p4` token, mapped via `PRIORITY_TOKENS` |
| `due_date` | Date-ish or nil | From an explicit date token or Chronic free text |
| `due_time` | Time-ish or nil | From an explicit time token or Chronic free text |
| `project_name` | String or nil | `#project` token |
| `recurrence` | String or nil | Raw recurrence phrase, handed to `Recurrence.parse` downstream |

# Citations

[1] [app/models/quick_add.rb](../../app/models/quick_add.rb)
[2] [specs/in-x-unit-design.md](../../specs/in-x-unit-design.md)
