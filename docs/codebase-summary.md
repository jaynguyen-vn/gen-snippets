# GenSnippets: Codebase Summary

**Total Codebase:** ~15,884 LOC across 48 Swift files
**Architecture:** MVVM + Service Layer with NotificationCenter events
**Primary Framework:** SwiftUI + Accessibility framework
**Deployment Target:** macOS 11.5+
**Current Version:** 2.9.5
**Last Updated:** March 14, 2026

---

## Directory Structure

```
GenSnippets/
├── GenSnippetsApp.swift              512  Main app entry point, AppDelegate, lifecycle
├── DesignSystem.swift              1,070  Design system (colors, typography, DS* components)
├── ValidationScript.swift             287  Self-contained validation tests (no XCTest)
├── StressTest.swift                   130  Event tap stress testing utility
│
├── Services/ (4,377 LOC)
│   ├── TextReplacementService.swift  1,421  Core engine with TrieNode, CGEvent tap, buffer
│   ├── RichContentService.swift        494  Image/file/URL insertion sequencing (file-based storage)
│   ├── OptimizedSnippetMatcher.swift   395  SuffixTree, BloomFilter, EventTapRecoveryManager, PerformanceMonitor
│   ├── LocalStorageService.swift       392  Batch-optimized UserDefaults + caching
│   ├── MetafieldService.swift          377  Dynamic {{field:default}} templating
│   ├── EdgeCaseHandler.swift           316  App-specific timing (terminals, browsers, IDEs, Discord, VMs)
│   ├── ShareService.swift              296  Export/import with conflict resolution
│   ├── AccessibilityPermissionManager  198  Permission request & status checking
│   ├── BrowserCompatibleTextInsertion  175  Browser-specific text insertion
│   ├── GlobalHotkeyManager.swift       158  Carbon-based hotkey registration
│   ├── SandboxMigrationService.swift    65  Sandbox to non-sandbox migration helper
│   ├── LocalizationService.swift        59  English/Vietnamese infrastructure
│   ├── UpdaterService.swift             35  Sparkle auto-update wrapper (singleton)
│   └── iCloudSyncService.swift          31  Disabled stub (incomplete)
│
├── Views/ (8,133 LOC)
│   ├── SnippetDetailView.swift       1,245  Detail pane with rich content editing
│   ├── ThreeColumnView.swift         1,112  Main 3-column layout (categories/snippets/detail)
│   ├── AddSnippetSheet.swift           732  Create/edit snippet modal with validation
│   ├── ShareImportSheet.swift          703  Import snippet sheet with progress
│   ├── ModernSnippetSearchView.swift   611  Global search UI (Cmd+Ctrl+S)
│   ├── ShareExportSheet.swift          396  Export snippet sheet
│   ├── InsightsView.swift              391  Usage analytics dashboard
│   ├── ConflictResolutionView.swift    296  Import merge conflict UI
│   ├── ShortcutRecorderView.swift      275  Keyboard shortcut input recorder
│   ├── ModernSettingsView.swift        277  Current settings UI
│   ├── SimpleSettingsView.swift        265  Simplified settings alternative
│   ├── CategoryDialogs.swift           263  Category create/edit/rename dialogs
│   ├── ShortcutsGuideView.swift        235  Keyboard shortcuts reference
│   ├── CategoryPickerSheet.swift       204  Category selection popup
│   ├── MenuBarView.swift               198  Menu bar popover UI
│   ├── SnippetSearchView.swift         336  Legacy search (replaced, kept for compat)
│   ├── ExportImportView.swift          221  Legacy export/import (replaced)
│   ├── SettingsView.swift              177  Legacy settings (replaced)
│   ├── StatusBarView.swift             100  Status indicator UI
│   ├── ContentView.swift                65  Container view
│   └── ButtonStyles.swift               41  Custom button styling
│
├── Models/ (990 LOC)
│   ├── SnippetUsage.swift              287  Usage tracking model (command-based)
│   ├── LocalSnippetsViewModel.swift    184  Snippet CRUD + batch operations + Base64→file migration
│   ├── CategoryViewModel.swift         143  Category state (alphabetical sorting)
│   ├── Snippet.swift                   136  RichContentType enum, RichContentItem, dual ID fields
│   ├── ShareExportData.swift            93  Export/import data structure
│   ├── Category.swift                   68  Category data model
│   └── SnippetsViewModel.swift          79  Legacy ViewModel (replaced)
│
├── Components/ (185 LOC)
│   └── ToastView.swift                 185  Toast notification component
│
├── Controllers/ (139 LOC)
│   └── SnippetSearchWindowController.swift  Search window management
│
├── Extensions/ (6 LOC)
│   └── String+Localization.swift         6  Localization helper
│
└── Resources/
    ├── Assets.xcassets/                    App icons, accent color
    ├── Localizable.strings (en, vi)        35 localization keys each
    └── GenSnippets.xcodeproj/              Build configuration
```

---

## Service Layer Architecture

### Singleton Services (Shared Pattern)

All services use `static let shared` pattern with thread-safe initialization:

| Service | Responsibility | Key Methods |
|---|---|---|
| **TextReplacementService** | Core text replacement engine, CGEvent monitoring | `start()`, `stop()`, `matchSnippet()` |
| **LocalStorageService** | Batch-optimized UserDefaults persistence | `saveSnippets()`, `loadSnippets()`, `batchSave()` |
| **MetafieldService** | Parse & substitute `{{key:default}}` placeholders | `extractMetafields()`, `promptForValues()`, `substitute()` |
| **RichContentService** | Sequential insertion of images, files, URLs | `insertContent()`, `handleMultipleItems()` |
| **EdgeCaseHandler** | App-specific timing adjustments | `adjustTimingFor()`, `detectApp()` |
| **ShareService** | Import/export with conflict resolution | `exportSnippets()`, `importSnippets()`, `resolveConflicts()` |
| **GlobalHotkeyManager** | Carbon-based global hotkey registration | `registerHotkey()`, `unregisterHotkey()` |
| **AccessibilityPermissionManager** | Permission status & prompting | `requestPermission()`, `checkStatus()` |
| **LocalizationService** | Language switching & key lookup | `localize()`, `setLanguage()` |

### Data Flow

```
User Types → CGEvent Tap (TextReplacementService)
           → Rolling Buffer (50 chars)
           → Trie Suffix Match (O(m))
           → Metafield Dialog (if needed)
           → RichContentService (images/files)
           → EdgeCaseHandler (timing)
           → System Paste Event
           ↓
           UserDefaults ← LocalStorageService (batch, 0.5s coalesce)
           ↓
           SnippetsViewModel/@Published → SwiftUI Views
           ↓
           User sees text replacement
```

### State Management

- **@StateObject** - SnippetsViewModel, CategoryViewModel in ContentView
- **@Published** - Observable properties for reactive updates
- **@Environment** - Design system tokens (DS*)
- **@ObservedObject** - View model binding in child views
- **NotificationCenter** - Cross-component events:
  - `snippetsDidChange`
  - `categoryDidChange`
  - `accessibilityPermissionDidChange`
  - `appLaunchedForFirstTime`
  - `importDidStartProgress`
  - `settingsDidChange`
  - `hotkeysDidChange`
  - `metafieldPromptDismissed`

---

## Core Engine: TextReplacementService (1,317 LOC)

### Trie Data Structure
- Embedded `TrieNode` class for O(m) suffix matching
- Optimized for command-first search
- Longest commands match first (priority)
- Memory efficient at 1000+ snippets

### CGEvent Tap
- System-wide keyboard monitoring (requires Accessibility)
- Running on system event tap thread
- Handles caps lock, modifiers, special characters
- Exponential backoff recovery on failure (max 10s)

### Rolling Buffer
- Maintains last 50 characters typed
- 15-second inactivity timeout
- Thread-safe with NSLock (`bufferLock`)
- Auto-cleanup of old entries

### Keyword Replacement
- **Keywords:** `{clipboard}`, `{cursor}`, `{timestamp}`, `{random-number}`, `{random:min-max}`, `{dd/mm}`, `{dd/mm/yyyy}`, `{time}`, `{uuid}`
- **Cached Regex** - Compiled once per app session
- **Dynamic Clipboard** - Read at insertion time
- **Date Formatting** - Cached formatter instances
- **Metafields:** `{{key}}` and `{{key:default}}` for user input prompts

### Event Processing
1. CGEvent tap captures keystroke
2. Convert key code → character
3. Add to rolling buffer
4. Search Trie for command match (suffix)
5. On match: Delete command, insert replacement
6. Metafield dialog if `{{...}}` present
7. RichContentService for images/files
8. EdgeCaseHandler applies app-specific timing

---

## Threading Model

| Queue | Purpose | Services |
|---|---|---|
| **Main Thread** | All UI updates | Views, ViewModels |
| **snippetQueue** (Concurrent) | Text replacement logic | TextReplacementService |
| **bufferLock** (NSLock) | Rolling buffer thread safety | TextReplacementService |
| **storageQueue** (Concurrent) | UserDefaults access | LocalStorageService |
| **matcerQueue** (Concurrent) | Snippet matching | OptimizedSnippetMatcher |
| **CGEvent Tap Thread** | System keyboard events | TextReplacementService (async to main) |

**Key Rules:**
- Never block main thread (UI responsiveness)
- Barrier writes for cache invalidation
- NSLock for shared mutable state
- Weak self in NotificationCenter observers

---

## Data Models

### Snippet
```swift
struct Snippet: Codable, Identifiable {
  var id: UUID
  var command: String              // Trigger phrase (e.g., "!email")
  var replacementText: String      // Replacement (supports keywords & metafields)
  var category: String             // Category name (default: "Uncategory")
  var isEnabled: Bool              // Active/disabled toggle
  var isFavorite: Bool             // Star for quick access
  var richContentItems: [RichContent]  // Images, files, URLs
}
```

### Category
```swift
struct Category: Codable, Identifiable {
  var id: UUID
  var name: String                 // Unique category name
  var color: String?               // Optional color hex
  var isCollapsed: Bool            // UI state
}
```

### SnippetUsage
```swift
struct SnippetUsage: Codable {
  var command: String              // Keyed by command (not ID)
  var count: Int                   // Times expanded
  var lastUsed: Date               // Recent usage time
}
```

### RichContent
```swift
enum RichContent: Codable {
  case plainText(String)
  case image(path: String)           // File-based since v2.8.0
  case file(path: String)
  case url(String)
}
```

---

## Design System (DesignSystem.swift)

Unified design language via environment objects:

| Category | Components |
|---|---|
| **Colors** | DSAccent, DSBackground, DSText, DSBorder, DSSecondary |
| **Typography** | DSLargeTitle, DSTitle, DSHeadline, DSBody, DSCaption |
| **Spacing** | DSSpacing (8pt grid: xs, sm, md, lg, xl, xxl) |
| **Components** | DSButton, DSTextField, DSPicker, DSToggle (custom styles) |

All views should prefer DS* components over native SwiftUI.

---

## Legacy & Deprecated Code

| File | Status | Reason |
|---|---|---|
| SnippetsViewModel.swift | Deprecated | Replaced by LocalSnippetsViewModel |
| SnippetSearchView.swift | Deprecated | Replaced by ModernSnippetSearchView |
| SettingsView.swift | Deprecated | Replaced by ModernSettingsView |
| ExportImportView.swift | Deprecated | Replaced by ShareImportSheet + ShareExportSheet |
| iCloudSyncService.swift | Disabled | Incomplete implementation |

*Keep for backward compatibility; remove in v3.0*

---

## Performance Characteristics

| Operation | Latency | Note |
|---|---|---|
| Command Match (Trie) | <5ms p95 | O(m) where m=command length |
| Batch Save (1000 snippets) | <200ms | 0.5s coalescing delay |
| App Launch | <500ms | Loads from UserDefaults cache |
| Metafield Dialog | ~50ms | Instant appearance |
| Image Insertion | 100-300ms | Clipboard + CGEvent pasting |
| File Insertion | 50-100ms | Sequential pastes |

---

## Known Issues & Refactoring Targets

| File | LOC | Issue | Priority |
|---|---|---|---|
| SnippetDetailView.swift | 1,245 | Too large, complex editing logic | High |
| ThreeColumnView.swift | 1,112 | Layout + state management mixed | High |
| AddSnippetSheet.swift | 731 | Form validation + rich content picker | Medium |
| ShareImportSheet.swift | 703 | Progress tracking + conflict UI | Medium |
| Code Duplication | N/A | Clipboard reading, TextField wrappers, menu builders | Medium |

**Refactoring Strategy (v2.7):**
1. Extract SnippetDetailView sub-components (editor, previewer, content picker)
2. Split ThreeColumnView into ColumnLayout + state management
3. Create shared ViewBuilders for repetitive UIs
4. Extract clipboard utilities to shared module

---

## Localization

**Supported Languages:** English (en), Vietnamese (vi)

**Key Files:**
- `en.lproj/Localizable.strings` (35 keys)
- `vi.lproj/Localizable.strings` (35 keys)

**Usage:**
```swift
Text("key_name".localized)  // Uses String+Localization extension
```

---

## Build Configuration

- **Minimum Deployment:** macOS 11.5
- **Target:** GenSnippets (single app target)
- **Signing:** Team ID (configured in project.pbxproj)
- **Sandbox:** App Sandbox disabled since v2.7.1 (enabled in earlier versions)
- **Runtime Security:** Hardened runtime with System Events exception
- **Code Signing Identity:** Apple Development

---

## Dependencies

- **[Sparkle 2.x](https://sparkle-project.org/)** — In-app auto-update framework (SPM)

All other dependencies are Apple frameworks:
- SwiftUI (UI)
- Foundation (UserDefaults, NotificationCenter, DateFormatter)
- Accessibility (accessibility framework)
- Carbon (global hotkeys)
- AppKit (NSPasteboard, NSApplication, NSStatusBar)

---

## Compilation & Build

```bash
# Debug build
xcodebuild -project GenSnippets.xcodeproj -scheme GenSnippets \
  -configuration Debug build

# Release build
xcodebuild -project GenSnippets.xcodeproj -scheme GenSnippets \
  -configuration Release build

# Test build
xcodebuild -project GenSnippets.xcodeproj -scheme GenSnippets \
  -enableCodeCoverage YES test
```

**Build Products:**
- Debug: `~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Debug/GenSnippets.app`
- Release: `~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Release/GenSnippets.app`

---

**Last Updated:** March 14, 2026
**Maintainer:** Jay Nguyen
**Version:** 2.9.5
