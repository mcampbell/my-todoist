# Design: responsive nav collapse

Single deployable unit — one layout change, one media query, one CSS drawer
styling. Not sliced (see `specs/responsive-nav-collapse-grill.md` for
resolved Q&A this design is based on).

## Overview

Replace Bulma's passive column stacking below 768px with an explicit hidden
sidebar + `<details>`/`<summary>` drawer toggle. Main task pane stays fixed
at full width on narrow screens; nav hides by default and appears as an
overlay when drawer is open.

## Changes

### 1. Layout structure (`app/views/layouts/application.html.erb:26-30`)

Wrap the nav in a `<details>` element with a plain-text `<summary>` toggle.
Keep the two-column structure unchanged for wide screens (Bulma will handle
the normal layout via `.columns`); media query hides the nav and adjusts
the summary positioning on narrow screens.

Current (lines 26-30):
```erb
<div class="columns">
  <div class="column is-narrow">
    <%= render "layouts/navbar" %>
  </div>
  <div class="column">
```

New:
```erb
<div class="columns">
  <details id="nav-drawer" class="nav-drawer">
    <summary class="nav-toggle">Menu</summary>
    <div class="column is-narrow nav-sidebar">
      <%= render "layouts/navbar" %>
    </div>
  </details>
  <div class="column nav-main">
```

Rationale: `<details>` wraps the nav and its toggle in one semantic block.
The `<summary>` acts as the toggle. The nav div retains `column is-narrow`
for wide-screen layout (Bulma reads it). We add class names (`nav-drawer`,
`nav-toggle`, `nav-sidebar`, `nav-main`) to target with media queries —
cleaner than relying on CSS selectors like `details > div:nth-child(2)`.

### 2. Stylesheet (`app/assets/stylesheets/application.css`)

Add media query targeting the 768px breakpoint. The query hides the nav
sidebar by default, shows the drawer as an overlay when `<details open>`
fires, and keeps the main pane full-width.

```css
/* Responsive nav drawer for mobile (< 768px) */
@media (max-width: 767.98px) {
  .nav-drawer {
    display: contents;
  }
  
  .nav-toggle {
    display: block;
    position: fixed;
    top: 1rem;
    left: 1rem;
    z-index: 999;
    padding: 0.5rem 1rem;
    background: white;
    border: 1px solid #dbdbdb;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 500;
  }
  
  .nav-sidebar {
    display: none;
  }
  
  .nav-drawer[open] .nav-sidebar {
    display: block;
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    width: 250px;
    z-index: 998;
    background: white;
    border-right: 1px solid #dbdbdb;
    overflow-y: auto;
    padding-top: 3.5rem;
  }
  
  .nav-main {
    width: 100%;
  }
}

/* Wide screens (>= 768px): default Bulma layout */
@media (min-width: 768px) {
  .nav-drawer {
    /* `details` contributes nothing to layout; content flows through */
    display: contents;
  }
  
  .nav-toggle {
    display: none;
  }
  
  .nav-sidebar {
    /* Retains Bulma's `column is-narrow` layout */
  }
  
  .nav-main {
    /* Retains Bulma's `column` flex layout */
  }
}
```

Breakdown:
- `.nav-drawer { display: contents; }` on both breakpoints makes the
  `<details>` element invisible to layout — its children flow directly into
  the parent `.columns`.
- Below 768px: toggle button is fixed top-left; nav sidebar is hidden by
  default and positioned fixed + full height when `<details open>`.
- Above 768px: toggle is hidden; sidebar flows normally via Bulma (no change
  to existing layout).

Rationale for `display: contents`: avoids wrapping the column in an extra
div that would break Bulma's flex layout. The `<details>` is semantic HTML
but doesn't participate in layout this way.

## Test plan

System spec in `spec/system/responsive_nav_flow_spec.rb`:

1. **Wide screen (>= 768px)**:
   - Toggle button not visible.
   - Nav sidebar and main pane displayed side-by-side as today.
   - All nav links (Inbox, Overdue, Today, Upcoming, Completed, New task,
     projects) are clickable and navigate correctly.

2. **Narrow screen (< 768px)**:
   - Toggle button ("Menu") visible at fixed top-left.
   - Nav sidebar hidden by default (main pane full-width).
   - Clicking toggle opens the drawer; sidebar slides in from the left.
   - Clicking a nav link (e.g., Inbox) navigates and closes the drawer
     (native `<details>` behavior: full page load resets state).
   - Clicking toggle again closes the drawer.

3. **Resize from wide to narrow**:
   - Drawer state persists correctly as viewport crosses 768px threshold.
   - No layout jump or visual glitch.

No new JavaScript or state persistence required — pure CSS + native
`<details>` behavior.

## Edge cases deferred

- Closing the drawer on outside-tap (would require JS; deferred per Q7 grill).
- Closing on Escape key (would require JS).
- Persistent drawer state across page loads (not applicable; full page
  reloads reset `<details>` state naturally).

## Files changed

- `app/views/layouts/application.html.erb` — wrap nav in `<details>`, add
  class names for media-query targeting.
- `app/assets/stylesheets/application.css` — add 768px media query with
  drawer overlay + toggle styling.

No changes to `_navbar.html.erb`, `app/models/task.rb`, or any non-view
files.

## Merge conflicts & rework

None anticipated. Changes are purely additive to layout/CSS; no existing
logic or shared styles touched. The `<details>` wrapper is inert on wide
screens (display: contents), so zero impact to the current desktop layout.
