---
okf_version: "0.1"
---

# my-todoist Knowledge Bundle

Local, single-user Todoist clone. Rails 8.1 / Ruby 3.4 / SQLite / ERB /
RSpec. Wholly LLM-coded — see the repo's `CLAUDE.md` and `specs/` for the
authoritative style reference; this bundle summarizes and cross-links
that material for quick orientation.

* [Architecture](architecture/) - the app as a whole: framework choices, the three parsing grammars, the request/response shape.
* [Models](models/) - the core domain objects and pure-computation classes.
* [Features](features/) - user-facing capabilities built on top of the models.
* [Decisions](decisions/) - notable design calls and the reasoning behind them, distilled from `specs/*-design.md` and `*-grill.md`.
