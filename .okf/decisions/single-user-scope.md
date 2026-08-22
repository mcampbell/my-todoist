---
type: Decision
title: No-auth, single-user scope
description: Auth/authz and multi-user concerns are explicitly out of scope for this app.
tags: [scope, security]
timestamp: 2026-08-22T00:00:00Z
---

# Decision

Treat authentication/authorization work as out of scope. The app runs on
a single machine for a single user, with no network exposure.

# Rationale

Stated directly in the repo's `CLAUDE.md`. Removes an entire category of
design questions (session handling, per-user data isolation, CSRF
threat model beyond the default Rails protections) from every feature
built on top of this app.

# Citations

[1] [CLAUDE.md](../../CLAUDE.md)
