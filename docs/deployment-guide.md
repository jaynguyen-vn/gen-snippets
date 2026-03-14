# GenSnippets: Build & Deployment Guide

**Current Version:** 2.8.2
**Target macOS:** 11.5+ (Big Sur and later)
**Build System:** Xcode 13.0+
**Last Updated:** March 14, 2026

---

## Prerequisites

### System Requirements
- **macOS:** 11.5 (Big Sur) or later
- **Xcode:** 13.0+ (for building from source)
- **Disk Space:** 5GB for build artifacts and DerivedData
- **Code Signing:** Apple Developer Team ID configured

### Accounts & Credentials
- **Apple Developer:** Team ID (for code signing)
- **GitHub:** Push access to main branch (for releases)
- **notarytool:** Credentials configured (for notarization)

### Environment Setup
```bash
# Install or update Xcode
xcode-select --install

# Verify Xcode version
xcodebuild -version
# Output should be Xcode 13.0 or later

# Install command line tools if needed
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

---

## Build Commands

### Debug Build

For local development and testing:

```bash
cd GenSnippets
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  -configuration Debug \
  build
```

**Output Location:**
```
~/Library/Developer/Xcode/DerivedData/GenSnippets-{hash}/Build/Products/Debug/GenSnippets.app
```

**Launch Debug Build:**
```bash
open ~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Debug/GenSnippets.app
```

### Release Build

For distribution and DMG packaging:

```bash
cd GenSnippets
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  -configuration Release \
  -arch arm64 -arch x86_64 \
  build
```

**Output Location:**
```
~/Library/Developer/Xcode/DerivedData/GenSnippets-{hash}/Build/Products/Release/GenSnippets.app
```

**Build for Both Architectures:**
```bash
# Universal binary (Apple Silicon + Intel)
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  -configuration Release \
  build
```

### Clean Build

Remove all build artifacts:

```bash
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  clean

# Also clean DerivedData (more thorough)
rm -rf ~/Library/Developer/Xcode/DerivedData/GenSnippets-*
```

### Build with Code Coverage (Future)

When XCTest suite is added (v2.9):

```bash
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  -enableCodeCoverage YES \
  test
```

---

## Version Management

### Update Version Number

Edit `GenSnippets.xcodeproj/project.pbxproj`:

```bash
# Find current version
grep "MARKETING_VERSION" GenSnippets.xcodeproj/project.pbxproj

# Example output:
# MARKETING_VERSION = 2.8.1;
```

**To Update:**

1. Open Xcode: `open GenSnippets.xcodeproj`
2. Select GenSnippets target
3. Go to Build Settings
4. Search for "Marketing Version"
5. Update value (e.g., 2.9.0)

Or edit directly:

```bash
# Using sed (macOS)
sed -i '' 's/MARKETING_VERSION = 2.8.1;/MARKETING_VERSION = 2.9.0;/' \
  GenSnippets.xcodeproj/project.pbxproj
```

### Version Numbering Scheme

**Pattern:** `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes (v3.0 from v2.x)
- **MINOR:** New features, improvements (v2.7 from v2.6)
- **PATCH:** Bug fixes only (v2.6.1 from v2.6.0)

---

## Code Signing

### Configure Team ID

1. **In Xcode:**
   - Select GenSnippets target
   - Build Settings → Code Signing Identity
   - Select your Apple Development Team

2. **In project.pbxproj:**
   ```bash
   grep "DEVELOPMENT_TEAM" GenSnippets.xcodeproj/project.pbxproj
   # Output: DEVELOPMENT_TEAM = XXXXXXXXXX;
   ```

3. **Update Team ID (if needed):**
   ```bash
   # Replace XXXXXXXXXX with your actual team ID
   sed -i '' 's/DEVELOPMENT_TEAM = XXXXXXXXXX;/DEVELOPMENT_TEAM = ABC123XYZ;/' \
     GenSnippets.xcodeproj/project.pbxproj
   ```

### Verify Code Signing

```bash
# Check app signature
codesign -v -v ~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Release/GenSnippets.app

# Output example:
# /path/to/GenSnippets.app: valid on disk
# /path/to/GenSnippets.app: satisfies its Designated Requirement
```

---

## DMG Creation

### Create Installer DMG (with Gatekeeper)

```bash
#!/bin/bash

VERSION="2.8.2"
APP_PATH=~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Release/GenSnippets.app
DMG_DIR="/tmp/dmg-staging-${VERSION}"
DMG_PATH="/tmp/GenSnippets.${VERSION}.dmg"

# Cleanup previous
rm -rf "$DMG_DIR" "$DMG_PATH"

# Create DMG staging directory
mkdir -p "$DMG_DIR"

# Copy app and create symlink to Applications
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG (UDZO = compressed, read-only)
hdiutil create \
  -volname "GenSnippets ${VERSION}" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG created: $DMG_PATH"
ls -lh "$DMG_PATH"

# Cleanup staging
rm -rf "$DMG_DIR"
```

**Save as:** `scripts/create-dmg.sh`

**Usage:**
```bash
chmod +x scripts/create-dmg.sh
./scripts/create-dmg.sh
```

**Output:**
```
/tmp/GenSnippets.2.8.2.dmg (15-20 MB typical)
```

### Notarize DMG (Apple Security)

Required to avoid "unidentified developer" warning on first launch.

```bash
#!/bin/bash

DMG_PATH="/tmp/GenSnippets.2.8.2.dmg"
APPLE_ID="your-apple-id@email.com"
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # Generate at appleid.apple.com
TEAM_ID="XXXXXXXXXX"

# Submit for notarization
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

# Output: Submission ID for tracking
```

**Generate App-Specific Password:**
1. Visit [appleid.apple.com](https://appleid.apple.com)
2. Security → App-Specific Passwords
3. Generate password for "Xcode"
4. Use in notarytool command

**Notarization Status:**
```bash
# Check status with submission ID
xcrun notarytool info {submission-id} \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD"
```

---

## GitHub Release

### Create Release on GitHub

```bash
#!/bin/bash

VERSION="2.8.2"
DMG_PATH="/tmp/GenSnippets.${VERSION}.dmg"
RELEASE_NOTES="Release notes here"

# Create release with DMG attachment
gh release create "v${VERSION}" \
  "$DMG_PATH" \
  --title "v${VERSION}" \
  --notes "$RELEASE_NOTES"
```

**Manual Steps (if gh CLI not available):**

1. Go to [GitHub Releases](https://github.com/jaynguyen-vn/gen-snippets/releases)
2. Click "Draft a new release"
3. Tag: `v2.8.2`
4. Title: `v2.8.2` or `GenSnippets 2.8.2`
5. Description:
   ```markdown
   ## What's New

   ### Bug Fixes
   - Clipboard race condition fix
   - Event tap timeout recovery

   ### Improvements
   - Enhanced clipboard access timing
   - Better error recovery mechanisms

   ### Breaking Changes
   - (if any)

   ## Installation

   Download `GenSnippets.2.8.2.dmg` below and drag GenSnippets to Applications folder.

   ## Requirements

   - macOS 11.5 or later
   - Accessibility permissions
   ```
6. Upload `GenSnippets.2.6.1.dmg`
7. Click "Publish release"

---

## Release Checklist

Before releasing a new version:

### Pre-Release (1 week before)

- [ ] Create release branch: `release/v{VERSION}`
- [ ] Update `MARKETING_VERSION` in project.pbxproj
- [ ] Update `docs/project-roadmap.md` with version status
- [ ] Update all `docs/` files with new version number
- [ ] Run full test suite (when available)
- [ ] Code review of changes
- [ ] Update README.md version badge (if changed)

### Build & Test (3 days before)

- [ ] Clean build: `xcodebuild clean`
- [ ] Debug build: Verify app launches
- [ ] Test core functionality:
  - [ ] Text replacement (plain text)
  - [ ] Keywords: `{clipboard}`, `{timestamp}`, `{date}`
  - [ ] Metafields: `{{name:default}}`
  - [ ] Rich content: images, files, URLs
  - [ ] Categories: create, edit, delete
  - [ ] Snippet CRUD: add, edit, delete, search
  - [ ] Import/export: backup and restore
  - [ ] Settings: hotkey, permissions
  - [ ] Permission handling: grant/revoke
- [ ] Test terminal compatibility: iTerm2, Ghostty, Terminal.app
- [ ] Test on different macOS versions (if available)
- [ ] Test on both Apple Silicon (M1/M2) and Intel Macs
- [ ] Performance test: 1000+ snippets
- [ ] Browser compatibility: Discord, Chrome, Safari, Firefox

### Build Release (Release day)

- [ ] Create Release build: `xcodebuild -configuration Release`
- [ ] Verify code signing: `codesign -v -v GenSnippets.app`
- [ ] Create DMG: `./scripts/create-dmg.sh`
- [ ] Notarize DMG (if distributing outside App Store)
- [ ] Verify DMG size and contents
- [ ] Create GitHub release with DMG

### Post-Release (Day after)

- [ ] Monitor crash reports (if App Store distribution)
- [ ] Monitor GitHub issues for regression reports
- [ ] Update website with new version info
- [ ] Announce release (Twitter, community forums, etc.)
- [ ] Merge release branch back to main

---

## Troubleshooting

### Build Fails: "xcrun: error"

**Cause:** Xcode command line tools not installed

**Solution:**
```bash
xcode-select --install
# OR
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Code Signing Error

**Cause:** Team ID not configured or incorrect

**Solution:**
1. Verify Team ID: `grep DEVELOPMENT_TEAM GenSnippets.xcodeproj/project.pbxproj`
2. Check in Xcode: Target → Build Settings → DEVELOPMENT_TEAM
3. Ensure Apple ID is signed into Xcode (Xcode → Preferences → Accounts)

### Build Succeeds but App Won't Launch

**Cause:** Missing accessibility permissions or corrupted cache

**Solutions:**
```bash
# Clear Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/GenSnippets-*

# Rebuild
xcodebuild clean build

# Launch directly
open ~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Debug/GenSnippets.app
```

### DMG Won't Open

**Cause:** Corrupted DMG or insufficient disk space

**Solution:**
```bash
# Verify DMG integrity
hdiutil verify /tmp/GenSnippets.2.8.2.dmg

# Recreate DMG
rm /tmp/GenSnippets.2.8.2.dmg
./scripts/create-dmg.sh
```

### Notarization Fails

**Cause:** App signature invalid or contains issues

**Solutions:**
1. Verify code signing:
   ```bash
   codesign -v -v GenSnippets.app
   spctl -a -v -t install GenSnippets.app
   ```

2. Check notarization logs:
   ```bash
   xcrun notarytool log {submission-id} \
     --apple-id "$APPLE_ID" \
     --password "$APP_PASSWORD"
   ```

3. Re-sign and rebuild:
   ```bash
   xcodebuild clean
   xcodebuild -configuration Release
   ```

---

## Environment Variables (Optional)

For CI/CD automation:

```bash
# Set before building
export DEVELOPMENT_TEAM="ABC123XYZ"
export MARKETING_VERSION="2.8.2"
export CODE_SIGN_IDENTITY="Apple Development"
export PROVISIONING_PROFILE_SPECIFIER=""

# Then build
xcodebuild -project GenSnippets.xcodeproj \
  -scheme "GenSnippets" \
  -configuration Release \
  build
```

---

## CI/CD Integration (Future)

For automated releases via GitHub Actions:

```yaml
# .github/workflows/release.yml (example for v2.9+)
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Release
        run: |
          xcodebuild -project GenSnippets/GenSnippets.xcodeproj \
            -scheme GenSnippets \
            -configuration Release \
            build
      - name: Create DMG
        run: ./scripts/create-dmg.sh
      - name: Upload Release
        uses: softprops/action-gh-release@v1
        with:
          files: /tmp/GenSnippets.*.dmg
```

---

## Gatekeeper & Code Signing Reference

### For Users: Bypass Gatekeeper on First Launch

If you get "unidentified developer" warning:

**GUI Method:**
1. Right-click GenSnippets.app → Open (not double-click)
2. Click "Open" in dialog
3. App launches with permission granted

**Terminal Method:**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/GenSnippets.app

# Then launch
open /Applications/GenSnippets.app
```

---

## Support & Documentation

- **Build Issues:** See Troubleshooting section above
- **Developer Setup:** See `docs/development-guide.md` (future)
- **Code Standards:** See `docs/code-standards.md`
- **Architecture:** See `docs/system-architecture.md`

---

**Last Updated:** March 14, 2026
**Maintainer:** Jay Nguyen
