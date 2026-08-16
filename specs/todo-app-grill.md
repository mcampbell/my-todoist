# Todo App Grill — 2026-08-13

## Initial prompt

a plan for a "todo" app, in case I stop being able to run Todoist. It should run locally, using SQLite3 as storage. It should be a web app, using Ruby on Rails, with the builtin "view" layer. It should handle standard TODO functionality, and I should be able to schedule todo's using as much of Todoist's "natural language" as possible. One must-have feature is Todoist's `every!` feature.

## Q1: NLP parsing approach

**Recommended:** chronic + custom recurrence layer
**Answer:** Chosen. Recurrence is the key/must-have part. Must support: "every day", "every!", "next monday", "weekdays", "workday".

## Q2: every vs every! semantics

**My initial guess:** backwards (had ! = fixed)
**Answer (correct):** `every! X` = next due date = completion date + X (rolling/floating, marked by `!`). `every X` (no bang) = next due date = original scheduled due date + X (fixed).

## Q3: Data model for recurring tasks

**Recommended:** single mutable row, due_at advances in place on completion
**Answer:** Chosen (matches Todoist's actual model).

## Q4: Organization features for v1

**Recommended:** Projects only (minimal)
**Answer:** Projects + Labels/tags + Priority levels. Sections skipped for v1.

## Q5: Auth

**Recommended:** none, single-user local app
**Answer:** Chosen.

## Q6: Views for v1

**Answer:** Today, Upcoming, Inbox (no due date), Per-project view. All 4 recommended options chosen.

## Q7: Task entry UX

**Recommended:** quick-add text parser, full Todoist-style single-field syntax
**Answer:** Chosen.

## Q8: Time & reminders

**Recommended:** due times yes, notifications no
**Answer:** Due times + notifications wanted (more than recommended).

## Q9: Notification delivery mechanism

**Recommended:** macOS native notification via background job + terminal-notifier/osascript
**Answer:** Chosen. Implies: Rails app/scheduler process must be running in background continuously (launchd or similar) to fire at due times.

> **Superseded 2026-08-15 (slice 6):** client-side, browser-based toasts
> replace the macOS notification + background scheduler. See
> `specs/design.md` Slice 6 and `~/tmp/2026-08-15-slice-6-grill.md`.

## Q10: Scheduler tech

**Recommended:** Solid Queue recurring job
**Answer:** Chosen. Needs bin/jobs process running alongside rails server (or Procfile.dev via foreman/overmind).

## Q11: Asset pipeline

**Recommended:** Rails 8 defaults, Propshaft + Importmap
**Answer:** Chosen.

## Requirement addition (user-initiated): sub-4-hour recurrence granularity

Todoist caps recurrence granularity at 4 hours. User wants finer: `every! 10 minutes` must be supported.
Implication: custom recurrence parser (Q1) must accept minute units, not just day/week/month.
Implication: Solid Queue recurring poll interval (Q10) must be <= smallest supported granularity (e.g. every 1 min) to fire on time.

## Q12: Minimum recurrence granularity

**Recommended:** 1 minute
**Answer:** Chosen. Poller cadence = every 1 minute via Solid Queue recurring.yml.

## Q13: weekday/workday definition

**Recommended:** Mon-Fri, no holiday awareness
**Answer:** Chosen.

## Q14: Todoist import

**Recommended:** yes, one-time import script
**Answer:** No — start fresh, manual re-entry.

## Q15: Subtasks

**Recommended:** no, flat tasks only
**Answer:** Chosen.

## Q16: Task completion behavior

**Recommended:** soft-complete (completed_at) + history view
**Answer:** Chosen.

## Q17: Autostart

**Recommended:** launchd auto-start
**Answer:** Manual start (bin/dev), but must catch up on missed reminders/due items when it comes back online.
Implication: on boot, sweep for due_at <= now && not yet notified -> fire notification immediately.
Implication: need catch-up rule for recurring tasks whose due date passed while app was off (see Q18).

## Q18: Missed recurring catch-up (fixed/no-bang recurrence)

**Recommended:** fast-forward silently, notify once
**Answer:** Mark the most recent missed occurrence as overdue (don't silently skip). On completion, reschedule to the nearest future date (skip past intervals rather than due_date+interval landing in the past again).

## Testing framework (override of default)

**Answer:** rspec + rspec-rails, not Minitest.
