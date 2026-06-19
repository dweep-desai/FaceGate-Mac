#!/bin/bash
#
# FaceGate-Mac Installer
# Installs FaceGate.app to /Applications and removes Gatekeeper quarantine.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/dweep-desai/FaceGate-Mac/main/install.sh | bash
#
# Or download and run locally:
#   chmod +x install.sh && ./install.sh
#

set -euo pipefail

APP_NAME="FaceGate"
INSTALL_DIR="/Applications"
GITHUB_REPO="dweep-desai/FaceGate-Mac"
RELEASE_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

# Colors for output.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  🛡️  FaceGate-Mac Installer             │${NC}"
echo -e "${BLUE}│  Lock your apps. Unlock with your face.  │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
echo ""

# Check macOS version.
macos_version=$(sw_vers -productVersion)
major_version=$(echo "$macos_version" | cut -d. -f1)

if [ "$major_version" -lt 13 ]; then
    echo -e "${RED}Error: FaceGate requires macOS 13 (Ventura) or later.${NC}"
    echo -e "Your version: ${macos_version}"
    exit 1
fi

echo -e "${GREEN}✓${NC} macOS ${macos_version} detected"

# Check if FaceGate is already installed.
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo -e "${YELLOW}⚠ FaceGate is already installed at ${INSTALL_DIR}/${APP_NAME}.app${NC}"
    read -p "  Overwrite? (y/N) " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    echo "  Removing existing installation..."
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Create temporary directory for download.
TMPDIR_INSTALL=$(mktemp -d)
trap "rm -rf ${TMPDIR_INSTALL}" EXIT

# Get latest release download URL.
echo ""
echo -e "${BLUE}→${NC} Fetching latest release from GitHub..."

DOWNLOAD_URL=$(curl -sL "$RELEASE_URL" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    assets = data.get('assets', [])
    for asset in assets:
        name = asset.get('name', '')
        if name.endswith('.dmg') or name.endswith('.zip'):
            print(asset['browser_download_url'])
            break
    else:
        print('')
except:
    print('')
" 2>/dev/null)

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${YELLOW}⚠ Could not find a release asset.${NC}"
    echo "  This may mean no releases have been published yet."
    echo ""
    echo "  To install from a local build:"
    echo "    1. Build the project in Xcode"
    echo "    2. Copy FaceGate.app to /Applications"
    echo "    3. Run: xattr -cr /Applications/FaceGate.app"
    echo ""
    echo "  To build from source:"
    echo "    brew install xcodegen"
    echo "    cd FaceGate-Mac"
    echo "    xcodegen generate"
    echo "    open FaceGate.xcodeproj"
    echo "    # Build with Cmd+B"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found release: ${DOWNLOAD_URL##*/}"

# Download the release.
echo -e "${BLUE}→${NC} Downloading..."
DOWNLOAD_FILE="${TMPDIR_INSTALL}/${DOWNLOAD_URL##*/}"
curl -sL -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"

# Handle DMG or ZIP.
if [[ "$DOWNLOAD_FILE" == *.dmg ]]; then
    echo -e "${BLUE}→${NC} Mounting DMG..."
    MOUNT_POINT=$(hdiutil attach -nobrowse -readonly "$DOWNLOAD_FILE" 2>/dev/null | grep "/Volumes" | awk '{print $3}')
    
    if [ -z "$MOUNT_POINT" ]; then
        echo -e "${RED}Error: Failed to mount DMG.${NC}"
        exit 1
    fi

    # Copy app.
    echo -e "${BLUE}→${NC} Installing to ${INSTALL_DIR}..."
    cp -R "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"

    # Unmount.
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

elif [[ "$DOWNLOAD_FILE" == *.zip ]]; then
    echo -e "${BLUE}→${NC} Extracting ZIP..."
    unzip -q "$DOWNLOAD_FILE" -d "$TMPDIR_INSTALL"

    # Find and copy app.
    APP_PATH=$(find "$TMPDIR_INSTALL" -name "${APP_NAME}.app" -maxdepth 2 | head -1)
    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}Error: ${APP_NAME}.app not found in archive.${NC}"
        exit 1
    fi

    echo -e "${BLUE}→${NC} Installing to ${INSTALL_DIR}..."
    cp -R "$APP_PATH" "${INSTALL_DIR}/"
fi

# Remove quarantine attribute (bypasses Gatekeeper for unsigned/unnotarized apps).
echo -e "${BLUE}→${NC} Removing Gatekeeper quarantine..."
xattr -cr "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo ""
echo -e "${GREEN}┌─────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  ✅ FaceGate installed successfully!     │${NC}"
echo -e "${GREEN}└─────────────────────────────────────────┘${NC}"
echo ""
echo -e "  Location: ${INSTALL_DIR}/${APP_NAME}.app"
echo ""

# Offer to open the app.
read -p "  Open FaceGate now? (Y/n) " -n 1 -r < /dev/tty
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open "${INSTALL_DIR}/${APP_NAME}.app"
    echo -e "  ${GREEN}✓${NC} FaceGate is starting! Look for 🛡️ in your menu bar."
fi

echo ""
