# Design: "q" global shortcut for new task

No grill doc — scope fits one function, single design per mc-design rules.

## Premise

Todoist's "q" opens a global quick-add overlay. This app has no overlay:
`/tasks/new` (`app/views/tasks/new.html.erb`) renders `_quick_add_form.html.erb`,
whose title field already has `autofocus: true`
(`app/views/tasks/_quick_add_form.html.erb:28`). Building a modal to match
Todoist's UI would be new scope no one asked for (YAGNI) — reuse the existing
page instead. "q" navigates there; the existing autofocus does the rest.

## Implementation

One function, `app/javascript/application.js` (currently imports only
`@hotwired/turbo-rails` and `notifications` — confirmed by reading the file,
no keydown/keyup handling exists anywhere in the app):

```js
document.addEventListener("keydown", (event) => {
  if (event.key !== "q") return
  if (event.ctrlKey || event.metaKey || event.altKey) return

  const tag = event.target.tagName
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
  if (event.target.isContentEditable) return

  event.preventDefault()
  Turbo.visit("/tasks/new")
})
```

- Target-tag and modifier guards stop "q" firing while a user is typing it
  into the title field, the (only) other text input in the app
  (`_quick_add_form.html.erb:28`; confirmed no other text/search input exists
  anywhere in the layout or navbar — scout check of `app/views/layouts/` and
  `_navbar.html.erb`).
- `Turbo.visit` (already loaded, `@hotwired/turbo-rails`) gives an in-app
  navigation instead of a full reload — no new import.
- No Stimulus controller: a document-level listener needs no element to
  attach to, and Stimulus isn't installed anywhere in the app (confirmed —
  no `app/javascript/controllers/` directory). Adding the dependency for one
  listener would be new scope, not reuse.
- Hardcoded path `"/tasks/new"` rather than route helper — this app has no
  Node tooling/JS routes gem, and the path is a stable Rails resourceful
  route (`resources :tasks`, `config/routes.rb:4`).

## Deferred / explicitly out of scope

- Any in-page overlay/modal quick-add — not built anywhere in this app;
  out of scope unless requested separately.
- Other Todoist shortcuts (`a` for task, `t` for today, etc.) — only "q" was
  asked for.

## Test plan

No JS test framework in this repo (no Node tooling, confirmed via
`config/importmap.rb` — Propshaft + Importmap only). Manual browser check:
press "q" on a page with focus outside any input → lands on `/tasks/new`
with the title field focused; press "q" while typing in the title field →
types a literal "q", no navigation.

## Merge conflict / rework

None — new code only, one file, no existing logic touched.
