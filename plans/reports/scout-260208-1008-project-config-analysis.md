# GenSnippets Project Configuration Analysis

## Build Configuration

### Version Information
- Marketing Version: 2.6.1 (from project.pbxproj)
- Build Number: 1
- Built Binary Version: 2.2.0 (outdated)

Version mismatch detected - rebuild required.

### Platform & Language
- macOS Deployment Target: 11.5 (Big Sur minimum)
- Swift Version: 5.0
- Xcode: 16.2
- SDK: macOS 26.1

### Bundle Configuration
- Bundle ID: Jay8448.Gen-Snippets
- Display Name: GenSnippets
- App Category: public.app-category.productivity

### Code Signing
- Code Sign Style: Automatic
- Development Team: 7Q463GFSX8
- Code Sign Identity: Apple Development (ad-hoc for macOS)
- Entitlements: GenSnippets/Gen_Snippets.entitlements

### App Sandbox
Sandbox Enabled: YES

Network Access:
- Incoming: NO
- Outgoing: NO

All Resource Access Disabled:
- Audio, Bluetooth, Calendars, Camera, Contacts, Location, Printing, USB: NO

File Access:
- User Selected Files: Read/Write

Runtime:
- Hardened Runtime: YES
- Dead Code Stripping: YES

### Entitlements
- com.apple.security.temporary-exception.apple-events: [com.apple.systemevents]
  Purpose: Required for keyboard monitoring and text insertion

### Build Settings
- Preview Content: Enabled
- Localization: en, vi (Vietnamese)
- Optimization: Debug (-Onone), Release (whole module)
- Parallel Builds: YES

## Documentation Structure

### Existing
Root:
- README.md - Comprehensive user guide
- CONTRIBUTING.md - Contribution guidelines
- CLAUDE.md - AI assistant guidance

project-docs/:
- GenSnippets-Analysis.md
- README-verification-report.md
- CODEBASE-ANALYSIS.md

techdocs/:
- fix-search-window-activates-main-window.md

### Missing (Per Global Standards)
No /docs directory exists. Should have:
- project-overview-pdr.md
- code-standards.md
- codebase-summary.md
- design-guidelines.md
- deployment-guide.md
- system-architecture.md
- project-roadmap.md

Documentation scattered across project-docs/ and techdocs/.

## Recent Development Activity

Recent Releases:
1. v2.6.1 - JetBrains IDE terminal fix
2. v2.6.0 - Share/import + resizable editor
3. v2.5.1 - UI background fix
4. v2.5.0 - Rich content support
5. v2.4.1 - New placeholders + UX
6. v2.4.0 - Metafield support

Key Changes:
- Code Signing: Unified team ID
- Sandbox: Hardened settings
- Design: Glassmorphism effects
- Performance: Category sorting, usage tracking (ID → command-based)
- Compatibility: Discord/browser timing fixes
- Memory: Leak prevention
- Features: Move snippets, category search, responsive UI

## README.md Summary

Current Version Badge: 2.4.0 (outdated - should be 2.6.1)

Key Features:
- System-wide text replacement via CGEvent
- Trie-based O(m) matching
- Category management
- Dynamic keywords (clipboard, cursor, timestamp, dates, UUIDs)
- Metafields for dynamic input
- Browser compatibility layer
- Usage tracking/insights
- Local-only storage (UserDefaults)
- Export/import
- Global hotkey (Cmd+Ctrl+S)

Architecture Components:
- TextReplacementService (~1,195 lines) - Core engine
- MetafieldService - Dynamic fields
- BrowserCompatibleTextInsertion - Browser timing
- LocalStorageService - Batch persistence
- AccessibilityPermissionManager - macOS permissions
- GlobalHotkeyManager - Carbon hotkeys

Known Issues:
- ThreeColumnView.swift large (~845 lines)
- No test coverage
- Threading race conditions possible
- iCloud sync incomplete
- Browser compatibility requires timing workarounds

## Configuration Analysis

Strengths:
- Strict app sandboxing (security-first)
- Ad-hoc signing (development flexibility)
- Hardened runtime
- Clean entitlements (minimal permissions)
- Swift 5.0 compatibility
- Localization ready (Vietnamese)
- Comprehensive README

Issues:
- Version mismatch: project.pbxproj (2.6.1) vs built binary (2.2.0)
- README badge outdated (2.4.0 vs 2.6.1)
- No /docs directory per global standards
- Documentation scattered
- No deployment guide
- No project roadmap
- No code standards doc
- Build config hardcoded (no xcconfig files)

Security:
- Full sandbox with minimal privileges
- No network access
- Temporary Apple Events exception (required)
- Accessibility permissions (documented)
- Hardened Runtime (code injection protection)

## Recommendations

1. Version Sync: Rebuild app to match 2.6.1
2. Update README: Change badge from 2.4.0 to 2.6.1
3. Documentation: Create /docs, migrate from project-docs/techdocs/, add missing docs
4. Configuration: Consider xcconfig files
5. Testing: Add XCTest suite
6. CI/CD: Add GitHub Actions

## File Locations

- Project Config: GenSnippets.xcodeproj/project.pbxproj
- Entitlements: GenSnippets/Gen_Snippets.entitlements
- Built Binary: build/Release/GenSnippets.app
- Storage: ~/Library/Preferences/Jay8448.Gen-Snippets.plist
- Documentation: README.md, CONTRIBUTING.md, CLAUDE.md, project-docs/, techdocs/

## Unresolved Questions

1. Why built binary (2.2.0) outdated vs source (2.6.1)?
2. Should documentation consolidate into /docs?
3. Is Vietnamese localization actively maintained?
4. What is iCloud sync implementation status?
5. Plans for automated testing?
