---
type: Decision
title: Single-user scope, login required
description: One user, internet-facing behind nginx and a login wall; multi-user and authorization stay out of scope.
tags: [scope, security]
timestamp: 2026-10-10T00:00:00Z
---

# Decision

Serve one user. The app may face the internet behind nginx (TLS) and a
login wall (Rails 8 authentication generator, no email password reset;
rake tasks `user:create` and `user:modify` set the password).
Authentication and security work is in scope. Multi-user support and
authorization (per-user data isolation) stay out of scope.

# Rationale

Changed 2026-10-10. The earlier decision (2026-08-22) kept all auth out of
scope because the app ran on one machine with no network exposure. The
owner now deploys it on the internet, so a login wall is required. One
user still means no per-user data, so authorization stays out.

# Citations

[1] [CLAUDE.md](../../CLAUDE.md)
[2] [design/auth.md](../../design/auth.md)
