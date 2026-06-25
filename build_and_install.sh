#!/bin/bash
set -e

echo "Generating Xcode project..."
xcodegen generate

echo "Building FaceGate..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FaceGate.xcodeproj -scheme FaceGate -destination "platform=macOS" -configuration Debug -derivedDataPath ./build

echo "Killing existing FaceGate processes..."
pkill -f "FaceGate.app/Contents/MacOS/FaceGate" || true
# Alternatively, match the app name exactly:
pkill -x "FaceGate" || true
sleep 1

echo "Removing old FaceGate from /Applications..."
rm -rf /Applications/FaceGate.app

echo "Copying new FaceGate to /Applications..."
cp -R build/Build/Products/Debug/FaceGate.app /Applications/FaceGate.app

echo "Launching new FaceGate app..."
open /Applications/FaceGate.app

echo "Done!"
