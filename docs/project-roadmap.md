# GenSnippets: Development Roadmap

**Current Version:** 2.6.1
**Release Date:** 2026-02-08
**Next Planned:** v2.7 (Q2 2026)
**Status:** Active Maintenance

---

## Version History

### ✓ v2.0 - Foundation (2024)
**Status:** Complete

Core text replacement engine with CGEvent monitoring, category management, and UserDefaults persistence. Established MVVM architecture and SwiftUI foundation.

**Key Features:**
- System-wide CGEvent-based keyboard monitoring
- Trie data structure for O(m) command matching
- Category organization
- Menu bar integration
- Three-column UI layout

---

### ✓ v2.1 - Dynamic Keywords (2024)
**Status:** Complete

Dynamic content insertion supporting keywords like clipboard, timestamps, dates, and UUID generation.

**Key Features:**
- Keywords: `{clipboard}`, `{timestamp}`, `{date}`, `{random}`, `{time}`, `{uuid}`
- Regex caching for performance
- Dynamic content at insertion time
- Keyword validation in snippet editor

---

### ✓ v2.2 - Export & Import (2024-2025)
**Status:** Complete

Backup and restore capability with conflict resolution for merged snippets.

**Key Features:**
- JSON export with human-readable format
- Smart import with conflict detection
- Merge resolution UI for overlapping commands
- Batch operations for large collections

---

### ✓ v2.3 - Rich Content (2025)
**Status:** Complete

Support for images, files, and URLs embedded in snippets with sequential insertion.

**Key Features:**
- Image support (base64 encoded)
- File insertion (path-based)
- URL handling (auto-format links)
- Backward-compatible multi-item system
- Sequential paste events (not simultaneous)

---

### ✓ v2.4 - Metafields & Analytics (2025)
**Status:** Complete

Custom placeholder system prompting users for input, plus usage tracking dashboard.

**Key Features:**
- Metafields: `{{field}}` and `{{field:default}}`
- Live preview dialog before insertion
- Usage tracking (command-based)
- Analytics dashboard with top snippets
- Insights view with usage stats

---

### ✓ v2.5 - Compatibility & Customization (2025)
**Status:** Complete

App-specific timing adjustments for browsers, terminals, IDEs. Global hotkey customization.

**Key Features:**
- EdgeCaseHandler for Discord, Chrome, Firefox, Safari
- Terminal/SSH detection with simple mode
- IDE detection (VS Code, JetBrains)
- VM/Remote environment detection
- Customizable global hotkeys (Cmd+Ctrl+S default)
- Keyboard shortcut recorder UI

---

### ✓ v2.6 - Polish & Security (2026-01 to 2026-02)
**Status:** Complete

Modern UI refinements, sandbox hardening, and improved import/export flows.

**Completed in v2.6.0:**
- Share/import redesign (ShareImportSheet)
- Resizable content editor in SnippetDetailView
- Modern settings UI (ModernSettingsView)
- Conflict resolution improvements

**Completed in v2.6.1:**
- JetBrains IDE terminal snippet expansion fix
- Improved event tap recovery
- Enhanced sandbox security configuration
- Hardened runtime configuration

---

## Current Release: v2.6.1

### Released: February 2026

**Bug Fixes:**
- Resolved snippet expansion issue in JetBrains IDE terminals
- Fixed UI rendering after prolonged background operation
- Improved event tap recovery with exponential backoff

**Improvements:**
- Enhanced code signing configuration
- App sandbox hardening
- Event tap robustness

**No Breaking Changes**
- Full backward compatibility with v2.0+

---

## Known Issues (Current)

| Issue | Severity | Impact | Workaround |
|---|---|---|---|
| **File Size: SnippetDetailView** | Medium | Hard to maintain, slow edits | Use Find/Replace carefully |
| **File Size: ThreeColumnView** | Medium | Layout + state mixed | Manual component extraction |
| **No XCTest Coverage** | High | Untested business logic | Manual QA only |
| **iCloud Sync Disabled** | Low | No cloud backup | Use JSON export |
| **Legacy View Duplication** | Low | Code duplication | Keep for compat, remove v3.0 |
| **Mixed Threading Model** | Medium | Potential race conditions | NSLock + DispatchQueue (mitigated) |
| **Code Duplication** | Medium | Clipboard reading, TextFields | Extract to utilities (v2.7) |

---

## Planned: v2.7 (Q2 2026)

### Focus: Code Quality & Test Coverage

**Target Completion:** June 2026

#### Phase 1: Refactoring (Weeks 1-4)

Reduce file sizes and eliminate code duplication:

```
- SnippetDetailView (1,245 LOC)
  ├─ Extract: SnippetContentEditor (200 LOC)
  ├─ Extract: RichContentPicker (300 LOC)
  ├─ Extract: SnippetDetailHeader (100 LOC)
  └─ Remaining: SnippetDetailView (645 LOC)

- ThreeColumnView (1,103 LOC)
  ├─ Extract: ColumnLayout (300 LOC)
  ├─ Extract: StateManagement (200 LOC)
  └─ Remaining: ThreeColumnView (603 LOC)

- Utilities (new)
  ├─ ClipboardHelper.swift (100 LOC)
  ├─ TextFieldBuilder.swift (150 LOC)
  ├─ MenuBuilder.swift (150 LOC)
  └─ Total new: 400 LOC
```

**Success Criteria:**
- All views <400 LOC
- DRY: Single clipboard reading implementation
- Single TextFieldWrapper for all text inputs

#### Phase 2: Unit Test Suite (Weeks 5-8)

Add XCTest coverage for core services:

```
GenSnippetsTests/
├── Services/
│   ├── TextReplacementServiceTests.swift (300 LOC)
│   │   ├─ Trie insertion & matching
│   │   ├─ Buffer management
│   │   ├─ Keyword replacement
│   │   └─ Thread safety
│   │
│   ├── LocalStorageServiceTests.swift (200 LOC)
│   │   ├─ Batch save coalescing
│   │   ├─ Load/decode error handling
│   │   └─ Cache invalidation
│   │
│   ├── MetafieldServiceTests.swift (150 LOC)
│   │   ├─ Metafield extraction
│   │   ├─ Placeholder substitution
│   │   └─ Edge cases (nested, missing)
│   │
│   └── ShareServiceTests.swift (150 LOC)
│       ├─ Import with conflicts
│       ├─ Export format validation
│       └─ Merge logic
│
├── Models/
│   ├── SnippetTests.swift (100 LOC)
│   ├── CategoryTests.swift (50 LOC)
│   └── SnippetUsageTests.swift (50 LOC)
│
└── Views/
    ├── AddSnippetSheetTests.swift (150 LOC)
    ├── ThreeColumnViewTests.swift (150 LOC)
    └── SearchViewTests.swift (100 LOC)

Total Tests: ~1,500 LOC
Target Coverage: >80% (services), >60% (UI)
```

**Success Criteria:**
- All tests pass
- 80%+ coverage on services
- >1,500 test LOC
- No external test dependencies (SwiftUI testing utilities only)

#### Phase 3: Documentation (Weeks 9-10)

Complete API documentation and developer guides:

```
docs/
├── api-reference.md (new)        - Service APIs, method docs
├── testing-guide.md (new)        - How to write tests
├── development-guide.md (new)    - Local dev setup
└── troubleshooting.md (new)      - Common issues & fixes
```

**Success Criteria:**
- All public APIs documented
- Testing patterns documented
- 100% file coverage (every Swift file mentioned)

#### Phase 4: Performance Optimization (Week 11)

Profile and optimize critical paths:

- [ ] Profile Trie matching on 1000+ snippets
- [ ] Optimize batch save coalescing (currently 0.5s)
- [ ] Cache compiled regex patterns
- [ ] Reduce memory footprint of rolling buffer
- [ ] Optimize SwiftUI view rendering (use LazyVStack if needed)

**Success Criteria:**
- Text replacement latency <50ms p99
- App memory <150MB with 1000 snippets
- Batch save overhead <200ms

#### Phase 5: Integration & Testing (Week 12)

Comprehensive integration testing and QA:

- [ ] End-to-end text replacement scenario
- [ ] Import/export round-trip
- [ ] Category management workflows
- [ ] Permission handling (grant/revoke)
- [ ] Browser compatibility (Discord, Chrome, Safari, Firefox)
- [ ] Terminal/SSH detection
- [ ] IDE detection (VS Code, JetBrains)

**Success Criteria:**
- Zero regressions from v2.6.1
- All platforms tested
- User-facing issues documented

---

## Backlog: Future Versions (v2.8+)

### v2.8 - iCloud Sync (Q3-Q4 2026)

Complete partial iCloud sync implementation:

- [ ] CloudKit integration (optional, privacy-respecting)
- [ ] Device synchronization
- [ ] Conflict resolution (last-write-wins or smart merge)
- [ ] Opt-in vs automatic sync
- [ ] Selective sync (categories)

### v2.9 - Snippet Marketplace (2026-2027)

Sharing and discovery platform:

- [ ] Community snippet repository
- [ ] Browse & install shared snippets
- [ ] Snippet rating/reviews
- [ ] Moderation & security scanning
- [ ] One-click install

### v3.0 - Major Cleanup (2027)

Breaking changes and architectural modernization:

- [ ] Remove legacy views (SnippetSearchView, SettingsView, ExportImportView)
- [ ] Remove legacy SnippetsViewModel
- [ ] Migrate UserDefaults → SwiftData (if macOS 14+ required)
- [ ] Minimum macOS 12.0+ (drop Big Sur support if needed)
- [ ] Remove CloudKit opt-in (make mandatory)
- [ ] Consolidate design system

### v3.1+ - Mobile Expansion (2027+)

iPad/iPhone companion apps:

- [ ] iPad app for snippet management
- [ ] iPhone quick access widget
- [ ] Cross-device sync
- [ ] Mobile snippet creation

---

## Success Metrics (v2.7 Target)

| Metric | Current | Target | Notes |
|---|---|---|---|
| **Test Coverage** | 0% | 80%+ (services) | XCTest suite |
| **Max File Size** | 1,245 LOC | <400 LOC | Refactoring |
| **Code Duplication** | 5+ places | 1 place | DRY principle |
| **Text Replacement Latency** | <50ms p95 | <50ms p99 | Profiling |
| **Memory (1000 snippets)** | <150MB | <150MB | No regression |
| **Build Time** | ~30s | <30s | Target maintenance |
| **Crash Rate** | <0.1% | <0.05% | Stability |

---

## Release Timeline

| Version | Release Date | Status | Focus |
|---|---|---|---|
| **v2.6.1** | 2026-02-08 | ✓ Released | Bug fixes, hardening |
| **v2.7.0** | 2026-06-15 (Target) | Planned | Quality, tests, refactor |
| **v2.8.0** | Q3-Q4 2026 | Backlog | iCloud sync |
| **v2.9.0** | 2026-2027 | Backlog | Marketplace |
| **v3.0.0** | 2027 | Backlog | Major cleanup, deprecations |
| **v3.1+** | 2027+ | Backlog | Mobile companion |

---

## Version Support Policy

| Version | Support Status | EOL Date |
|---|---|---|
| **2.6.x** | Current | 2026-06-15 (end of v2.7 beta) |
| **2.5.x** | Legacy | 2026-03-15 |
| **2.4.x** | EOL | 2025-12-15 |
| **2.0-2.3.x** | EOL | 2025-06-15 |

- **Current:** Receives bug fixes and minor features
- **Legacy:** Critical security fixes only
- **EOL:** No support

---

## Key Decisions & Rationale

### Decision: No Third-Party Dependencies

**Status:** ✓ Enforced in v2.0+

**Rationale:**
- Faster app startup
- Smaller app bundle
- Zero dependency updates/security issues
- Better macOS integration with Apple frameworks

**Impact:**
- More code written in-house
- No npm/CocoaPods management
- Full control over functionality

### Decision: Local-Only Storage (No Cloud by Default)

**Status:** ✓ Current (v2.0-2.6)

**Rationale:**
- Privacy-first approach
- No account management
- No network dependency
- Data stays on user's device

**Impact:**
- Manual backup via JSON export
- No cross-device sync (v2.8 will add optional)
- User owns data completely

### Decision: Trie Over Suffix Tree

**Status:** ✓ Current (TextReplacementService)

**Rationale:**
- Simpler implementation
- O(m) performance sufficient (m = command length)
- Lower memory footprint
- Built once per launch

**Impact:**
- OptimizedSnippetMatcher (Bloom Filter + Suffix Tree) unused
- Will remove in v2.7 refactor

### Decision: Single App Target (No Extensions)

**Status:** ✓ Current

**Rationale:**
- Simplifies code (no extension communication overhead)
- Full sandbox app provides enough power
- Browser compatibility handled via EdgeCaseHandler
- Terminal/IDE detection works cross-app

**Impact:**
- No browser extension (would require separate project)
- No system extension needed
- Simpler deployment and support

---

## Unresolved Questions

1. **CloudKit Pricing Model** - Free tier or paid subscription for v2.8+?
2. **Marketplace Moderation** - Community-driven or centralized review?
3. **Mobile First Timeline** - iPad first or iPhone first?
4. **Enterprise Features** - Team management, organization sharing (future)?
5. **Keyboard Layout Support** - Non-QWERTY keyboard detection (future)?

---

**Last Updated:** February 2026
**Maintained By:** Jay Nguyen
**Feedback:** GitHub Issues welcome
