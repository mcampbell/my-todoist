# Design: responsive nav collapse

Single deployable unit — one layout change, one media query, one CSS drawer
styling. Not sliced (see `specs/responsive-nav-collapse-grill.md` for
resolved Q&A this design is based on).

## Overview

Introduce a collapsible nav drawer for mobile screens below 768px, keeping
the main task pane fixed at full width. Currently, Bulma's two-column layout
squeezes both columns to narrow widths on small screens; this change hides the
nav sidebar by default and reveals it via a toggle-button drawer overlay instead,
so the main task pane remains full-width on narrow viewports.

## Changes

### 1. Layout structure (`app/views/layouts/application.html.erb:26-33`)

Add a visually-hidden checkbox plus a plain-text `<label>` toggle before the
nav column. Keep the two-column structure unchanged for wide screens (Bulma
will handle the normal layout via `.columns`); the media query hides the nav
and adjusts the label positioning on narrow screens.

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
  <input type="checkbox" id="nav-drawer" class="nav-drawer-toggle"
         aria-label="Toggle navigation menu">
  <label for="nav-drawer" class="nav-toggle">Menu</label>
  <div class="column is-narrow nav-sidebar">
    <%= render "layouts/navbar" %>
  </div>
  <div class="column nav-main">
```

Rationale: the checkbox drives a pure-CSS disclosure — clicking the `<label>`
toggles the checkbox, and `.nav-drawer-toggle:checked ~ .column.nav-sidebar`
shows the drawer. This is engine-independent: unlike `<details>`, whose
closed-state some engines hide even with `display: contents`, the sidebar is
never hidden at wide widths, so menu items always render on desktop. The nav
div retains `column is-narrow` for wide-screen layout (Bulma reads it).

### 2. Stylesheet (`app/assets/stylesheets/application.css`)

Add a media query targeting the 768px breakpoint. The query hides the nav
sidebar by default and shows the drawer as an overlay while the toggle checkbox
is checked, keeping the main pane full-width.

```css
/* Toggle checkbox: visually hidden but reachable; drives the drawer state. */
.nav-drawer-toggle {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.nav-toggle {
  display: none;
}

/* Responsive nav drawer for mobile (<= 768px) */
@media (width <= 768px) {
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

  .column.nav-sidebar {
    display: none;
  }

  .nav-drawer-toggle:checked ~ .column.nav-sidebar {
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
    animation: slideInFromLeft 0.3s ease;
  }

  @keyframes slideInFromLeft {
    from { transform: translateX(-100%); }
    to { transform: translateX(0); }
  }

  @media (prefers-reduced-motion: reduce) {
    .nav-drawer-toggle:checked ~ .column.nav-sidebar {
      animation: none;
    }
  }

  .column.nav-main {
    padding-top: 3rem;
  }
}

/* Wide screens (> 768px): default Bulma layout, sidebar always visible. */
@media (width > 768px) {
  .nav-toggle {
    display: none;
  }
}
```

Breakdown:
- `.nav-drawer-toggle` is visually hidden (`opacity: 0`, `position: absolute`),
  so it does not affect Bulma's flex layout.
- Below 768px: the "Menu" label is fixed top-left; the nav sidebar is hidden by
  default and, when the toggle checkbox is checked, positioned fixed + full
  height as an overlay. A smooth slide-in animation plays when the drawer opens
  (respects `prefers-reduced-motion`). `.column.nav-main` gets
  `padding-top: 3rem` so the fixed toggle never obscures the first main-pane
  element.
- Above 768px: the toggle is hidden and the sidebar flows normally via Bulma
  (no change to existing layout); menu items are never hidden at this width.

## Test plan

System spec in `spec/system/responsive_nav_flow_spec.rb` (leveraging `rack_test`
driver; CSS breakpoint rendering and overlay styling deferred to manual browser
testing):

1. **Markup structure** (all viewport sizes):
   - `input#nav-drawer.nav-drawer-toggle[type=checkbox]` is present.
   - `label.nav-toggle` with text "Menu" is linked to it (`for="nav-drawer"`).
   - `div.nav-sidebar.column.is-narrow` follows the checkbox (so the
     `:checked ~ .nav-sidebar` selector applies).
   - `div.nav-main.column` wraps the main content.
   - All nav links (Inbox, Overdue, Today, Upcoming, Completed, New task,
     Manage projects, Manage labels) are clickable and navigate correctly.

2. **Toggle behavior**: clicking the "Menu" label checks / unchecks the
   checkbox, so the drawer opens and closes.

3. **Page navigation**: navigating to another page re-renders the checkbox
   unchecked (drawer closed); production Turbo behavior is unaffected.

## CSS breakpoint and overlay rendering

The 768px media query and fixed-position overlay styling cannot be asserted
programmatically via `rack_test` (no rendering engine, no viewport resize).
Verify these manually in a real browser:
- Resize to ≤768px width → "Menu" button appears at top-left; nav sidebar is
  hidden (main pane full-width).
- Resize to >768px width → "Menu" button disappears; nav and main pane display
  side-by-side with the sidebar visible.
- Click "Menu" to open drawer → checkbox becomes checked; sidebar appears as an
  overlay on top of the main pane with a smooth slide-in animation.
- Click "Menu" again to close → checkbox unchecked; sidebar is hidden
  immediately (no exit animation exists — close is instant).
- Navigate to another page → drawer closes automatically (checkbox re-rendered
  unchecked).

Cross-browser: the checkbox disclosure is engine-independent (no reliance on
`<details>` closed-state behavior), so wide-screen visibility and the mobile
toggle behave identically in all modern browsers. Verified in Chromium at
1280px (10/10 sidebar links visible, toggle hidden) and 375px (toggle visible,
drawer opens/ closes).

No new JavaScript or state persistence required — pure CSS checkbox disclosure.

## Edge cases deferred

- Closing the drawer on outside-tap (would require JS; deferred per Q7 grill).
- Closing on Escape key (would require JS).
- Persistent drawer state across page loads (not applicable; Turbo naturally
  resets it by recreating the HTML).

## Files changed

- `app/views/layouts/application.html.erb` — add checkbox + label toggle and
  class names (`nav-toggle`, `nav-sidebar`, `nav-main`) for media-query
  targeting.
- `app/assets/stylesheets/application.css` — add `.nav-drawer-toggle` and
  `.nav-toggle` rules, 768px media query with drawer overlay + toggle styling,
  and a `prefers-reduced-motion` guard for the animation.

No changes to `_navbar.html.erb`, `app/models/task.rb`, or any non-view
files.

## Merge conflicts & rework

None anticipated. Changes are purely additive to layout/CSS; no existing
logic or shared styles touched. On wide screens the toggle is hidden and the
sidebar renders exactly as before, so zero impact to the current desktop
layout.