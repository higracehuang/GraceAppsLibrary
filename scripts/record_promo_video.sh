#!/usr/bin/env bash
#
# record_promo_video.sh (GraceAppsLibrary Universal Video Recorder)
# Automates simulator video recording for Apple App Store Preview.
#
# Usage:
#   1. Timed Interactive Recording (Records for fixed seconds):
#      ./record_promo_video.sh [duration_seconds] [device_name]
#      ./record_promo_video.sh 28 "iPhone 17 Pro Max"
#
#   2. Automated UI Test Walkthrough (Prebuilds & drives test walkthrough):
#      ./record_promo_video.sh --auto [device_name]
#
# Options:
#   --duration, -d <sec>  Recording duration in seconds (default: 28, Apple max: 30)
#   --device, -D <name>    Target simulator name (default: "iPhone 17 Pro Max")
#   --lang, -l <code>      Language code: en, es, zh-Hans, etc. (default: en)
#   --output-dir <path>    Output directory (default: ./Screenshots/Video)
#   --auto, -a             Drive recording with xcodebuild test
#   --scheme <name>        Xcode scheme for test mode (default: auto-detected)
#

set -euo pipefail

ROOT_DIR="$(pwd)"
OUTPUT_DIR="${ROOT_DIR}/Screenshots/Video"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MODE="interactive"
DURATION=28
DEVICE_NAME="iPhone 17 Pro Max"
LANG_CODE="en"
SCHEME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto|-a)
      MODE="auto"
      shift
      ;;
    --lang|-l)
      LANG_CODE="$2"
      shift 2
      ;;
    --duration|-d)
      DURATION="$2"
      shift 2
      ;;
    --device|-D)
      DEVICE_NAME="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    [0-9]*)
      DURATION="$1"
      shift
      ;;
    *)
      DEVICE_NAME="$1"
      shift
      ;;
  esac
done

OUTPUT_FILE="${OUTPUT_DIR}/promo_recording_${LANG_CODE}_${TIMESTAMP}.mp4"
mkdir -p "${OUTPUT_DIR}"

echo "=========================================================="
echo "🎬 GraceAppsLibrary App Preview Video Recorder"
echo "=========================================================="
echo "Device:    ${DEVICE_NAME}"
echo "Duration:  ${DURATION}s (Apple limit: 15-30s)"
echo "Language:  ${LANG_CODE}"
echo "Mode:      ${MODE}"
echo "Output:    ${OUTPUT_FILE}"
echo "=========================================================="

# 1. Resolve Simulator UDID
echo "🔍 Resolving simulator UDID for '${DEVICE_NAME}'..."
SIM_UDID=$(xcrun simctl list devices available | grep -E "${DEVICE_NAME}" | head -n 1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()' || true)

if [[ -z "${SIM_UDID}" ]]; then
  echo "⚠️ Exact match not found for '${DEVICE_NAME}', falling back to available Pro Max / Plus..."
  SIM_UDID=$(xcrun simctl list devices available | grep -E "iPhone (16|15|14) Pro Max" | head -n 1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()' || true)
fi

if [[ -z "${SIM_UDID}" ]]; then
  echo "❌ Error: Could not find an available simulator."
  exit 1
fi

echo "✅ Target Simulator: ${SIM_UDID}"

# Boot simulator if not booted
STATE=$(xcrun simctl list devices | grep "${SIM_UDID}" | grep -oE '\((Booted|Shutdown)\)' | tr -d '()' || true)
if [[ "${STATE}" != "Booted" ]]; then
  echo "⚡ Booting simulator..."
  xcrun simctl boot "${SIM_UDID}"
  open -a Simulator
  sleep 4
fi

# Clean status bar for marketing (9:41 AM, 100% battery, full wifi/cellular)
echo "📶 Setting clean status bar..."
xcrun simctl status_bar "${SIM_UDID}" override \
  --time "9:41" \
  --dataNetwork "wifi" \
  --wifiMode "active" \
  --wifiBars 3 \
  --cellularMode "active" \
  --cellularBars 4 \
  --batteryState "charged" \
  --batteryLevel 100 2>/dev/null || true

# 2. Record
cleanup() {
  echo ""
  echo "🛑 Stopping screen recording..."
  kill -INT "${RECORDER_PID}" 2>/dev/null || true
  wait "${RECORDER_PID}" 2>/dev/null || true
  xcrun simctl status_bar "${SIM_UDID}" clear 2>/dev/null || true
}

echo "📹 Starting screen recording via simctl..."
xcrun simctl io "${SIM_UDID}" recordVideo --codec h264 "${OUTPUT_FILE}" &
RECORDER_PID=$!
trap cleanup EXIT INT TERM

if [[ "${MODE}" == "auto" ]]; then
  echo "🤖 Automated mode: driving UI tests..."
  if [[ -z "${SCHEME}" ]]; then
    # Auto-detect scheme from xcodeproj in current directory
    SCHEME=$(basename "$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)" .xcodeproj 2>/dev/null || "")
  fi
  if [[ -n "${SCHEME}" ]]; then
    xcodebuild test \
      -scheme "${SCHEME}" \
      -destination "id=${SIM_UDID}" \
      -only-testing:"${SCHEME}UITests" \
      2>&1 | grep -E "(Test Case|passed|failed|Testing)" || true
  else
    echo "⚠️ No scheme specified; sleeping for ${DURATION}s..."
    sleep "${DURATION}"
  fi
else
  echo ""
  echo "⏱️  Recording for ${DURATION} seconds..."
  echo "👉 Perform your app walkthrough in the Simulator window now!"
  for ((i=DURATION; i>0; i--)); do
    printf "\r⏳ Remaining: %2d seconds... " "$i"
    sleep 1
  done
  echo ""
fi

# Trigger clean stop
trap - EXIT INT TERM
cleanup

echo ""
echo "=========================================================="
echo "🎉 RAW RECORDING SAVED:"
echo "Path:      ${OUTPUT_FILE}"
if [[ -f "${OUTPUT_FILE}" ]]; then
  echo "File Size: $(du -h "${OUTPUT_FILE}" | cut -f1)"
fi
echo "=========================================================="
echo "Next step: Run render_preview_video.py to add overlays and export canonical 30fps Apple App Preview."
