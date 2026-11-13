#!/usr/bin/env bash
#
# install-to-ios.sh
# Universal CLI installer for iOS debug binaries using Apple's `xcrun devicectl`.
# Works with any iOS project / .app / .ipa bundle.
#
set -euo pipefail

# ANSI colors
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BOLD}Usage:${NC} $(basename "$0") [options] [path/to/App.app]

${BOLD}Options:${NC}
  -d, --device <name|id>   Target device name or identifier (auto-detected if omitted)
  -l, --launch             Launch the app on the device after installing
  -b, --build              Build the project using xcodebuild before installing
  -c, --configuration <c>  Build configuration (default: Debug)
  -s, --scheme <s>         Xcode scheme to build (auto-detected if omitted)
  -n, --dry-run            Show what would be installed without executing
  -h, --help               Show this help message

${BOLD}Examples:${NC}
  # Install and launch the current directory's Xcode project debug build:
  $(basename "$0") --launch

  # Install a specific .app bundle:
  $(basename "$0") /path/to/MyApp.app

  # Force build and install onto a specific device:
  $(basename "$0") --build -d \"iPhone\" -l"
    exit 0
}

TARGET_DEVICE=""
APP_PATH=""
DO_LAUNCH=false
DO_BUILD=false
DRY_RUN=false
BUILD_CONFIG="Debug"
TARGET_SCHEME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device)
            TARGET_DEVICE="$2"
            shift 2
            ;;
        -l|--launch)
            DO_LAUNCH=true
            shift
            ;;
        -b|--build)
            DO_BUILD=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--configuration)
            BUILD_CONFIG="$2"
            shift 2
            ;;
        -s|--scheme)
            TARGET_SCHEME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$APP_PATH" ]]; then
                APP_PATH="$1"
                shift
            else
                echo -e "${RED}Unknown argument: $1${NC}"
                usage
            fi
            ;;
    esac
done

# Ensure xcrun devicectl is available
if ! command -v xcrun &>/dev/null || ! xcrun devicectl --version &>/dev/null; then
    echo -e "${RED}Error: 'xcrun devicectl' is not available. Please ensure Xcode Command Line Tools are installed.${NC}"
    exit 1
fi

# Detect connected iOS device if not specified
if [[ -z "$TARGET_DEVICE" ]]; then
    echo -e "${CYAN}==>${NC} Discovering connected iOS devices..."
    
    # Use python to parse devicectl json output
    DEVICES_JSON=$(xcrun devicectl list devices -j - 2>/dev/null || true)
    
    DEVICE_INFO=$(python3 -c '
import json, sys

raw = sys.stdin.read()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

connected = []
standby = []

for d in data.get("result", {}).get("devices", []):
    conn = d.get("connectionProperties", {})
    hard = d.get("hardwareProperties", {})
    dev = d.get("deviceProperties", {})

    # Match physical iOS devices (iPhone / iPad) that are paired and reachable
    if hard.get("reality") == "physical" and hard.get("platform") == "iOS":
        tunnel = conn.get("tunnelState", "")
        pairing = conn.get("pairingState", "")
        
        info = {
            "id": d.get("identifier"),
            "name": dev.get("name", "Unknown").strip(),
            "model": hard.get("marketingName") or hard.get("deviceType", "iPhone"),
            "status": "connected" if tunnel == "connected" else "standby"
        }

        if tunnel == "connected":
            connected.append(info)
        elif pairing == "paired" and tunnel != "unavailable":
            standby.append(info)

# Prefer currently connected over standby
available = connected if connected else standby

for item in available:
    dev_id = item["id"]
    dev_name = item["name"]
    dev_model = item["model"]
    status = item["status"]
    print(f"{dev_id}\t{dev_name}\t{dev_model}\t{status}")
' <<< "$DEVICES_JSON")

    DEVICE_COUNT=$(echo -n "$DEVICE_INFO" | grep -c '^' || true)

    if [[ "$DEVICE_COUNT" -eq 0 ]]; then
        echo -e "${RED}Error: No connected physical iOS devices found.${NC}"
        echo "Make sure your iPhone is connected via USB or Wi-Fi, unlocked, and trusted."
        exit 1
    elif [[ "$DEVICE_COUNT" -eq 1 ]]; then
        TARGET_DEVICE=$(echo "$DEVICE_INFO" | cut -f1)
        DEVICE_NAME=$(echo "$DEVICE_INFO" | cut -f2)
        DEVICE_MODEL=$(echo "$DEVICE_INFO" | cut -f3)
        DEVICE_STATUS=$(echo "$DEVICE_INFO" | cut -f4)
        if [[ "$DEVICE_STATUS" == "standby" ]]; then
            echo -e "${GREEN}✓${NC} Found device: ${BOLD}${DEVICE_NAME}${NC} (${DEVICE_MODEL}) via Wi-Fi [Standby]"
            echo -e "${CYAN}==>${NC} Connecting Wi-Fi tunnel to ${DEVICE_NAME}..."
            xcrun devicectl device info lockState --device "$TARGET_DEVICE" >/dev/null 2>&1 || true
        else
            echo -e "${GREEN}✓${NC} Found device: ${BOLD}${DEVICE_NAME}${NC} (${DEVICE_MODEL}) [Connected]"
        fi
    else
        echo -e "${YELLOW}Multiple connected devices found:${NC}"
        INDEX=1
        while IFS=$'\t' read -r id name model status; do
            echo "  [$INDEX] $name ($model) - $status ($id)"
            INDEX=$((INDEX + 1))
        done <<< "$DEVICE_INFO"
        read -r -p "Select device [1-$DEVICE_COUNT]: " SELECTION
        TARGET_DEVICE=$(echo "$DEVICE_INFO" | sed -n "${SELECTION}p" | cut -f1)
        DEVICE_NAME=$(echo "$DEVICE_INFO" | sed -n "${SELECTION}p" | cut -f2)
        echo -e "${GREEN}✓${NC} Selected: ${BOLD}${DEVICE_NAME}${NC}"
        echo -e "${CYAN}==>${NC} Connecting Wi-Fi tunnel to ${DEVICE_NAME}..."
        xcrun devicectl device info lockState --device "$TARGET_DEVICE" >/dev/null 2>&1 || true
    fi
fi

# Detect Xcode project if present in current directory
XCODE_PROJECT=$(find . -maxdepth 1 -name "*.xcodeproj" -o -name "*.xcworkspace" | head -n 1 || true)
PROJECT_NAME=""
if [[ -n "$XCODE_PROJECT" ]]; then
    PROJECT_NAME=$(basename "$XCODE_PROJECT" | sed -E 's/\.(xcodeproj|xcworkspace)$//')
fi

# Handle build flag or missing app path
if [[ "$DO_BUILD" = true ]] || [[ -z "$APP_PATH" ]]; then
    # If no explicit app was given, check for existing build first unless --build was explicitly asked
    FOUND_APP=""
    if [[ "$DO_BUILD" = false ]] && [[ -n "$PROJECT_NAME" ]]; then
        # Check DerivedData for this project (excluding index builds)
        DERIVED_APP=$(find ~/Library/Developer/Xcode/DerivedData -not -path "*/Index.noindex/*" -maxdepth 6 -type d -path "*/${PROJECT_NAME}-*/Build/Products/${BUILD_CONFIG}-iphoneos/${PROJECT_NAME}.app" 2>/dev/null | head -n 1 || true)
        if [[ -n "$DERIVED_APP" ]]; then
            FOUND_APP="$DERIVED_APP"
        fi
        
        # Check local build directory
        if [[ -z "$FOUND_APP" ]] && [[ -d "./build/${BUILD_CONFIG}-iphoneos/${PROJECT_NAME}.app" ]]; then
            FOUND_APP="./build/${BUILD_CONFIG}-iphoneos/${PROJECT_NAME}.app"
        fi
    fi

    if [[ -n "$FOUND_APP" ]]; then
        APP_PATH="$FOUND_APP"
        echo -e "${GREEN}✓${NC} Found existing build: ${CYAN}${APP_PATH}${NC}"
    elif [[ -n "$XCODE_PROJECT" ]]; then
        echo -e "${YELLOW}!${NC} No existing build found. Building ${BOLD}${PROJECT_NAME}${NC}..."
        
        SCHEME_ARG=()
        if [[ -n "$TARGET_SCHEME" ]]; then
            SCHEME_ARG=(-scheme "$TARGET_SCHEME")
        else
            SCHEME_ARG=(-scheme "$PROJECT_NAME")
        fi

        BUILD_DIR="$(pwd)/.build_device"
        xcodebuild \
            "${SCHEME_ARG[@]}" \
            -configuration "$BUILD_CONFIG" \
            -destination "generic/platform=iOS" \
            -derivedDataPath "$BUILD_DIR" \
            build

        APP_PATH=$(find "$BUILD_DIR/Build/Products/${BUILD_CONFIG}-iphoneos" -maxdepth 1 -name "*.app" | head -n 1)
    else
        echo -e "${RED}Error: No .app specified and no Xcode project found in current directory.${NC}"
        usage
    fi
fi

# Validate app bundle exists
if [[ ! -d "$APP_PATH" ]] && [[ ! -f "$APP_PATH" ]]; then
    echo -e "${RED}Error: App not found at path: ${APP_PATH}${NC}"
    exit 1
fi

if [[ "$DRY_RUN" = true ]]; then
    echo -e "${YELLOW}[Dry Run]${NC} Would run:"
    echo "  xcrun devicectl device install app --device \"$TARGET_DEVICE\" \"$APP_PATH\""
    if [[ "$DO_LAUNCH" = true ]]; then
        DRY_BUNDLE_ID="<BundleID>"
        if [[ -f "$APP_PATH/Info.plist" ]]; then
            DRY_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || echo "<BundleID>")
        fi
        echo "  xcrun devicectl device process launch --device \"$TARGET_DEVICE\" $DRY_BUNDLE_ID"
    fi
    exit 0
fi

echo -e "${CYAN}==>${NC} Installing ${BOLD}$(basename "$APP_PATH")${NC} to device (${TARGET_DEVICE})..."
xcrun devicectl device install app --device "$TARGET_DEVICE" "$APP_PATH"
echo -e "${GREEN}✓ App successfully installed!${NC}"

# Launch if requested
if [[ "$DO_LAUNCH" = true ]]; then
    BUNDLE_ID=""
    INFO_PLIST=""

    if [[ -d "$APP_PATH" ]]; then
        INFO_PLIST="$APP_PATH/Info.plist"
    fi

    if [[ -f "$INFO_PLIST" ]]; then
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || true)
    fi

    if [[ -n "$BUNDLE_ID" ]]; then
        echo -e "${CYAN}==>${NC} Launching ${BOLD}${BUNDLE_ID}${NC} on device..."
        xcrun devicectl device process launch --device "$TARGET_DEVICE" "$BUNDLE_ID"
        echo -e "${GREEN}✓ App launched!${NC}"
    else
        echo -e "${YELLOW}Warning: Could not extract Bundle Identifier to launch the app automatically.${NC}"
    fi
fi
