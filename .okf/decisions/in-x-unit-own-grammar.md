---
type: Decision
title: '"in X unit" gets its own grammar, not Chronic'
description: The recurrence and "in X unit" free-text grammars use dedicated regex + duration math rather than the Chronic gem.
tags: [quick-add, chronic, parsing]
timestamp: 2026-08-22T00:00:00Z
---

# Decision

[QuickAdd](/models/quick-add.md) reaches for the Chronic gem only inside
`date_span`, for genuinely free-text date/time phrases ("next monday",
"3pm"). The `every (N)? unit` recurrence grammar and the `in X unit`
grammar are each hand-rolled: their own regex constant plus duration
arithmetic, not routed through Chronic.

# Rationale

Full reasoning in `specs/in-x-unit-design.md`. Chronic is good at
open-ended natural-language dates but its behavior for a narrow,
structured grammar like "in 3 days" is less predictable/controllable
than a dedicated regex + `ActiveSupport::Duration` computation — and
recurrence needs to preserve phase/rolling semantics
([Recurrence](/models/recurrence.md)) that Chronic has no concept of.

# Citations

[1] [specs/in-x-unit-design.md](../../specs/in-x-unit-design.md)
[2] [specs/in-x-unit-grill.md](../../specs/in-x-unit-grill.md)
