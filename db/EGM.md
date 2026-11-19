# db

## Overview

SQLite schema and migrations.

## Interface

- `schema.rb`: tables `tasks`, `projects`, `labels`, `task_labels`, `completed_occurrences`, `users`, `sessions`.
- `migrate/`: one file for each schema change.
- `seeds.rb`: empty template.

## Invariants

- `tasks.priority` has a check constraint: 0 to 3.
- `projects.name` and `labels.name` are unique with `NOCASE` collation.
- Deleting a project sets `tasks.project_id` to null.
- `completed_occurrences` keeps names as text. It has no foreign keys.
- Change the schema only with a new migration. Do not edit `schema.rb` by hand.

## Side Effects

- `bin/rails db:prepare` and `db:migrate` write the SQLite files in `storage/`.

## Verification

- Run: `bin/rails db:prepare && bin/rspec`
