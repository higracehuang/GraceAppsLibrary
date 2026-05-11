#!/bin/bash
# A quick script to build the GraceAppsLibrary for iOS Simulator to ensure there are no build errors.

echo "Checking translations..."
python3 scripts/check_translations.py
if [ $? -ne 0 ]; then
    echo "❌ Translation check failed! Please fix inconsistent keys."
    exit 1
fi

echo "Building GraceAppsLibrary..."
xcodebuild -scheme GraceAppsLibrary -destination "generic/platform=iOS Simulator" build

if [ $? -eq 0 ]; then
    echo "✅ Build Succeeded!"
else
    echo "❌ Build Failed!"
    exit 1
fi
