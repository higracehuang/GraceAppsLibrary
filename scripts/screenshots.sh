#!/usr/bin/env bash
#
# screenshots.sh (GraceAppsLibrary Universal Entrypoint)
#
# Unified CLI runner for App Store screenshots:
#   - capture: boots simulators and captures raw screenshots into Screenshots/Raw
#   - render / export: builds HTML template and exports App Store frames via headless Chrome
#   - all: runs capture followed by render
#
# Usage:
#   ./scripts/screenshots.sh [all|capture|export] [options]
#
# Options:
#   --config <path>        Path to screenshots.json (default: ./screenshots.json or ./Marketing/screenshots.json)
#   --device <iphone|ipad|all>
#   --lang <code|all>
#   --bundle <bundle_id>   (Optional if specified in screenshots.json)
#   --help                 Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(pwd)"

ACTION="all"
if [[ $# -gt 0 ]]; then
  case "$1" in
    capture|export|render|all)
      ACTION="$1"
      shift
      ;;
  esac
fi

PASSTHROUGH_ARGS=("$@")

if [[ "${ACTION}" == "capture" || "${ACTION}" == "all" ]]; then
  echo "========================================================"
  echo "📸 [1/2] Capturing Raw Simulator Screenshots"
  echo "========================================================"
  bash "${SCRIPT_DIR}/capture_screenshots.sh" "${PASSTHROUGH_ARGS[@]}"
fi

if [[ "${ACTION}" == "export" || "${ACTION}" == "render" || "${ACTION}" == "all" ]]; then
  echo ""
  echo "========================================================"
  echo "🎨 [2/2] Rendering App Store Marketing Frames"
  echo "========================================================"
  python3 "${SCRIPT_DIR}/render_screenshots.py" --project-root "${APP_DIR}" "${PASSTHROUGH_ARGS[@]}"
fi

echo ""
echo "🎉 Screenshot pipeline completed successfully!"
