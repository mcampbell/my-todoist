# Rake Tasks

## Overview

Rake tasks to manage the single login user.

## Interface

- `user:create EMAIL=... PASSWORD=...`: makes the login user.
- `user:modify EMAIL=... PASSWORD=...`: changes the password and ends every login.

## Invariants

- Start the command with a space to keep the password out of shell history.
- `user:modify` runs in one transaction. An invalid password changes nothing.

## Side Effects

- Writes the `users` table. `user:modify` deletes all rows in `sessions` for the user.

## Verification

- Run: `bin/rspec spec/tasks/user_rake_spec.rb`
