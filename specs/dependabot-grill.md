# Dependabot plan — grill-me Q&A

Repo: mcampbell/my-todoist (public, GitHub). Rails app, Ruby gems only via
Bundler — no package.json/npm, JS deps pinned via importmap. No
.github/workflows exist yet.

## Decisions

1. **Auto-merge**: NO. User merges PRs manually. No CI workflow added.
   Hands-off = low-effort setup, not unattended merging.
2. **Ecosystem**: `bundler` only (derived — no npm/actions deps to update).
3. **Schedule**: weekly, with a 1-week cooldown on new gem versions
   (`cooldown.default-days: 7`) to reduce supply-chain risk from
   freshly-published/compromised releases.
4. **Grouping**: group all patch/minor bumps into one weekly PR to
   minimize manual-merge burden.
5. **Major versions**: excluded from the group — open as their own
   individual PR so they get real review, not a rubber-stamp merge.
6. **Security updates**: enabled separately from version-update config.
   CVE-triggered PRs open immediately, NOT subject to the 7-day cooldown
   (known vuln in current dep != unproven fresh release).

## Not asked (defaults, low stakes for solo repo)
- No reviewers/assignees/labels — single-owner repo.
- open-pull-requests-limit, commit-message prefix, target-branch: leave
  defaults in implementation.
