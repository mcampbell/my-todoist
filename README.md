# my-todoist

My LLM coded clone of todoist.

Local single-user Todoist clone. Rails 8, SQLite, builtin ERB views, RSpec.
See `specs/` for the design, estimates, and per-slice implementation plans.

## Scope

This app runs on one machine, for one user, and never faces the network.
No authentication, no authorization, and no other security controls are
required. Do not add them. Keep the framework surface small: the app loads
only Active Record, Action Controller, Action View, and Active Model. Do not
add Active Job, Solid Queue, Active Storage, Action Mailer, Action Cable, or a
deployment stack unless a real feature needs it. Slice 6's due reminders are
client-side (a JS poll shows in-page toasts); no background job stack.

## How to Run

Requirements: Ruby 3.4 (see `.ruby-version`). No Node — assets use Propshaft
plus Importmap.

First time:

```
bundle install
bin/rails db:prepare
```

Start the app:

```
bin/rails server
```

Open <http://localhost:3000>. The app is single-user and needs no login.

## Test

```
bin/rspec
```
