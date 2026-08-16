# my-todoist — Estimates

Scale: trivial=3h · small=1d · medium=2d · large=1wk. Session-relative.

## Slices

| Slice | Work | Size | Days |
|---|---|---|---|
| 1 | Walking skeleton (app, DB, RSpec, Bulma, Task CRUD, complete, history) | medium | 2 |
| 2 | Organization (projects, labels, priority, sidebar, per-project/Inbox) | medium | 2 |
| 3 | Date views (Today / Upcoming) | small | 1 |
| 4 | Quick-add NLP one-off (chronic, p#/#proj/@label tokens) | medium | 2 |
| 5 | Recurrence engine (every/every!, parser PORO, catch-up, CompletedOccurrence audit log replacing completed_at) | large | 6 |
| 6 | Client-side due toasts (JSON poll endpoint + JS module + in-page toasts) | small | 1 |
| | **Subtotal** | | **14** |

## Merge-conflict cost

| # | Conflict | Cost | Days |
|---|---|---|---|
| C1 | `tasks` schema/model — 2 streams (slices 2, 5) add columns + migrations | small | 1 |
| C2 | Layout/nav partial — slice 2 + slice 3 both edit nav | trivial | 0.5 |
| C3 | TasksController#create — structured vs parsed | trivial | 0.5 |
| | **Subtotal** | | **2** |

## Rework cost

| # | Rework | Cost | Days |
|---|---|---|---|
| R1 | Plain form → quick-add field (slice 1 → 4) | trivial | 0.5 |
| R2 | Create controller path (slice 1 → 4) | trivial | 0.5 |
| R3 | Filtering reworked for next-occurrence (slice 3 → 5) | trivial | 0.5 |
| R5 | design.md Domain section rewritten for CompletedOccurrence audit log (slice 5) | trivial | 0.5 |
| | **Subtotal** | | **2** |

## Total

Slices 14 + conflicts 2 + rework 2 = **18 days** (~4 wk solo).

Notes:

- Slice 5 (recurrence) is the risk + value core; largest by design.
- Slice 6 is pure client-side (no job stack) — smaller than originally
  estimated; its old rework R4 (drop `completed_at IS NULL`) is void since
  slice 5 destroyed that column and slice 6 adds no column or poller.
- Parallelizing streams 2 / 4+5 / 6 after slice 1 compresses wall-clock, not effort.

## "in X unit" date-pinning grammar

- Single slice, easy (1 point): regex + parse branch + duration math, no new deps. See specs/in-x-unit-design.md.
