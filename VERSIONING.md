# Versioning Policy

GraceAppsLibrary follows [Semantic Versioning (SemVer)](https://semver.org/) with the format `MAJOR.MINOR.PATCH` (e.g., `1.30.3`):

```
MAJOR . MINOR . PATCH
  │       │       │
  │       │       └── Language additions, bug fixes, & minor maintenance
  │       └────────── New features & backward-compatible additions
  └────────────────── Breaking changes & incompatible API modifications
```

---

## Rules

| Level | Component | When to Bump | Examples |
|---|---|---|---|
| **Major** | `X.0.0` | **Breaking Changes** | • Incompatible API changes<br>• Removing or renaming public methods/types<br>• Altering required parameter signatures<br>• Raising minimum iOS deployment target |
| **Minor** | `0.Y.0` | **New Features** | • Adding new SwiftUI views, sections, or modifiers<br>• Adding new public managers or helper functions<br>• Backward-compatible feature enhancements |
| **Patch** | `0.0.Z` | **Language Additions & Bug Fixes** | • Adding new language localizations (e.g., French, Spanish)<br>• Fixing bugs or layout issues<br>• Updating existing localized strings<br>• Documentation and internal refactoring |

---

## Release Checklist

1. **Translations**: Ensure all `.lproj` folders match the reference keys:
   ```bash
   python3 scripts/check_translations.py
   ```
2. **Build & Tests**: Verify the build succeeds on the simulator target:
   ```bash
   ./scripts/build.sh
   ```
3. **Tagging**: Commit changes and tag the release:
   ```bash
   git tag -a X.Y.Z -m "Release description"
   ```
