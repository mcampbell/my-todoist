# my-todoist — Estimates

Scale: trivial=3h · small=1d · medium=2d · large=1wk. Session-relative.

## Slices

| Slice | Work | Size | Days |
|---|---|---|---|
| 1 | Walking skeleton (app, DB, RSpec, Bulma, Task CRUD, complete, history) | medium | 2 |
| 2 | Organization (projects, labels, priority, sidebar, per-project/Inbox) | medium | 2 |
| 3 | Date views (Today / Upcoming) | small | 1 |
| 4 | Quick-add NLP one-off (chronic, p#/#proj/@label tokens) | medium | 2 |
| 5 | Recurrence engine (every/every!, parser PORO, catch-up) | large | 5 |
| 6 | Notifications + Solid Queue poller + missed sweep | medium | 2 |
| | **Subtotal** | | **14** |

## Merge-conflict cost

| # | Conflict | Cost | Days |
|---|---|---|---|
| C1 | `tasks` schema/model — 3 streams add columns + migrations | small | 1 |
| C2 | Layout/nav partial — slice 2 + slice 3 both edit nav | trivial | 0.5 |
| C3 | TasksController#create — structured vs parsed | trivial | 0.5 |
| | **Subtotal** | | **2** |

## Rework cost

| # | Rework | Cost | Days |
|---|---|---|---|
| R1 | Plain form → quick-add field (slice 1 → 4) | trivial | 0.5 |
| R2 | Create controller path (slice 1 → 4) | trivial | 0.5 |
| R3 | Filtering reworked for next-occurrence (slice 3 → 5) | trivial | 0.5 |
| | **Subtotal** | | **1.5** |

## Total

Slices 14 + conflicts 2 + rework 1.5 = **17.5 days** (~3.5 wk solo).

Notes:

- Slice 5 (recurrence) is the risk + value core; largest by design.
- Parallelizing streams 2 / 4+5 / 6 after slice 1 compresses wall-clock, not effort.
