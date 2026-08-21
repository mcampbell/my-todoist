# Esc shortcut: abandon new task

## Grill

Q: What should Esc do on `/tasks/new`?
A: Abandon the in-progress task and go back to the page the user came from —
same destination as the existing "Cancel" link (`safe_return_to` falling
back to the task list).

Q: Reuse the Cancel link's target, or duplicate the return-to logic in JS?
A: Reuse. The server already computes the safe destination
(`TasksController#safe_return_to`, blocks open redirects) and renders it as
the Cancel link's `href`. Esc just clicks that link's destination via
`Turbo.visit`, so there's one source of truth for "where does cancel go."

Q: Scope of the listener?
A: Only active when `window.location.pathname === "/tasks/new"`. No focus
checks needed — Escape is a universal "back out" key regardless of whether
the title input has focus.

## Implementation

`app/javascript/application.js`: second `keydown` listener, sibling to the
existing "q" shortcut. On `Escape` while on `/tasks/new`, reads
`#cancel-link`'s `href` and calls `Turbo.visit`.

`app/views/tasks/_quick_add_form.html.erb`: gave the Cancel link
`id="cancel-link"` so JS can find it.

## Testing

No spec added — same as the "q" shortcut (`specs/q-shortcut-design.md`):
the suite is `rack_test`-only (no Selenium/Cuprite, no `js: true`
anywhere), so keydown behavior isn't exercisable from RSpec.
