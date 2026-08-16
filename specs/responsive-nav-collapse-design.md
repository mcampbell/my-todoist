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
.nav-drawer {
  display: contents;
}

/* Responsive nav drawer for mobile (< 768px) */
@media (max-width: 767.98px) {
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
    list-style: none;
  }
  
  .nav-toggle::-webkit-details-marker {
    display: none;
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
    animation: slideInFromLeft 0.3s ease;
  }
  
  @keyframes slideInFromLeft {
    from { transform: translateX(-100%); }
    to { transform: translateX(0); }
  }
}

/* Wide screens (>= 768px): default Bulma layout */
@media (min-width: 768px) {
  .nav-toggle {
    display: none;
  }
}
```

Breakdown:
- `.nav-drawer { display: contents; }` makes the `<details>` element invisible 
  to layout — its children flow directly into the parent `.columns`.
- Below 768px: toggle button is fixed top-left; nav sidebar is hidden by 
  default and positioned fixed + full height when `<details open>`. A smooth 
  slide-in animation plays when the drawer opens.
- Above 768px: toggle is hidden; sidebar flows normally via Bulma (no change 
  to existing layout).

Rationale for `display: contents`: avoids wrapping the column in an extra
div that would break Bulma's flex layout. The `<details>` is semantic HTML
but doesn't participate in layout this way.

## Test plan

System spec in `spec/system/responsive_nav_flow_spec.rb` (leveraging `rack_test`
driver; CSS breakpoint rendering verification deferred to manual browser testing
or a separate browser-driven suite):

1. **Markup structure** (all viewport sizes):
   - `details#nav-drawer` element is present.
   - `summary.nav-toggle` with text "Menu" is a child of `#nav-drawer`.
   - `div.nav-sidebar.column.is-narrow` wraps the nav (inside details).
   - `div.nav-main.column` wraps the main content.
   - All nav links (Inbox, Overdue, Today, Upcoming, Completed, New task,
     Manage projects, Manage labels) are clickable and navigate correctly.

2. **CSS class targeting** (assertions about class presence, not rendering):
   - `.nav-toggle` has styling (setup verified via class presence on HTML; 
     actual overlay/fixed positioning verified manually in browser due to CSS 
     media query limitations of rack_test).
   - `.nav-sidebar` and `.nav-main` are positioned correctly via class names 
     on the HTML (setup is correct).

3. **Native `<details>` behavior** (pure HTML/DOM, no CSS required):
   - Clicking the `<summary>` toggles the `[open]` attribute on `<details>` 
     (native browser API, works in headless driver).
   - Navigating to another page resets the `<details>` to closed state 
     (Turbo replaces `<body>`, recreating the closed `<details>`; manual 
     verification in browser confirms the drawer re-closes after link clicks).

## CSS breakpoint & overlay rendering

The 768px media query and fixed-position overlay styling cannot be asserted
programmatically via `rack_test` (no CSS engine, no viewport resize).
Verify these manually in a real browser:
- Resize to <768px width → toggle button ("Menu") appears at top-left; nav
  sidebar is hidden (main pane full-width).
- Resize to ≥768px width → toggle button disappears; nav and main pane
  display side-by-side.
- Click "Menu" to open drawer; sidebar appears as an overlay on top of the 
  main pane with a smooth slide-in animation. Click "Menu" again to close. 
  Navigate to another page → drawer closes automatically (Turbo replaces 
  `<body>`).

No new JavaScript or state persistence required — pure CSS + native
`<details>` behavior.

## Edge cases deferred

- Closing the drawer on outside-tap (would require JS; deferred per Q7 grill).
- Closing on Escape key (would require JS).
- Persistent drawer state across page loads (not applicable; Turbo naturally
  resets it by recreating the HTML).

## Files changed

- `app/views/layouts/application.html.erb` — wrap nav in `<details>`, add
  class names for media-query targeting.
- `app/assets/stylesheets/application.css` — add `display: contents` rule
  and 768px media query with drawer overlay + toggle styling.

No changes to `_navbar.html.erb`, `app/models/task.rb`, or any non-view
files.

## Merge conflicts & rework

None anticipated. Changes are purely additive to layout/CSS; no existing
logic or shared styles touched. The `<details>` wrapper is inert on wide
screens (display: contents), so zero impact to the current desktop layout.
