# JavaScript

## Overview

Browser code served through Importmap. This project has no Node tooling.

## Interface

- `app_path.js`: `appPath(path)` adds the mount prefix from the `script-name` meta tag.
- `application.js`: midnight page reload, and keys `q` (new task), `/` (search), and `Escape` (cancel).
- `notifications.js`: polls `/tasks/due_since.json` every 30 seconds. Shows in-page toasts and optional OS notifications. A mute toggle is kept in `localStorage`.

## Invariants

- Build every URL with `appPath("/...")`. Never use a bare `"/..."` literal. The app can run under a sub-path such as `/todo`.
- The poll moves its anchor to the server `now` after each good response. On an error it keeps the anchor.
- Due reminders stay client-side. Do not add a background job for them.

## Side Effects

- Sends `fetch` requests to `due_since`.
- Reads and writes `localStorage`. Asks for browser notification permission.

## Verification

- Run: `bin/rspec spec/requests/os_notifications_spec.rb spec/system/notifications_flow_spec.rb`
