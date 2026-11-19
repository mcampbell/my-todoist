# config

## Overview

Rails configuration: frameworks, routes, Importmap, Puma, database, and initializers.

## Interface

- `application.rb`: loads only Active Model, Active Record, Action Controller, and Action View. Sets `time_zone` to Eastern.
- `routes.rb`: `resource :session`, `resources :tasks` (no `show`) with member and collection actions, `projects`, `labels`, `completed_occurrences#show`. Root is `tasks#index`.
- `importmap.rb`: pins `application`, `notifications`, `app_path`, and Turbo.
- `initializers/chronic.rb`: sets `Chronic.time_class = Time.zone`.
- `puma.rb`, `database.yml` (SQLite), `environments/`.

## Invariants

- Add another Rails framework only when a feature needs it.
- The database keeps UTC. Views show Eastern time.
- `config/master.key` is secret and ignored by git. Do not commit it.

## Side Effects

- None at runtime beyond Rails boot.

## Verification

- Run: `bin/rspec spec/config`
