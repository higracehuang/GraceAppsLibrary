#!/bin/bash
# A quick script to build the GraceAppsLibrary for iOS Simulator to ensure there are no build errors.

echo "Building GraceAppsLibrary..."
xcodebuild -scheme GraceAppsLibrary -destination "generic/platform=iOS Simulator" build

if [ $? -eq 0 ]; then
    echo "✅ Build Succeeded!"
else
    echo "❌ Build Failed!"
    exit 1
fi
