#!/usr/bin/env bash
#
# preview_video.sh (GraceAppsLibrary Universal Video Entrypoint)
#
# Unified CLI runner for Apple App Store Preview Videos:
#   - record: boots simulator and captures raw recording into Screenshots/Video/
#   - render: composites localized animated text pill overlays and encodes 30fps Apple Preview
#   - all: runs record followed by render
#
# Usage:
#   ./scripts/preview_video.sh [all|record|render] [options]
#
# Options:
#   --config <path>        Path to preview_storyboard.json (default: ./Marketing/preview_storyboard.json)
#   --lang <code|all>      Language code (default: en)
#   --duration <sec>       Recording duration (default: 28s)
#   --device <name>        Simulator device name (default: "iPhone 17 Pro Max")
#   --fastlane             Export directly to fastlane/app-previews/<locale>/
#   --help                 Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(pwd)"

ACTION="render"
if [[ $# -gt 0 ]]; then
  case "$1" in
    record|render|all)
      ACTION="$1"
      shift
      ;;
  esac
fi

PASSTHROUGH_ARGS=("$@")

if [[ "${ACTION}" == "record" || "${ACTION}" == "all" ]]; then
  echo "========================================================"
  echo "📹 [1/2] Recording Simulator App Preview Video"
  echo "========================================================"
  bash "${SCRIPT_DIR}/record_promo_video.sh" "${PASSTHROUGH_ARGS[@]}"
fi

if [[ "${ACTION}" == "render" || "${ACTION}" == "all" ]]; then
  echo ""
  echo "========================================================"
  echo "🎨 [2/2] Rendering Overlays & Encoding 30fps App Preview"
  echo "========================================================"
  python3 "${SCRIPT_DIR}/render_preview_video.py" "${PASSTHROUGH_ARGS[@]}"
fi

echo ""
echo "🎉 App Preview pipeline completed successfully!"
