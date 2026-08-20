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
APPCAST="$PROJECT_DIR/appcast.xml"
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

# Re-releasing a version already in the feed would leave two items claiming the
# same sparkle:version — Sparkle's choice between them is not something to bet on.
if grep -q "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>" "$APPCAST"; then
    echo "Error: appcast.xml already has an item for $VERSION"
    echo "Bump MARKETING_VERSION / CURRENT_PROJECT_VERSION and re-export first."
    exit 1
fi

echo "=== GenSnippets Release v$VERSION (build $BUILD) ==="
echo ""

# Prompt for release notes
echo "Enter release notes (HTML supported, empty line to finish):"
echo "  Example: <li>Added auto-update</li><li>Bug fixes</li>"
echo "---"
NOTES=""
while IFS= read -r line; do
    [ -z "$line" ] && break
    NOTES="${NOTES}${line}"
done
if [ -n "$NOTES" ]; then
    echo "  ✓ Release notes captured"
else
    NOTES="<li>Bug fixes and improvements</li>"
    echo "  → Using default release notes"
fi

# Step 1: Create DMG
echo "[1/3] Creating DMG..."
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

# Step 2: Sign the DMG and prepend one new item to appcast.xml.
#
# generate_appcast is used only to produce the signed <item> for this release, in a
# throwaway directory. Its own appcast output must NOT be copied over ours: it keeps
# just a rolling window of recent versions (measured: "removed 16 old updates" on this
# feed) and every item we drop is a machine below the current floor losing the last
# build it could run — see the per-item sparkle:minimumSystemVersion note in CLAUDE.md.
echo "[2/3] Signing DMG and updating appcast.xml..."
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp "$DMG_PATH" "$STAGING/GenSnippets.${VERSION}.dmg"
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
    "$STAGING"

python3 - "$APPCAST" "$STAGING/appcast.xml" "$VERSION" "$NOTES" <<'PY'
import re, sys, xml.etree.ElementTree as ET

appcast_path, generated_path, version, notes = sys.argv[1:5]
CHANNEL_ANCHOR = "        <title>GenSnippets</title>\n"

def item_count(text):
    return len(ET.fromstring(text).findall("./channel/item"))

existing = open(appcast_path).read()
generated = open(generated_path).read()

# Take Sparkle's item verbatim so its signature, length and pubDate are exactly
# what it computed; only the release notes are ours to add.
item = next(
    (m.group(0) for m in re.finditer(r"[ \t]*<item>.*?</item>\n?", generated, re.S)
     if f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>" in m.group(0)),
    None,
)
if item is None:
    sys.exit(f"generate_appcast produced no item for {version}")

# Insert the description into THIS item only, ahead of its enclosure. The old
# sed-based injection matched every </sparkle:minimumSystemVersion> in the file,
# which would have stamped these notes onto every historical item too.
enclosure = re.search(r"([ \t]*)<enclosure ", item)
if not enclosure:
    sys.exit(f"item for {version} has no <enclosure>")
indent = enclosure.group(1)
description = f"{indent}<description><![CDATA[<ul>{notes}</ul>]]></description>\n"
item = item[:enclosure.start()] + description + item[enclosure.start():]

if not item.endswith("\n"):
    item += "\n"
if CHANNEL_ANCHOR not in existing:
    sys.exit("appcast.xml has no recognizable channel title to insert after")

updated = existing.replace(CHANNEL_ANCHOR, CHANNEL_ANCHOR + item, 1)

before, after = item_count(existing), item_count(updated)
if after != before + 1:
    sys.exit(f"refusing to write: item count went {before} -> {after}")
first = ET.fromstring(updated).find("./channel/item/title").text
if first != version:
    sys.exit(f"refusing to write: newest item is {first}, expected {version}")

open(appcast_path, "w").write(updated)
print(f"  ✓ appcast.xml: {before} -> {after} items, {version} first")
PY

# Step 3: Commit and push
echo "[3/3] Committing appcast.xml..."
cd "$PROJECT_DIR"
git --no-pager diff --stat appcast.xml
read -r -p "Commit and push this to main? [y/N] " CONFIRM
case "$CONFIRM" in
    [yY]*)
        git add appcast.xml
        git commit -m "release: update appcast for v$VERSION (build $BUILD)"
        git push
        echo "  ✓ Pushed to main"
        ;;
    *)
        echo "  → Skipped. appcast.xml is modified but uncommitted; commit it yourself"
        echo "    or 'git checkout -- appcast.xml' to discard."
        ;;
esac

echo ""
echo "=== Release v$VERSION packaged ==="
echo ""
echo "Next: create the GitHub release and upload the DMG:"
echo "  gh release create v$VERSION $DMG_PATH --repo $GITHUB_REPO --title v$VERSION"
echo ""
echo "Sparkle reads appcast.xml from main, so the enclosure URL 404s until that"
echo "release exists. Check 'gh auth status' first — the active account must have"
echo "write access to $GITHUB_REPO (git push may be going through an SSH alias"
echo "with different credentials than the gh token)."
