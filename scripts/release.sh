#!/bin/bash
# GenSnippets Release Script
# Usage: ./scripts/release.sh
#
# Prerequisites:
#   1. Bump version + build number in Xcode
#   2. Export GenSnippets.app to ~/Downloads/
#   3. Run this script
#
# Dependencies: brew install create-dmg, gh CLI, EdDSA key in Keychain

set -euo pipefail

APP_PATH="$HOME/Downloads/GenSnippets.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASES_DIR="$PROJECT_DIR/releases"
SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData/GenSnippets-"*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 0 2>/dev/null | head -1)"
GITHUB_REPO="jaynguyen-vn/gen-snippets"

# Read version from exported app
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found"
    echo "Export the app from Xcode first (Product → Archive → Distribute App → Direct Distribution)"
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$HOME/Downloads/GenSnippets.${VERSION}.dmg"

if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle tools not found in DerivedData"
    echo "Build the project in Xcode first to download Sparkle package"
    exit 1
fi

echo "=== GenSnippets Release v$VERSION (build $BUILD) ==="
echo ""

# Step 1: Create DMG
echo "[1/4] Creating DMG..."
rm -f "$DMG_PATH"
create-dmg \
    --volname 'GenSnippets' \
    --window-size 500 300 \
    --icon-size 80 \
    --icon 'GenSnippets.app' 150 150 \
    --app-drop-link 350 150 \
    "$DMG_PATH" \
    "$APP_PATH"
echo "  ✓ DMG created: $DMG_PATH"

# Step 2: Generate appcast with Sparkle (auto-signs with EdDSA key from Keychain)
echo "[2/4] Generating appcast.xml..."
rm -rf "$RELEASES_DIR"
mkdir -p "$RELEASES_DIR"
cp "$DMG_PATH" "$RELEASES_DIR/GenSnippets.${VERSION}.dmg"
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
    "$RELEASES_DIR"
cp "$RELEASES_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
rm -rf "$RELEASES_DIR"
echo "  ✓ appcast.xml updated"

# Step 3: Commit and push
echo "[3/4] Committing and pushing..."
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "release: update appcast for v$VERSION (build $BUILD)"
git push
echo "  ✓ Pushed to main"

# Step 4: Create GitHub release
echo "[4/4] Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "v$VERSION" \
    --generate-notes
echo "  ✓ GitHub release v$VERSION created"

echo ""
echo "=== Release v$VERSION complete! ==="
echo "Users will be notified of the update automatically."
