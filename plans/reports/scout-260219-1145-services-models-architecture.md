# GenSnippets Architecture Scout Report
## Services, Models, Controllers & Extensions Analysis

**Date:** Feb 19, 2026 | **Scope:** GenSnippets/Services, Models, Controllers, Extensions  
**Total LOC:** ~4,400 | **Files Analyzed:** 22

---

## SERVICES LAYER (13 files)

### Core Services

#### 1. TextReplacementService.swift (~1,330 LOC)
**Role:** Core text replacement engine with system-wide keyboard monitoring

**Key Classes:**
- `TrieNode` - Embedded suffix tree for O(m) command matching
  - `insert(command: String, snippet: Snippet)` - Insert command into trie
  - `findMatchingSuffix(in text: String) -> Snippet?` - Find matching suffix
  - `search(command: String) -> Snippet?` - Direct command search

- `TextReplacementService` - Singleton managing keyboard interception & text expansion
  - **Cached DateFormatters:** 8 pre-compiled formatters for {timestamp}, {date}, {time}, etc
  - **Thread Safety:** DispatchQueue (concurrent read, barrier write) + NSLock for buffers
  - **Event Tap:** CFMachPort + CFRunLoopSource for low-level keyboard monitoring
  - **Buffer Management:** 50-char rolling buffer with 15-second inactivity timeout

**Key Public Methods:**
- `startMonitoring()` - Setup accessibility permissions & CGEvent tap
- `stopMonitoring()` - Clean up resources, disable event tap
- `updateSnippets(_ snippets: [Snippet])` - Update internal trie & lookup tables
- `replaceText(in text: String) -> String` - Manual snippet replacement
- `insertSnippetDirectly(_ snippet: Snippet)` - Direct insertion (used by search view)
- `getContentForCommand(_ command: String) -> String?` - Retrieve processed snippet content
- `containsCommand(_ text: String) -> Bool` - Check if text contains command suffix

**Special Keyword Processing:**
- Dynamic keywords: `{clipboard}`, `{cursor}`, `{timestamp}`, `{time}`, `{dd/mm}`, `{uuid}`, `{random-number:min-max}`
- Cursor positioning via `{cursor}` marker (removes marker, tracks final position)
- Rich content support via RichContentService integration

**Dependencies:**
- `MetafieldService` - Extract & replace `{{field:default}}` patterns
- `RichContentService` - Handle image/file content insertion
- `EdgeCaseHandler` - App-specific timing/deletion strategies
- `BrowserCompatibleTextInsertion` - Browser timing adjustments (legacy, now in service)
- `UsageTracker` - Record snippet command usage

**Notable Implementation Details:**
- Event tap re-enable logic with exponential backoff (max 5s delay)
- Detects duplicate keystrokes via time + keyCode comparison
- Special handling for Vietnamese IME & combining diacritical marks
- App-specific deletion timing: Discord (4ms), Terminal (1ms), standard (0.5ms)
- Handles keystroke hangs in iTerm2/Ghostty via duplicate detection

---

#### 2. LocalStorageService.swift (~390 LOC)
**Role:** Batch-optimized UserDefaults persistence with caching layer

**Key Classes:**
- `LocalStorageService` - Singleton for snippet/category CRUD
  - **Caching:** In-memory cache with 1000-item size limit
  - **Batch Saves:** 0.5-second debounce timer (prevents excessive writes)
  - **Thread Safety:** DispatchQueue concurrent reads + barrier writes

**Key Public Methods:**
- `saveCategories(_ categories: [Category])` - Queue save with batch debounce
- `loadCategories() -> [Category]` - Load with cache check
- `createCategory(_ category: Category) -> Category` - Create & save
- `updateCategory(_ categoryId: String, _ updated: Category)` - Update & save
- `deleteCategory(_ categoryId: String) -> Bool` - Delete category + associated snippets
- `saveSnippets(_ snippets: [Snippet])` - Queue batch save
- `loadSnippets() -> [Snippet]` - Load with cache check
- `deleteSnippet(_ snippetId: String)` - Delete snippet + cleanup
- `exportData() -> URL?` - Full export (includes Base64 image conversion)
- `importData(from url: URL) -> Bool` - Full import (includes Base64→file conversion)
- `clearAllData()` - Nuclear reset

**Data Flow:**
1. Create/update called → cache updated + pending flag set
2. Batch timer scheduled (0.5s debounce)
3. Timer fires → actual JSON encode/write to UserDefaults
4. On load: cache check first, barrier write on miss

**Dependencies:**
- `RichContentService.shared` - Convert image paths ↔ Base64 during export/import

---

#### 3. AccessibilityPermissionManager.swift (~195 LOC)
**Role:** macOS Accessibility permission request & monitoring

**Key Classes:**
- `AccessibilityPermissionManager` - Singleton for permission lifecycle

**Key Public Methods:**
- `requestAccessibilityPermissions() -> Bool` - Check & prompt for permissions
- `isAccessibilityEnabled() -> Bool` - Check current status
- `showAccessibilityPermissionAlert() -> Bool` - Manual alert display
- `needsRestartAfterPermissionGrant() -> Bool` - Check if restart required

**Permission Flow:**
1. `AXIsProcessTrusted()` - Initial check (silent)
2. If false: `AXIsProcessTrustedWithOptions(prompt: true)` - Show system prompt
3. Start retry timer (2s intervals, max 60s) to detect when user grants permission
4. On grant: post `AccessibilityPermissionGranted` notification + show restart alert

**Logging:** Comprehensive debug info (Bundle ID, Process ID, PID, AX trust status, sandbox container)

---

#### 4. GlobalHotkeyManager.swift (~160 LOC)
**Role:** Global keyboard shortcut registration for snippet search (default: Cmd+Opt+E)

**Key Classes:**
- `GlobalHotkeyManager` - Singleton for hotkey setup

**Key Public Methods:**
- `setupGlobalHotkey()` - Initial registration with accessibility request
- `registerHotkey()` - Register NSEvent monitors for custom shortcut
- `updateShortcut()` - Re-register when shortcut changes

**Implementation:**
- Dual monitors: global (system-wide) + local (app-focused)
- Default: E key (14) + Command+Option modifiers
- Configurable via UserDefaults: `SearchShortcutKeyCode`, `SearchShortcutModifiers`
- 30-second refresh cycle (reduced from 5s for performance)
- Listens for `UpdateSearchShortcut` notification

**Dependencies:**
- `SnippetSearchWindowController.showSearchWindow()` - Trigger search panel

---

#### 5. EdgeCaseHandler.swift (~280 LOC)
**Role:** App-specific behavior detection & timing adjustments

**Key Classes:**
- `EdgeCaseHandler` (static utility)

**AppCategory Enum:**
- `.standard`, `.browser`, `.terminal`, `.passwordField`, `.virtualMachine`, `.remoteDesktop`, `.electronApp`, `.discord`, `.ide`, `.game`, `.sshSession`, `.unknown`

**Key Static Methods:**
- `detectAppCategory() -> AppCategory` - Identify running app
- `isTerminal(_ bundleID: String) -> Bool` - Terminal detection (must come BEFORE SSH check to avoid `/bin/ps` hangs)
- `isPasswordField() -> Bool` - Check `IsSecureEventInputEnabled()`
- `isIMEComposing() -> Bool` - Detect Vietnamese/Chinese/Japanese IME composition mode

**App-Specific Timing:**
```
Discord:   deletion=4ms, paste=5ms, useSimple=false
Terminal:  deletion=1ms, paste=default, useSimple=true
Browser:   deletion=2ms, paste=2ms, useSimple=false
VM/Remote: deletion=3ms, paste=4ms, useSimple=true
IDE:       deletion=1.5ms, paste=default, useSimple=true
Standard:  deletion=0.5ms, paste=0.8ms, useSimple=false
```

**Integration with TextReplacementService:**
- Extension methods: `shouldPerformExpansion()`, `getTimingForCurrentApp()`
- Disable expansion in password fields & games
- Disable if IME in composition mode

**Known Detection Limitations:**
- SSH check via `/bin/ps aux` spawn (50-300ms block) - only used when terminal detected
- Fullscreen game detection requires window enumeration

---

#### 6. OptimizedSnippetMatcher.swift (~395 LOC)
**Role:** Advanced matching algorithms (currently unused - TextReplacementService handles matching)

**Key Classes:**
- `SuffixTree` - Thread-safe suffix tree structure
  - `insert(_ snippet: Snippet)` - Insert all suffixes
  - `findMatchingSuffixes(in text: String) -> [Snippet]` - Find matching suffixes

- `BloomFilter` - Probabilistic quick-lookup to avoid false positives
  - `add(_ string: String)` - Add string to filter
  - `mightContain(_ string: String) -> Bool` - Test membership (0.01 false positive rate)
  - `clear()` - Reset filter

- `OptimizedSnippetMatcher` - High-level API (DispatchQueue concurrent)
  - `updateSnippets(_ snippets: [Snippet])` - Rebuild tree & filter
  - `findBestMatch(in buffer: String) -> Snippet?` - Find best match
  - `containsPartialMatch(_ buffer: String) -> Bool` - Check partial match

- `IntelligentBufferManager` - Buffer with character frequency tracking
- `EventTapRecoveryManager` - Recovery strategies on failure (reenable → recreate → fallback)
- `PerformanceMonitor` - Callback timing analysis

**Status:** Architecture provided but not actively used (TextReplacementService has its own matching)

---

#### 7. MetafieldService.swift (~80 LOC)
**Role:** Extract & replace interactive placeholder fields (`{{name:default}}`)

**Key Classes:**
- `Metafield` - Single placeholder definition
- `MetafieldService` - Singleton for metafield operations
- `MetafieldInputPanel` - UI dialog for collecting metafield values

**Key Public Methods:**
- `containsMetafields(_ text: String) -> Bool` - Quick check
- `extractMetafields(_ text: String) -> [Metafield]` - Parse all placeholders
- `replaceMetafields(_ text: String, with values: [String: String]) -> String` - Inject values

**Pattern:** `{{keyName:defaultValue}}`

---

#### 8. RichContentService.swift (~100 LOC sampled)
**Role:** File-based image/document storage (refactored from Base64 in v2.8.0)

**Key Methods (partial):**
- `storeImage(_ image: NSImage, for snippetId: String) -> (path: String, mimeType: String)?` - Save PNG
- `storeImageFromPath(_ path: String, for snippetId: String)` - Copy existing file
- `loadImageSmart(from data: String) -> NSImage?` - Try file path, fall back to Base64
- `isFilePath(_ data: String) -> Bool` - Distinguish file vs Base64
- Image/file conversion methods for export/import (Base64 ↔ file path)

**Storage Location:** `~/Library/Application Support/GenSnippets/RichContent/`

---

#### 9. BrowserCompatibleTextInsertion.swift (~175 LOC)
**Role:** Legacy browser timing utilities (mostly superseded by TextReplacementService)

**Note:** Comment indicates functionality merged into TextReplacementService. File contains reference implementation for browser-specific paste delays.

---

#### 10. LocalizationService.swift (~60 LOC sampled)
**Role:** Multi-language support (English, Vietnamese)

**Languages Supported:** English, Vietnamese (auto-detect or user-selected)  
**API:**
- `setLanguage(_ language: Language)` - Change language
- `localizedString(for key: String) -> String` - Get localized text

---

#### 11. ShareService.swift (~80 LOC sampled)
**Role:** Export snippets/categories for sharing

**Key Methods:**
- `exportCategory(_ category: Category) -> ShareExportData` - Export with Base64 images
- `exportSnippets(_ snippetIds: Set<String>) -> ShareExportData` - Selective export
- `writeToFile(_ data: ShareExportData, filename: String) throws -> URL` - Write JSON to temp
- `generateExportFilename(categoryName: String?, snippetCount: Int) -> String` - Timestamp filename

---

#### 12. SandboxMigrationService.swift (~65 LOC)
**Role:** One-time UserDefaults migration (v2.7.0)

**Purpose:** Migrate data from sandboxed container to non-sandboxed location when disabling App Sandbox

**Flow:**
1. Check `SandboxMigrationCompleted_v2.7.0` flag
2. If false: try to read sandboxed plist
3. Copy all non-Apple keys to current UserDefaults
4. Set migration flag

---

#### 13. iCloudSyncService.swift (~30 LOC)
**Role:** iCloud sync stub (disabled)

**Status:** Non-functional stub due to missing iCloud entitlements

---

## MODELS LAYER (7 files)

### Core Data Models

#### 1. Snippet.swift (~135 LOC)
**Purpose:** Core snippet entity with rich content support

**Data Structure:**
```swift
struct Snippet: Identifiable, Codable, Equatable {
    var id: String  // Computed: _id ?? idField ?? ""
    
    // Core fields
    let command: String              // Search command (e.g. ";thanks")
    let content: String              // Replacement text or description
    let description: String?         // UI description
    let categoryId: String?          // Category reference
    
    // Metadata
    let userId: String?              // Cloud user ID
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    // Rich content (legacy single-item)
    let contentType: RichContentType?
    let richContentData: String?     // File path or Base64
    let richContentMimeType: String?
    
    // Rich content (multi-file)
    let richContentItems: [RichContentItem]?
    
    // Computed properties
    var actualContentType: RichContentType  // Default: plainText
    var allRichContentItems: [RichContentItem]
    var hasRichContent: Bool
}
```

**RichContentType Enum:**
- `.plainText`, `.image`, `.url`, `.file`

**RichContentItem Structure:**
- `id`, `type`, `data` (file path or Base64), `mimeType`, `fileName`

**Backward Compatibility:**
- Handles both `_id` (new) and `id` (legacy) fields via `CodingKeys`
- Converts legacy single-item to array via `allRichContentItems`
- Image paths can be file paths (v2.8.0+) or Base64 (legacy, auto-detected)

---

#### 2. Category.swift (~65 LOC)
**Purpose:** Category/folder organization model

**Data Structure:**
```swift
struct Category: Identifiable, Codable, Hashable {
    var id: String  // Computed: _id ?? idField ?? ""
    
    let name: String
    let description: String?
    let userId: String?
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?
}
```

**Special Categories:**
- `id="all-snippets"` - View all snippets across categories
- `id="uncategory"` - Default for uncategorized snippets
- Always sorted alphabetically (except special ones at top)

---

#### 3. SnippetUsage.swift (~285 LOC)
**Purpose:** Track snippet usage statistics & analytics

**Data Structures:**
```swift
struct SnippetUsage: Codable {
    let snippetCommand: String      // Command (not ID)
    var usageCount: Int
    var lastUsedDate: Date?
    var firstUsedDate: Date
    let snippetId: String?          // Legacy field for migration
}
```

**UsageTracker Class (Singleton):**
- In-memory cache + UserDefaults persistence
- Batch save with 0.5s debounce
- Thread-safe: DispatchQueue concurrent reads + barrier writes

**Key Methods:**
- `recordUsage(for snippetCommand: String)` - Increment count & update last used
- `getUsage(for snippetCommand: String) -> SnippetUsage?`
- `getMostUsedSnippets(limit: Int) -> [(String, SnippetUsage)]`
- `getRecentlyUsedSnippets(limit: Int) -> [(String, SnippetUsage)]`
- `getLastUsed(for snippetCommand: String) -> String` - Formatted text ("Today", "3 days ago", etc)

**Migration:** ID-based (v1) → Command-based (v2)
- Checks `didMigrateToCommandBased_v2` flag
- Maps snippet IDs to commands, merges conflicting entries
- Cleans up orphaned data for deleted snippets

---

#### 4. SnippetsViewModel.swift (~80 LOC)
**Purpose:** ObservableObject for SwiftUI snippet management

**Key Properties:**
- `@Published var snippets: [Snippet]`
- `@Published var isLoading`
- `@Published var error`

**Key Methods:**
- `fetchSnippets(isRefresh: Bool)` - Load from local storage
- `loadLocalSnippets()` - Load from UserDefaults + notify TextReplacementService
- `saveLocalSnippets()` - Direct UserDefaults save
- `useFallbackSnippets()` - Provide defaults for first-time users (";thanks", ";hello", ";bye")

**Dependencies:**
- Posts `SnippetsUpdated` notification on load
- Updates `TextReplacementService.shared` with new snippets

---

#### 5. CategoryViewModel.swift (~80 LOC sampled)
**Purpose:** ObservableObject for SwiftUI category management

**Key Properties:**
- `@Published var categories: [Category]`
- `@Published var selectedCategory: Category?`
- `@Published var isLoading`

**Key Methods:**
- `loadCategories()` - Load from LocalStorageService
  1. Load all categories
  2. Add "All" category at index 0
  3. Add "Uncategory" at index 1
  4. Sort remaining alphabetically
  5. Remove duplicates of special categories

**Special Categories:**
- Always "All" first (id: "all-snippets")
- Then "Uncategory" (id: "uncategory")
- Then user categories A-Z

---

#### 6. ShareExportData.swift (~95 LOC)
**Purpose:** Portable sharing format (excludes internal IDs & usage stats)

**Data Structures:**
```swift
struct ShareExportData: Codable {
    let version: String
    let exportDate: Date
    let categoryName: String?  // Hint only (not enforced)
    let snippets: [ShareSnippet]
}

struct ShareSnippet: Codable {
    let command: String
    let content: String
    let description: String?
    let categoryName: String?  // Hint only (not enforced)
    let contentType: RichContentType?
    let richContentItems: [RichContentItem]?
    
    // init(from: Snippet, categoryName: String?)
    // Converts images to Base64 for portable sharing
}
```

**Difference from Full Export (LocalStorageService.ExportData):**
- No user IDs
- No internal snippet IDs
- Images converted to Base64 (portable)
- Designed for sharing, not backup

---

#### 7. LocalSnippetsViewModel.swift
**Not analyzed** (implied to be similar to SnippetsViewModel)

---

## CONTROLLERS LAYER (1 file)

#### SnippetSearchWindowController.swift (~137 LOC)
**Purpose:** Global search panel window controller

**Key Classes:**
- `NSView Extension` - Recursive first responder finder by type
- `SnippetSearchWindowController` - NSWindowController + NSWindowDelegate

**Key Static Methods:**
- `showSearchWindow()` - Show/create snippet search panel
  1. Save current active app
  2. Hide main windows (if running in background mode)
  3. Reuse existing panel or create new
  4. Focus on text field
  
- `returnToPreviousApp()` - Restore focus to previous app

**Panel Configuration:**
- Type: `NSPanel` with `.nonactivatingPanel` style
- Size: 860×580 (min 800×500)
- Level: `.floating` (appears above all apps)
- Behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.transient`
- Hides on app deactivate: false

**Window Lifecycle:**
- `windowWillClose` - Clean up shared reference
- Handles orphaned instances

**Dependencies:**
- `ModernSnippetSearchView` - SwiftUI search UI
- `AppDelegate` - Check `isRunningInBackground` flag

---

## EXTENSIONS LAYER (1 file)

#### String+Localization.swift (~6 LOC)
**Purpose:** Convenient localization syntax

```swift
extension String {
    var localized: String {
        return LocalizationService.shared.localizedString(for: self)
    }
}
```

**Usage:** `"key_name".localized` instead of calling service directly

---

## KEY ARCHITECTURAL PATTERNS

### 1. Thread Safety
- **TextReplacementService:** DispatchQueue (concurrent read + barrier write) + NSLock for buffers
- **LocalStorageService:** DispatchQueue concurrent with barrier writes
- **UsageTracker:** Concurrent DispatchQueue with barrier writes
- **Cache:** Double-check locking pattern on barrier reads

### 2. Batch Operations
- **LocalStorageService:** 0.5s debounce for UserDefaults writes
- **UsageTracker:** 0.5s debounce for usage saves
- Reduces I/O overhead significantly

### 3. Singleton Pattern
- All major services: `static let shared = ServiceName()`
- Private initializers to enforce singleton

### 4. Event Notification
- TextReplacementService: Listen for `SnippetsUpdated`
- GlobalHotkeyManager: Listen for `UpdateSearchShortcut`
- UsageTracker: Post `SnippetUsageUpdated` notification
- AccessibilityPermissionManager: Post `AccessibilityPermissionGranted`

### 5. Backward Compatibility
- **Snippet Model:** Supports both `_id` (new) and `id` (legacy) via CodingKeys
- **Rich Content:** Legacy single-item + new multi-file array
- **Usage Tracking:** ID-based (v1) → Command-based (v2) with migration
- **Image Storage:** File paths (v2.8.0+) + Base64 fallback (legacy)

### 6. Export/Import Design
- **LocalStorageService.exportData()** - Full backup (includes Base64 images)
- **ShareService** - Portable format (Base64 images, no user IDs)
- Bidirectional image conversion (path ↔ Base64)

---

## DEPENDENCIES GRAPH

```
TextReplacementService
  ├── MetafieldService
  ├── RichContentService
  ├── EdgeCaseHandler
  ├── UsageTracker
  └── LocalStorageService (indirect)

LocalStorageService
  └── RichContentService (export/import)

SnippetsViewModel
  └── TextReplacementService

CategoryViewModel
  └── LocalStorageService

UsageTracker
  └── LocalStorageService (migration)

GlobalHotkeyManager
  └── SnippetSearchWindowController

SnippetSearchWindowController
  └── AppDelegate (isRunningInBackground)
```

---

## CRITICAL OBSERVATIONS

### Recent Changes (v2.7-v2.8)
1. **Sandbox Disabled** - App no longer sandboxed (App Sandbox = NO)
2. **Image Storage Refactored** - Base64 → file-based (RichContentService)
3. **Usage Tracking Migration** - ID-based → Command-based (persistent)
4. **Event Tap Resilience** - Exponential backoff for re-enable (handles iTerm2/Ghostty hangs)
5. **Terminal Keystroke Hangs** - Fixed duplicate detection via time+keyCode comparison

### Performance Optimizations
- Cached DateFormatters (8 instances) - avoid creation overhead
- Trie structure in TextReplacementService for O(m) matching
- Bloom filter in OptimizedSnippetMatcher (unused but available)
- 50-item callback execution time buffer
- Reduced event tap check timer: 5s → 10s
- Hotkey re-registration: 30s → 5 minutes

### Known Limitations
- iCloud sync disabled (missing entitlements)
- Fullscreen game detection requires window enumeration (CPU overhead)
- SSH detection via `/bin/ps aux` spawn (50-300ms block, gated by terminal check)
- No test coverage (architecture provided but untested)
- ThreeColumnView.swift still ~845 LOC (could benefit from component extraction)

### Thread Safety Considerations
- **Race Conditions Possible:** Mixed threading in shared state (buffers, event tap state)
- **Timer Cleanup:** Careful management to avoid deadlocks (async invalidate on non-main thread)
- **Retain Cycles:** NotificationCenter observers use `[weak self]` throughout
- **Callback Synchronization:** Event tap callback is synchronous (must be fast <10ms)

---

## RECOMMENDED DOCUMENTATION UPDATES

1. Update `./docs/system-architecture.md` with:
   - Event tap + trie matching algorithm
   - Batch save debounce strategy
   - App-specific timing table (Discord, Terminal, Browser, etc)
   - Image storage refactoring (Base64 → file-based)

2. Update `./docs/code-standards.md` with:
   - Thread safety patterns (DispatchQueue usage)
   - Singleton pattern standards
   - Timer cleanup patterns

3. Create `./docs/performance-guide.md` with:
   - Event tap callback profiling
   - Cache strategies
   - Bloom filter implementation details

---

**Report Generated:** Feb 19, 2026 | **Confidence:** High (all files read & analyzed)
