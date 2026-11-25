# Pre-Release Smoke Test Generation (`SMOKE_TEST.md`)

Every app using `GraceAppsLibrary` must maintain a `SMOKE_TEST.md` file (at the project root, `AppInfo/SMOKE_TEST.md`, or `ProjectInfo/SMOKE_TEST.md`). `GALValidatorPlugin` enforces its presence and structure on every Xcode build.

## When to Update `SMOKE_TEST.md`

- Before any App Store / TestFlight release.
- Whenever commits have landed after the latest release tag and you are preparing a release check.

## Agent Workflow

1. **Find the latest release tag**:
   ```bash
   git describe --tags --abbrev=0
   ```
   (If the repo has no release tags yet, use `Since Tag: none (initial release)` and inspect `git log --oneline -n 30`.)

2. **Inspect commits since that tag**:
   ```bash
   git log <tag>..HEAD --oneline
   git diff --stat <tag>..HEAD
   ```

3. **Write/update `SMOKE_TEST.md`** with:
   - A `Since Tag: <tag>` header line (required by `GALValidatorPlugin`).
   - Actionable, user-facing `- [ ] ...` checklist items grouped by area (Core Flows, Monetization/Paywall, Ads, Watch/Widgets, Localization, etc.) derived from the commits since `<tag>`.
   - Always include baseline sanity checks if relevant commits touched `GraceAppsLibrary`, IAPs, ads, or onboarding.

## Required Format

```markdown
# Pre-Release Smoke Tests

Since Tag: release-1.0.0

## Changes Since `release-1.0.0`
- [ ] Verify <feature/fix from commit 1>
- [ ] Verify <feature/fix from commit 2>

## Core Regression
- [ ] Cold launch, onboarding/paywall, and settings links
```

## Pre-Release Verification Script

Run from an app repository root to verify `SMOKE_TEST.md` matches the latest release tag:
```bash
../GraceAppsLibrary/scripts/check_smoke_test.sh
```
