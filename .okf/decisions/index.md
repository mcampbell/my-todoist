# Decisions

* [Single-user scope, login required](single-user-scope.md) - one user behind nginx + login; multi-user/authz out of scope.
* [Browser notifications replace the server notifier](browser-notification-api.md) - browser Notification API + per-browser Mute, so alerts work from a cloud server.
* [OS notification triggered client-side, not from the polling endpoint](os-notification-client-triggered.md) - (deprecated, superseded) code-review-driven fix for a thread-blocking and double-fire bug.
* ["in X unit" gets its own grammar, not Chronic](in-x-unit-own-grammar.md) - why recurrence/duration grammars bypass Chronic.
* [Inbox already shows overdue tasks — no filtering needed](inbox-overdue-no-bug.md) - a reported bug that was actually a test-coverage gap.
* [No JS-capable test driver](no-js-test-driver.md) - why client-JS features ship without RSpec coverage.
