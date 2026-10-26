# config/initializers

## Purpose
Code that runs once at Rails boot.

## Files
- assets.rb - asset version "1.0" (Propshaft).
- chronic.rb - sets Chronic.time_class to Time.zone. QuickAdd date parsing depends on it.
- content_security_policy.rb - CSP; only comments, no policy active.
- filter_parameter_logging.rb - filters passw, email, secret, token and similar keys from logs.
- inflections.rb - only comments, no custom rules.

## Rules for agents
- Do not remove chronic.rb. Without it Chronic uses system time, not the app time zone.
- Keep email and passw in filter_parameters. The app has a login.
- Keep initializers small. Put logic in app/ or lib/.

## Verification
- `bin/rspec`
- `bin/rubocop`
- `bin/brakeman` after a CSP or filter change.
