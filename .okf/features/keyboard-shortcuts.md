---
type: Feature
title: Keyboard shortcuts
description: Global keydown listeners in application.js — q (new task), / (search), Esc (abandon and return).
resource: file:///home/mcampbell/dev/my-todoist/app/javascript/application.js
tags: [ui, keyboard, javascript]
timestamp: 2026-08-22T00:00:00Z
---

# Overview

Three `document`-level `keydown` listeners, all skipping when a modifier
key is held or focus is already in a text input/contenteditable:

- **`q`** -> `Turbo.visit("/tasks/new")`.
- **`/`** -> `Turbo.visit("/tasks/search")` — same guard shape as `q`.
- **`Escape`** -> on an allowlisted set of pathnames (`/tasks/new`,
  `/tasks/search`), clicks the page's `#cancel-link` (its `href` is
  server-computed — `safe_return_to` on the new-task page, `root_path`
  on search — so the client doesn't duplicate that redirect logic).

Deliberately **not** generalized to every page with a Cancel link (e.g.
the edit-task form) — kept scoped to what was explicitly asked for each
time.

No JS spec exists for any of these — the RSpec suite is `rack_test` only
(no Selenium/Cuprite), so keydown behavior isn't exercisable from RSpec;
each was verified by code review instead. See
[No JS driver in the test suite](/decisions/no-js-test-driver.md).

# Citations

[1] [specs/q-shortcut-design.md](../../specs/q-shortcut-design.md)
[2] [specs/esc-shortcut-design.md](../../specs/esc-shortcut-design.md)
