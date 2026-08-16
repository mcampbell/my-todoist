# Dependabot design

Single deployable unit — not sliced. One config file + one repo toggle, no
dependencies between them, no parallel work streams to unlock.

## What ships

**1. `.github/dependabot.yml`**

```yaml
version: 2
updates:
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "weekly"
    cooldown:
      default-days: 7
    groups:
      gems:
        applies-to: version-updates
        update-types:
          - "minor"
          - "patch"
    ignore: []
```

- No `open-pull-requests-limit` override — default (5) is fine, grouping
  keeps volume low.
- No `major` update-type in the group → majors excluded automatically,
  Dependabot opens them as individual PRs (default behavior when not
  grouped).
- No reviewers/assignees/labels — solo repo, PR list is enough.

**2. Enable Dependabot security updates** (repo setting, not YAML):

```
gh api -X PUT repos/mcampbell/my-todoist/automated-security-fixes
```

Requires Dependabot alerts enabled first (usually on by default for public
repos — verify, enable if not):

```
gh api -X PUT repos/mcampbell/my-todoist/vulnerability-alerts
```

Security-update PRs bypass `cooldown` and `schedule` — CVE fixes open
immediately, independent of the weekly/grouped config above. This is
GitHub's built-in behavior, nothing to configure for it in the YAML.

## Verification

- `gh api repos/mcampbell/my-todoist/vulnerability-alerts` → 204 = alerts on
- `gh api repos/mcampbell/my-todoist/automated-security-fixes` → 200 with
  `enabled: true`
- Push the YAML, check repo Insights → Dependency graph → Dependabot to
  confirm it parses (GitHub validates on push; malformed YAML shows an
  error there, not a build failure — no CI to catch it otherwise).

## Deferred / out of scope

- CI + auto-merge (user declined — manual merge only)
- github-actions ecosystem entry (nothing to update — no workflows exist)
- npm/yarn ecosystem (no package.json — importmap only)

## Own decision

Skipping ParallelChange / phased-slice treatment entirely — this is a
config artifact, not a code change with callers to migrate. Ship as one
commit.

## Unresolved questions

None — grill-me session closed every branch. One open item that's the
user's call at apply-time, not a design gap: whether to `gh api` the two
security-setting toggles now or leave them for the user to click in repo
Settings → Code security themselves.
