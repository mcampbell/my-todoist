# Completed pagination design

Goal: the Completed page shows one page of rows at a time, so it stays fast as
the log grows.

Single slice (one deployable unit, no slicing).

## Change

- `TasksController#completed`: one line each for `@last_page` (count / 50,
  rounded up, at least 1), `@page` (`params[:page].to_i.clamp(1, @last_page)`:
  a missing, bad, or too-large `?page=` shows the nearest real page, never an
  empty one), and the `offset`/`limit` query by `COMPLETED_PER_PAGE` (50).
  Order by `completed_at DESC, id DESC`: the `id` tie-break keeps rows with
  equal times from moving between pages.
- `tasks/_pager.html.erb` (Bulma `pagination`): First, Previous, page numbers
  current +/- 2, Next, Last, and a GET form with a number box (`page`,
  `min` 1, `max` last) and a Go button (phone number pads have no Enter key)
  to jump to a page. Mark the current page with
  `aria-current="page"`. On page 1, First and Previous are not links; on the
  last page, Next and Last are not links. Hide the pager when there is only
  one page.
- Build every URL with `completed_tasks_path(page:)` (sub-path safe).

## Decisions

- No gem (pagy, kaminari) and no page-math class: three controller lines do
  the job (YAGNI, user call). Request specs cover the math.
- 50 rows per page, a constant. No per-page picker.
- Search's completed results stay unpaged. Out of scope.
- No merge conflicts or rework: one slice, so estimates.md gets no entry.

## Tasks

- [x] Branch `completed-pagination`
- [x] Red: request spec - page slices, pager links, jump form, clamping
- [x] Green: controller + `_pager` partial
- [x] `bin/rspec`, `bin/rubocop` green
- [x] code-reviewer pass
- [x] Commit
