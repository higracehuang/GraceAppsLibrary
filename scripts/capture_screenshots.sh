#!/usr/bin/env bash
#
# capture_screenshots.sh (GraceAppsLibrary Universal Runner)
# Automated App Store simulator screenshot capture across all presets and languages.
#
# Usage:
#   capture_screenshots.sh --bundle <BUNDLE_ID> [options]
#
# Options:
#   --bundle <id>         Required. Bundle identifier of the app (e.g. com.deelightfullabs.ReadingLog)
#   --app-path <path>      Path to compiled .app bundle in DerivedData (auto-detected if omitted)
#   --output-dir <dir>     Directory to save screenshots (default: ./Screenshots/Raw)
#   --iphone-udid <udid>   Explicit iPhone simulator UDID (auto-detects iPhone 17/16 Pro if omitted)
#   --ipad-udid <udid>     Explicit iPad simulator UDID (auto-detects iPad mini/Pro if omitted)
#   --iphone-only          Capture iPhone only
#   --ipad-only            Capture iPad only
#   --both                 Capture both iPhone and iPad (default)
#   --lang <code>          Language: auto (detect from app bundle, default), all, or specific code(s) (en, zh, de, es, ja, fr)
#   --presets "<list>"     Custom preset list formatted as "ID|Filename.png,ID2|Filename2.png"
#

set -euo pipefail

BUNDLE_ID=""
APP_PATH=""
OUTPUT_DIR="$(pwd)/Screenshots/Raw"
IPHONE_UDID=""
IPAD_UDID=""
RUN_IPHONE=true
RUN_IPAD=true
SELECTED_LANG="auto"
CUSTOM_PRESETS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --app-path)
      APP_PATH="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --iphone-udid)
      IPHONE_UDID="$2"
      shift 2
      ;;
    --ipad-udid)
      IPAD_UDID="$2"
      shift 2
      ;;
    --iphone-only|--iphone)
      RUN_IPHONE=true
      RUN_IPAD=false
      shift
      ;;
    --ipad-only|--ipad)
      RUN_IPHONE=false
      RUN_IPAD=true
      shift
      ;;
    --both)
      RUN_IPHONE=true
      RUN_IPAD=true
      shift
      ;;
    --lang)
      SELECTED_LANG="$2"
      shift 2
      ;;
    --presets)
      CUSTOM_PRESETS="$2"
      shift 2
      ;;
    *)
      echo "Unknown flag: $1"
      exit 1
      ;;
  esac
done

if [[ -z "${BUNDLE_ID}" ]]; then
  echo "❌ Error: --bundle <BUNDLE_ID> is required."
  exit 1
fi

# Auto-locate app bundle in DerivedData by matching CFBundleIdentifier if not passed
if [[ -z "${APP_PATH}" ]]; then
  for candidate in $(find ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator -name "*.app" -maxdepth 1 2>/dev/null); do
    if [[ -f "${candidate}/Info.plist" ]]; then
      candidate_bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${candidate}/Info.plist" 2>/dev/null || true)
      if [[ "${candidate_bid}" == "${BUNDLE_ID}" ]]; then
        APP_PATH="${candidate}"
        break
      fi
    fi
  done
fi

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "❌ Error: Could not locate compiled .app bundle in DerivedData."
  echo "Please build your app first for the iOS Simulator."
  exit 1
fi

echo "📦 Using App Bundle: ${APP_PATH}"

# Device resolution helper
find_simulator() {
  local search_name="$1"
  xcrun simctl list devices available | grep -E "${search_name}" | tail -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true
}

if [[ -z "${IPHONE_UDID}" ]]; then
  for search in "iPhone 17 Pro \(" "iPhone 16 Pro \(" "iPhone 15 Pro \(" "iPhone Pro" "iPhone"; do
    IPHONE_UDID=$(find_simulator "${search}")
    if [[ -n "${IPHONE_UDID}" ]]; then
      break
    fi
  done
fi

if [[ -z "${IPAD_UDID}" ]]; then
  for search in "iPad mini \(A17 Pro\)" "iPad mini" "iPad Pro" "iPad"; do
    IPAD_UDID=$(find_simulator "${search}")
    if [[ -n "${IPAD_UDID}" ]]; then
      break
    fi
  done
fi

# Supported languages: CODE|FOLDER_NAME|APPLE_LANG|APPLE_LOCALE
declare -a ALL_LANGUAGES=(
  "en|English|en|en_US"
  "zh|Simplified Chinese|zh-Hans|zh_CN"
  "de|German|de|de_DE"
  "es|Spanish|es|es_ES"
  "ja|Japanese|ja|ja_JP"
  "fr|French|fr|fr_FR"
)

# Detect project-supported localizations across bundle, Plist, pbxproj, and String Catalogs
detect_project_languages() {
  local bundle_locs=""
  if [[ -d "${APP_PATH}" ]]; then
    bundle_locs=$(swift -e '
      import Foundation
      if let b = Bundle(path: CommandLine.arguments[1]) {
        print(b.localizations.joined(separator: " "))
      }
    ' "${APP_PATH}" 2>/dev/null || true)
  fi

  local plist_locs=""
  if [[ -f "${APP_PATH}/Info.plist" ]]; then
    plist_locs=$(/usr/libexec/PlistBuddy -c "Print :CFBundleLocalizations" "${APP_PATH}/Info.plist" 2>/dev/null | grep -E '^[[:space:]]+[a-zA-Z_-]+' | tr -d ' ' || true)
  fi

  local top_lproj=""
  if [[ -d "${APP_PATH}" ]]; then
    top_lproj=$(find "${APP_PATH}" -maxdepth 1 -name "*.lproj" 2>/dev/null | sed -E 's/.*\/([a-zA-Z_-]+)\.lproj/\1/' || true)
  fi

  local pbx_regions=""
  local pbxproj
  pbxproj=$(find . -maxdepth 3 -name "project.pbxproj" 2>/dev/null | head -n 1 || true)
  if [[ -n "${pbxproj}" && -f "${pbxproj}" ]]; then
    pbx_regions=$(awk '/knownRegions = \(/,/\);/' "${pbxproj}" | grep -E '^[[:space:]]+[a-zA-Z_-]+' | tr -d '\t ,;' || true)
  fi

  local xcstrings_locs=""
  for xcs in $(find . -maxdepth 4 -name "*.xcstrings" 2>/dev/null); do
    local keys
    keys=$(grep -E '^[[:space:]]{4}"[a-zA-Z_-]+"[[:space:]]*:[[:space:]]*\{' "${xcs}" 2>/dev/null | tr -d ' "{:' || true)
    xcstrings_locs="${xcstrings_locs} ${keys}"
  done

  local combined="${bundle_locs} ${plist_locs} ${top_lproj} ${pbx_regions} ${xcstrings_locs}"
  combined=$(echo "${combined}" | tr ',' ' ' | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')

  local detected=()
  for lang_entry in "${ALL_LANGUAGES[@]}"; do
    IFS='|' read -r code name aloc acode <<< "${lang_entry}"
    local code_lower=$(echo "${code}" | tr '[:upper:]' '[:lower:]')
    local aloc_lower=$(echo "${aloc}" | tr '[:upper:]' '[:lower:]')

    local matched=false
    for token in ${combined}; do
      token=$(echo "${token}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
      if [[ "${token}" == "base" || -z "${token}" ]]; then
        continue
      fi
      if [[ "${token}" == "${code_lower}" || "${token}" == "${aloc_lower}" || "${token}" == "${code_lower}-"* || "${aloc_lower}" == "${token}-"* ]]; then
        matched=true
        break
      fi
    done

    if [[ "${matched}" == "true" ]]; then
      detected+=("${lang_entry}")
    fi
  done

  if [[ ${#detected[@]} -eq 0 ]]; then
    # Fallback to English if no other localizations detected
    detected+=("${ALL_LANGUAGES[0]}")
  fi

  printf '%s\n' "${detected[@]}"
}

declare -a PROJECT_LANGUAGES=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && PROJECT_LANGUAGES+=("${line}")
done < <(detect_project_languages)

declare -a LANGUAGES=()
if [[ "${SELECTED_LANG}" == "all" || "${SELECTED_LANG}" == "auto" || "${SELECTED_LANG}" == "detect" ]]; then
  LANGUAGES=("${PROJECT_LANGUAGES[@]}")
  echo "🌐 Project supports ${#LANGUAGES[@]} localization(s) in ${APP_PATH##*/}:"
  for lang_entry in "${LANGUAGES[@]}"; do
    IFS='|' read -r code name aloc acode <<< "${lang_entry}"
    echo "   • ${name} (${code})"
  done
else
  IFS=',' read -ra REQ_LANGS <<< "${SELECTED_LANG}"
  for req in "${REQ_LANGS[@]}"; do
    req_trimmed=$(echo "${req}" | xargs)
    for lang_entry in "${ALL_LANGUAGES[@]}"; do
      IFS='|' read -r code name aloc acode <<< "${lang_entry}"
      if [[ "${code}" == "${req_trimmed}" || "${name}" == "${req_trimmed}" ]]; then
        LANGUAGES+=("${lang_entry}")
        break
      fi
    done
  done
fi

if [[ ${#LANGUAGES[@]} -eq 0 ]]; then
  echo "❌ Error: Language '${SELECTED_LANG}' is not supported."
  exit 1
fi

# Presets: PRESET_ID|FILENAME
declare -a PRESETS=()
if [[ -n "${CUSTOM_PRESETS}" ]]; then
  IFS=',' read -ra ADAPTED <<< "${CUSTOM_PRESETS}"
  for item in "${ADAPTED[@]}"; do
    PRESETS+=("${item}")
  done
else
  # Default 7 standard GraceApps App Store presets
  PRESETS=(
    "1|01 - Main Benefit.png"
    "2|02 - Primary Feature.png"
    "3|03 - Secondary Feature.png"
    "4|04A - Consistency Calendar.png"
    "4b|04B - Milestone Celebration.png"
    "5|05A - Customization Differentiator.png"
    "5b|05B - Settings and Pro Overview.png"
  )
fi

prepare_device() {
  local udid="$1"
  local name="$2"
  echo "📱 Preparing ${name} (${udid})..."

  local status
  status=$(xcrun simctl list devices | grep "${udid}" | grep -o "(Booted)" || true)
  if [[ -z "${status}" ]]; then
    echo "  → Booting ${name}..."
    xcrun simctl boot "${udid}"
  fi

  xcrun simctl bootstatus "${udid}" >/dev/null 2>&1

  echo "  → Installing latest app..."
  xcrun simctl install "${udid}" "${APP_PATH}"

  echo "  → Bringing simulator into foreground & activating..."
  open -a Simulator --args -CurrentDeviceUDID "${udid}"
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
  sleep 2
}

capture_device() {
  local udid="$1"
  local device_folder="$2"
  local device_label="$3"

  echo ""
  echo "========================================================"
  echo "🚀 Starting Capture for ${device_label}"
  echo "========================================================"

  for lang_entry in "${LANGUAGES[@]}"; do
    IFS='|' read -r lang_code lang_folder apple_lang apple_locale <<< "${lang_entry}"
    local target_dir="${OUTPUT_DIR}/${device_folder}/${lang_folder}"
    mkdir -p "${target_dir}"

    echo ""
    echo "🌐 Language: ${lang_folder} (${apple_lang} / ${apple_locale})"
    echo "📂 Target Directory: ${target_dir}"

    for preset_entry in "${PRESETS[@]}"; do
      IFS='|' read -r preset_id filename <<< "${preset_entry}"
      local out_file="${target_dir}/${filename}"

      echo "  📸 Capturing preset [${preset_id}] -> ${filename}..."

      # Terminate any running instance and wait for process cleanup
      xcrun simctl terminate "${udid}" "${BUNDLE_ID}" 2>/dev/null || true
      sleep 1.0

      # Launch with screenshot preset and language override
      xcrun simctl launch "${udid}" "${BUNDLE_ID}" \
        -SCREENSHOT_PRESET "${preset_id}" \
        -SCREENSHOT_LANG "${lang_code}" \
        -AppleLanguages "(${apple_lang})" \
        -AppleLocale "${apple_locale}" >/dev/null

      # Initial wait for cold-launch, view animation and seeding
      sleep 4.5

      # Verification loop: ensure the app has transitioned off the splash/launch screen
      local max_retries=6
      local attempt=0
      while [[ ${attempt} -lt ${max_retries} ]]; do
        xcrun simctl io "${udid}" screenshot "${out_file}" >/dev/null 2>&1

        local is_ready
        is_ready=$(python3 -c "
import sys
from PIL import Image
import numpy as np
try:
    img = Image.open(sys.argv[1]).convert('RGB')
    arr = np.array(img)
    colors = len(np.unique(arr.reshape(-1, 3), axis=0))
    bot_std = arr[-200:-50, :].std()
    top_std = arr[60:180, :].std()
    # Launch screen has <= 1800 colors and solid uniform top & bottom areas
    if colors > 2000 and (bot_std > 2.0 or top_std > 2.0 or '${preset_id}' == '4b'):
        print('ready')
    elif colors > 3000:
        print('ready')
    else:
        print('waiting')
except Exception:
    print('ready')
" "${out_file}" 2>/dev/null || echo "ready")

        if [[ "${is_ready}" == "ready" ]]; then
          break
        fi

        attempt=$((attempt + 1))
        echo "     ⏳ View still rendering (attempt ${attempt}/${max_retries}), waiting 1.0s..."
        sleep 1.0
      done

      # Terminate to keep clean
      xcrun simctl terminate "${udid}" "${BUNDLE_ID}" 2>/dev/null || true

      if [[ -f "${out_file}" ]]; then
        local dims
        dims=$(sips -g pixelWidth -g pixelHeight "${out_file}" 2>/dev/null | awk '/pixel/ {printf "%s ", $2}' | tr -d '\n')
        echo "     ✅ Saved (${dims}px, verified content)"
      else
        echo "     ❌ Failed to save screenshot"
      fi
    done
  done
}

if [[ "${RUN_IPHONE}" == "true" ]]; then
  prepare_device "${IPHONE_UDID}" "iPhone"
  capture_device "${IPHONE_UDID}" "iPhone" "iPhone"
fi

if [[ "${RUN_IPAD}" == "true" ]]; then
  prepare_device "${IPAD_UDID}" "iPad"
  capture_device "${IPAD_UDID}" "iPad" "iPad"
fi

echo ""
echo "========================================================"
echo "🎉 All screenshots captured successfully!"
echo "========================================================"
