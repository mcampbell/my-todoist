# app

## Overview

The Rails application code: controllers, models, helpers, views, and browser JavaScript.

## Subdirectories & Boundaries

- controllers: [EGM.md](./controllers/EGM.md) - HTML actions behind a login. Scripted access uses the browser login and CSRF token.
- models: [EGM.md](./models/EGM.md) - Active Record models and the pure `QuickAdd`, `Recurrence`, and `PointInTime` grammars.
- helpers: [EGM.md](./helpers/EGM.md) - date, priority, and link display helpers.
- views: [EGM.md](./views/EGM.md) - ERB templates. Forms must pass `return_to`.
- javascript: [EGM.md](./javascript/EGM.md) - Importmap JS. Builds URLs with `appPath`.
- assets: CSS only (Bulma). No contract.
