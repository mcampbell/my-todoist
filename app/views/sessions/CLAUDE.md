# app/views/sessions

## Purpose

Login page. Auth lives in the `Authentication` concern.

## Files

- `new.html.erb` - sign-in form. `form_with url: session_path`. Fields: `email_address`, `password` (maxlength 72).

## Rules for agents

- Controller opts out with `allow_unauthenticated_access`. Do not add data that needs a login.
- No `return_to` field. The concern stores the post-login URL.
- Build URLs with route helpers in ERB. JS-facing URLs use `appPath("/...")` (`app/javascript/app_path.js`), never a bare `"/..."` literal.

## Verification

- `bin/rspec` (full suite)
- `bin/rubocop` (lint)
