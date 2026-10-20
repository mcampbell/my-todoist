---
type: Decision
title: No JS-capable test driver — Capybara stays rack_test-only
description: The RSpec suite has no Selenium/Cuprite driver and no js:true specs, so JavaScript behavior (keyboard shortcuts, fetch calls) is reviewed but not test-covered.
tags: [testing, capybara, javascript]
generated:
  by: process:okf-migrate
  at: 2026-08-22T00:00:00Z
sources:
  - resource: "/features/keyboard-shortcuts.md"
    title: "features/keyboard-shortcuts"
---

# Decision

Ship keyboard-shortcut and other client-JS features (`q`, `/`, `Esc`;
the browser notification and Mute toggle) without an accompanying JS spec, relying on
`bin/rubocop`/`bin/rspec` for the server side and a `/code-reviewer` pass
for the JS.

# Rationale

Capybara is in the Gemfile but only `driven_by(:rack_test)` is
configured anywhere in the suite — no `javascript_driver`, no
Selenium/Cuprite, no `js: true` on any existing spec. `rack_test` can't
execute JavaScript, so there's no way to exercise a `keydown` listener or
a `fetch()` call from RSpec today. Each JS feature's design doc
(`specs/q-shortcut-design.md`, `specs/esc-shortcut-design.md`) notes this
explicitly rather than silently skipping coverage.
