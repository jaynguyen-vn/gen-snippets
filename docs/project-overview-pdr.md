# GenSnippets: Project Overview & PDR

**Version:** 2.9.8
**Platform:** macOS 11.5+ (Big Sur and later)
**Language:** Swift 5.5+, SwiftUI
**Status:** Active Maintenance
**Bundle ID:** Jay8448.Gen-Snippets
**Release Date:** March 21, 2026

---

## Product Vision

GenSnippets is a macOS menu bar utility that brings professional text expansion to any macOS application. Users create simple "command" triggers that instantly expand into predefined text, URLs, rich content, or dynamic values—eliminating repetitive typing across the entire system.

**Tagline:** "Type less, create more."

---

## Target Audience

1. **Power Users** - Developers, writers, support teams managing frequent repetitive text
2. **Mac Professionals** - Anyone working across multiple applications (browsers, IDEs, email clients, messaging apps)
3. **Content Creators** - Bloggers, marketers, social media managers with template content
4. **System Administrators** - Tech teams deploying standardized snippets across organizations

---

## Core Features (MVP + Completed)

### Essential Text Expansion
- System-wide CGEvent-based keyboard monitoring
- Trie-optimized O(m) command matching
- Auto-cleanup of typed commands
- 50-character rolling buffer with 15-second timeout
- Longer commands take precedence (priority matching)

### Content Types
- Plain text replacements
- Images (file-based storage, migrated from base64 in v2.8.0)
- Files (path-based with sequential insertion)
- URLs (auto-formatted)
- Rich content mixed in single snippet

### Dynamic Keywords
- `{clipboard}` - Current clipboard content
- `{cursor}` - Cursor position marker
- `{timestamp}` - Unix timestamp
- `{random-number}` / `{random:min-max}` - Random integers
- `{dd/mm}`, `{dd/mm/yyyy}` - Date formats
- `{time}` - Current time HH:mm:ss
- `{uuid}` - Unique identifiers

### Metafields (Custom Placeholders)
- `{{field}}` - Prompts user for input
- `{{field:default}}` - Pre-filled default value
- Live preview dialog before insertion
- Perfect for templates with variable content

### Organization & Discovery
- Custom categories with alphabetical sorting
- "Uncategory" for miscellaneous snippets
- Global search (Cmd+Ctrl+S hotkey)
- Usage analytics dashboard
- Snippet usage tracking (most-used sorting)

### Data Management
- 100% offline storage in UserDefaults
- Batch save with 0.5s coalescing
- JSON export/import with conflict resolution
- No cloud sync (by design)
- Privacy-first: zero network access

### macOS Integration
- Menu bar app with snippet count badge
- Optional dock icon
- Launch at login support
- Accessibility permissions auto-prompt
- Specialized browser timing (Discord, Chrome, etc.)
- Terminal/SSH detection with special handling
- IDE detection (VS Code, JetBrains terminals)

### Advanced Features
- Customizable global hotkeys
- Keyboard shortcut recorder
- App-specific timing adjustments (EdgeCaseHandler)
- Multi-language support (English, Vietnamese)
- Toast notifications for user feedback
- Conflict resolution UI for import merges
- Batch operations for performance at 1000+ snippets

---

## Technical Requirements

### Non-Functional Requirements
| Requirement | Target | Status |
|---|---|---|
| **Latency** | <100ms command→replacement | ✓ Achieved (Trie: O(m)) |
| **Max Snippets** | 1000+ | ✓ Tested |
| **Memory Usage** | <150MB | ✓ With caching layer |
| **Accessibility** | WCAG 2.1 AA | Partial |
| **Code Coverage** | >80% | ✗ No tests yet |
| **Startup Time** | <1s | ✓ <500ms typical |
| **Storage Limit** | ~10MB (UserDefaults) | ✓ Batching prevents overflow |

### System Requirements
- **macOS Version:** 11.5 (Big Sur) or later
- **Xcode:** 13.0+
- **Accessibility Permissions:** Required
- **Sandbox:** App Sandbox disabled since v2.7.1 (enabled in earlier versions)
- **Network:** None required (offline-only)

### Dependencies
- [Sparkle 2.x](https://sparkle-project.org/) (auto-update, SPM)
- SwiftUI (built-in)
- Accessibility framework (built-in)
- Carbon framework (global hotkeys)
- Foundation (UserDefaults, NotificationCenter)

### Permissions Required
1. **Accessibility** - System-wide keyboard event monitoring
2. **User-Selected Files** - Read/write via file browser
3. **System Events** - Keyboard simulation (Apple Events, temporary exception)

---

## Success Metrics

### Usage Metrics
- Users save >50 text replacements on average
- 40%+ of typeable applications supported
- >500ms latency in <1% of replacements
- 99.9% uptime of CGEvent tap

### Quality Metrics
- <0.1% crash rate per session
- <5s recovery time if event tap fails
- 0 data loss incidents
- 100% local data safety (no cloud dependency)

### User Satisfaction
- >4.5/5 star rating on Mac App Store
- <5% uninstall rate
- 30%+ daily active user rate
- >70% retention after 30 days

### Performance Metrics
- Command match in <5ms (p95)
- App launch in <500ms
- Batch save <200ms for 1000 snippets
- Memory stable at <100MB under typical load

---

## Version Roadmap

### ✓ v2.0 - Foundation (Initial Release)
- Basic text replacement with CGEvent tap
- Category management
- UserDefaults persistence
- Menu bar UI

### ✓ v2.1 - Dynamic Content
- Keywords: `{clipboard}`, `{timestamp}`, `{date}`, etc.
- Dynamic keyword replacement engine
- Regex caching for performance

### ✓ v2.2 - Export/Import
- JSON export functionality
- Conflict resolution on import
- Batch operations with caching

### ✓ v2.3 - Rich Content
- Image support (base64)
- File insertion support
- Sequential multi-item insertion

### ✓ v2.4 - Metafields & Analytics
- Custom placeholder system `{{key:default}}`
- Live preview dialog
- Usage tracking dashboard
- Command-based usage analytics

### ✓ v2.5 - Browser & IDE Compatibility
- App-specific timing (Discord, browsers, terminals, VMs)
- Global hotkey customization
- Keyboard shortcut recorder
- Browser compatibility refinements

### ✓ v2.6 - Polish & Stability
- Edge case handling for SSH, VMs, IDEs
- Share/import sheet UI overhaul
- Modern settings UI
- Sandbox hardening

### ✓ v2.7 - Disable App Sandbox & UX Improvements
- App Sandbox disabled to improve compatibility
- Improved user experience
- Window management fixes
- Enhanced event tap recovery

### ✓ v2.8 - Image Storage Refactoring
- Image storage migrated from Base64 to file-based (v2.8.0)
- Keystroke hang fixes in iTerm2 and Ghostty (v2.8.1)
- Terminal list sync improvements
- Clipboard race condition fix (v2.8.2)
- Event tap timeout recovery (v2.8.2)

### ✓ v2.9 - Auto-Update & Background Mode
- Sparkle 2.x integration for in-app auto-updates (v2.9.0)
- EdDSA signature verification for secure updates
- Automated release script (`scripts/release.sh`)
- "Check for Updates" menu item and Settings UI
- Auto-enter background mode when launched as login item (v2.9.6)
- Load snippets on startup for background mode text replacement (v2.9.7)
- Fresh window management after login-item background launch (v2.9.8)

### Planned: v2.10+ (Backlog)
- [ ] Unit test coverage (XCTest)
- [ ] iCloud sync completion
- [ ] Cloud backup option
- [ ] Snippet marketplace/sharing
- [ ] Team/organization management
- [ ] Browser extension for web-based input
- [ ] Cross-device sync (iPad companion)

---

## Constraints & Assumptions

### Constraints
1. **macOS Only** - No iOS, Windows, or Linux support planned
2. **Local Storage Only** - No cloud by design (privacy-first)
3. **Accessibility Required** - Cannot work without keyboard monitoring permission
4. **30 LOC max per generated snippet** - Complex templates need external tools
5. **No third-party dependencies** - Pure Apple frameworks only

### Assumptions
1. Users understand text replacement safety (no undo on replacements)
2. Users grant accessibility permissions voluntarily
3. Most snippets <500 chars (typical email signature size)
4. Users managing <1000 snippets at a time
5. No enterprise user authentication needed

---

## Technical Debt & Known Issues

| Issue | Severity | Owner | Status |
|---|---|---|---|
| SnippetDetailView (1,245 LOC) | Medium | Split needed | Planned v3.0 |
| ThreeColumnView (1,112 LOC) | Medium | Component extraction | Planned v3.0 |
| No XCTest coverage | High | Add test suite | Planned v2.9 |
| iCloud sync disabled | Low | Complete implementation | Deferred |
| Legacy view duplicates | Low | Remove old views | Planned v3.0 |
| Code duplication (clipboard, TextFields) | Medium | DRY refactor | Planned v3.0 |
| OptimizedSnippetMatcher unused | Low | Remove in v3.0 | Candidate for removal |

---

## Release Process

1. **Version Bump:** Update `MARKETING_VERSION` in `project.pbxproj`
2. **Changelog:** Update docs with new version
3. **Export:** Archive and export app from Xcode to `~/Downloads/`
4. **Release:** Run `./scripts/release.sh X.Y.Z` (creates DMG, signs with EdDSA, generates appcast, creates GitHub release)

---

## Compliance & Security

- **Privacy:** Zero network access, all data local
- **Sandbox:** App Sandbox disabled since v2.7.1 for improved compatibility
- **Code Signing:** Team ID signing configured
- **Hardened Runtime:** Enabled with necessary exceptions
- **Data Format:** Plain JSON, human-readable, user-editable
- **Accessibility:** Uses private API (CGEvent) - may break on macOS major versions
- **Image Storage:** File-based (not Base64) for better performance and memory efficiency

---

## Glossary

| Term | Definition |
|---|---|
| **CGEvent Tap** | System-level keyboard event monitor requiring Accessibility permission |
| **Metafield** | Custom placeholder like `{{name:default}}` that prompts user for input |
| **Trie** | Tree data structure for O(m) command matching (m = command length) |
| **Snippet** | A single command → replacement mapping with metadata |
| **Category** | User-defined folder for organizing related snippets |
| **Suffix Match** | Match at end of typed text (how triggers activate) |
| **Uncategory** | Default category for snippets without assigned category |
| **Batch Save** | Coalesced writes to UserDefaults with 0.5s delay for performance |

---

**Last Updated:** March 21, 2026
**Next Review:** Q3 2026 (post v2.9 release)
