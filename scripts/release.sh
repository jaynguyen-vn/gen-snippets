#!/bin/bash
# GenSnippets Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 2.9.0
#
# Prerequisites:
#   - Export GenSnippets.app from Xcode to ~/Downloads/
#   - brew install create-dmg (if not installed)
#   - EdDSA private key in Keychain (already generated)

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./scripts/release.sh <version>"
    echo "Example: ./scripts/release.sh 2.9.0"
    exit 1
fi

APP_PATH="$HOME/Downloads/GenSnippets.app"
DMG_PATH="$HOME/Downloads/GenSnippets.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASES_DIR="$PROJECT_DIR/releases"
SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData/GenSnippets-"*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 0 2>/dev/null | head -1)"
GITHUB_REPO="jaynguyen-vn/gen-snippets"

# Validate prerequisites
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found"
    echo "Export the app from Xcode first (Product → Archive → Distribute App → Direct Distribution)"
    exit 1
fi

if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle tools not found in DerivedData"
    echo "Build the project in Xcode first to download Sparkle package"
    exit 1
fi

echo "=== GenSnippets Release v$VERSION ==="
echo ""

# Step 1: Create DMG
echo "[1/5] Creating DMG..."
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

# Step 2: Copy DMG to releases folder for appcast generation
echo "[2/5] Preparing releases folder..."
mkdir -p "$RELEASES_DIR"
cp "$DMG_PATH" "$RELEASES_DIR/GenSnippets.dmg"
echo "  ✓ DMG copied to releases/"

# Step 3: Generate appcast with Sparkle (auto-signs with EdDSA key from Keychain)
echo "[3/5] Generating appcast.xml..."
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
    "$RELEASES_DIR"
# Move generated appcast to project root
cp "$RELEASES_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
echo "  ✓ appcast.xml updated with v$VERSION"

# Step 4: Commit and push appcast
echo "[4/5] Committing appcast.xml..."
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "release: update appcast for v$VERSION"
git push
echo "  ✓ appcast.xml pushed to main"

# Step 5: Create GitHub release
echo "[5/5] Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "v$VERSION" \
    --generate-notes
echo "  ✓ GitHub release v$VERSION created"

# Cleanup
rm -rf "$RELEASES_DIR"

echo ""
echo "=== Release v$VERSION complete! ==="
echo "Users will be notified of the update automatically."
