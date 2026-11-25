#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${1:-.}"
cd "$APP_ROOT"

SMOKE_FILE="AppInfo/SMOKE_TEST.md"
if [ ! -f "$SMOKE_FILE" ]; then
  echo "❌ Missing $SMOKE_FILE"
  exit 1
fi

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
RECORDED_TAG=$(grep -i "^Since Tag:" "$SMOKE_FILE" | head -n 1 | sed -E 's/^Since Tag:[[:space:]]*//I' | tr -d '\r')

if [ -z "$RECORDED_TAG" ]; then
  echo "❌ $SMOKE_FILE is missing 'Since Tag: <tag>' header"
  exit 1
fi

if [ "$LATEST_TAG" != "none" ] && [[ "$RECORDED_TAG" != *"$LATEST_TAG"* ]]; then
  echo "⚠️  $SMOKE_FILE references '$RECORDED_TAG', but latest git tag is '$LATEST_TAG'"
  echo "   Commits since $LATEST_TAG:"
  git log "${LATEST_TAG}..HEAD" --oneline
  exit 1
fi

if ! grep -qE "^- \[[ xX]\] " "$SMOKE_FILE"; then
  echo "❌ $SMOKE_FILE has no checklist items ('- [ ] ...')"
  exit 1
fi

echo "✅ $SMOKE_FILE is valid (Since Tag: $RECORDED_TAG)"
