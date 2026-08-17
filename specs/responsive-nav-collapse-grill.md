# Grill: responsive nav collapse

Goal: on narrow screens, stop the left nav (`_navbar.html.erb`, rendered via
Bulma `.columns`/`.column is-narrow` in `application.html.erb:26-30`) from
stacking below the main task pane. Instead hide/collapse it so the main
pane stays front and center.

Current state (found before asking):
- `application.html.erb:26` wraps nav + main content in Bulma `.columns`.
- Bulma stacks columns vertically at its built-in 768px breakpoint — no
  custom CSS/JS involved today.
- No Stimulus controllers exist; JS is plain files loaded via importmap
  (`application.js`, `notifications.js`).
- Nav content: Inbox/Overdue/Today/Upcoming/Completed/New task + project
  list + Manage projects/labels (`_navbar.html.erb:1-20`).

## Q&A

1. **Mechanism**: pure CSS media query. Not a "state" — re-evaluated per
   render, nothing to store/persist.
2. **Access when collapsed**: `<details>`/`<summary>` toggle (CSS-only,
   no JS) reveals nav as an overlay/drawer.
3. **Breakpoint**: 768px — reuse Bulma's existing mobile breakpoint.
4. **Overlay vs push**: overlay. Drawer floats over the main pane; main
   pane markup/position stays untouched underneath.
5. **Toggle label**: plain text "Menu" (no icon, no icon library).
6. **Wide-screen (>=768px) behavior**: unchanged — nav always inline/
   visible as today; toggle only appears/matters below breakpoint.
7. **Closing the drawer**: accept native `<details>` behavior — closes by
   re-tapping "Menu" or by navigating (fresh page load resets it). No
   outside-tap/Escape JS.

## Resolution
CSS-only `<details>`/`<summary>` drawer, 768px breakpoint, overlay
positioning, text toggle label, no JS, no state persistence. Wide-screen
layout unchanged.
