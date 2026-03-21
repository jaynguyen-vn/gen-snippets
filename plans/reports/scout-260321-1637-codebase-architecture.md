# GenSnippets Codebase Scout Report

**Date:** 2026-03-21  
**Project:** GenSnippets macOS Text Expansion App  
**Total Swift Files:** 48  
**Total LOC:** 16,063

## Executive Summary

GenSnippets is a well-structured macOS text replacement application built with SwiftUI. The codebase follows clean architecture principles with clear separation between UI (Views), business logic (Services), and data models (Models). The app implements sophisticated text monitoring via CGEvent tap, maintains thread-safe operations, and supports rich content (images, files, URLs) alongside basic text replacement.

**Architecture Highlights:**
- Service-oriented design with singleton services for core functionality
- Model-ViewModel pattern for state management (ObservableObject)
- Thread-safe operations using DispatchQueue and NSLock primitives
- Comprehensive dynamic keyword replacement system
- Multi-format rich content support with file-based storage

---

## Root-Level Swift Files

### GenSnippetsApp.swift (684 LOC)
**Purpose:** Main application entry point and AppDelegate  
**Key Classes:**
- `GenSnippetsApp` - @main struct with WindowGroup and command handlers
- `AppDelegate` - NSApplicationDelegate managing menu bar UI, app lifecycle, and window management

**Notable Patterns:**
- Uses NSApplicationDelegateAdaptor for macOS 11 compatibility
- Manages NSStatusItem (menu bar icon) with NSPopover for popover UI
- Handles Sparkle auto-updater integration via UpdaterService
- Custom quit dialog allowing background vs. full quit modes
- Strong reference to mainWindow prevents deallocation during background mode transitions
- Notification-driven command handling (ShowSettings, ShowQuitDialog, HideDockIcon)

**Dependencies:**
- UpdaterService.shared (auto-update manager)
- TextReplacementService.shared (core replacement engine)
- Imports: SwiftUI, ServiceManagement, AppKit, Sparkle

---

### DesignSystem.swift (1,070 LOC)
**Purpose:** Centralized design tokens and UI constants  
**Key Structures:**
- `DSColors` - Color palette (backgrounds, text, accents, status, borders, shadows, gradients)
- `DSTypography` - Font definitions (display, heading, body, label, caption, code sizes)
- `DSSpacing` - Spacing constants (xs, sm, md, lg, xl)
- `DSCornerRadius` - Border radius values
- `DSShadow` - Shadow definitions
- `DSAnimation` - Animation timing and curves
- `DSBorder` - Border styles
- `DSIconSize` - Icon sizing constants

**Notable Pattern:** Token-based design system enabling consistent, maintainable UI across the entire app. No computed properties or dynamic logic—pure constants.

---

### ValidationScript.swift (287 LOC)
**Purpose:** Data validation and integrity checking utility  
**Key Classes/Functions:**
- `ValidationScript` - Main validation engine
- Validates snippet commands, content, categories
- Checks for duplicate commands, empty fields
- Provides detailed error messages for validation failures

**Use Cases:** Used during import/export to catch data inconsistencies before persisting.

---

### StressTest.swift (130 LOC)
**Purpose:** Performance and stress testing utility (DEBUG build only)  
**Key Functions:**
- Bulk snippet creation for load testing
- Memory usage monitoring
- Performance benchmarking helpers

**Use Cases:** Local testing to verify app behavior under high snippet counts (1000+).

---

## Models (6 files, 1,024 LOC)

### Snippet.swift (136 LOC)
**Purpose:** Core data model for text snippets  
**Key Structures:**
- `RichContentType` enum - Defines content types: plainText, image, url, file
- `RichContentItem` - Individual rich content item with type, data (path/base64), mimeType, fileName
- `Snippet` - Main model with command, content, description, categoryId, metadata

**Notable Features:**
- Backward-compatible with legacy single-item rich content format
- Dual ID fields (_id, idField) to support API migration
- Multi-file support via richContentItems array
- Computed properties: `actualContentType`, `allRichContentItems`, `hasRichContent`
- Custom CodingKeys for API serialization

**Dependencies:** Foundation (Codable)

---

### Category.swift (68 LOC)
**Purpose:** Category/folder organization model  
**Key Structures:**
- `Category` - Identifiable, Codable, Hashable model with name, description, metadata
- `CategoriesResponse`, `CategoryRequest`, `CategoryCreateResponse`, `CategoryUpdateResponse` - API DTOs

**Notable Features:**
- Hashable for Set operations (multi-select UI)
- Dual ID field support (_id, idField)
- Custom equality based on _id

---

### LocalSnippetsViewModel.swift (184 LOC)
**Purpose:** Local-first snippet state management  
**Key Class:** `LocalSnippetsViewModel` - ObservableObject with @Published state

**Published Properties:**
- snippets: [Snippet] - All loaded snippets
- isLoading, isRefreshing - Loading state
- error: String? - Error messages
- lastUpdated: Date? - Timestamp of last load

**Key Methods:**
- `loadSnippets()` - Load from LocalStorageService
- `createSnippet()` - Create with rich content support
- `updateSnippet()` - Update with rich content support
- `deleteSnippet()` - Mark as deleted
- `migrateBase64ImagesToFiles()` - One-time migration from Base64 to file-based storage

**Notable Pattern:** Single source of truth via LocalStorageService. Batches operations and posts SnippetsUpdated notifications to TextReplacementService.

---

### SnippetsViewModel.swift (79 LOC)
**Purpose:** Legacy/fallback snippet state (simpler, local-only)  
**Key Class:** `SnippetsViewModel` - ObservableObject

**Use Case:** Fallback for basic CRUD operations without persistence layer abstraction. Creates default snippets for first-time users.

---

### CategoryViewModel.swift (143 LOC)
**Purpose:** Category state management with sorting  
**Key Class:** `CategoryViewModel` - ObservableObject

**Published Properties:**
- categories: [Category] - All categories with special ones ("All", "Uncategory") always present
- selectedCategory: Category? - Currently selected category
- isLoading, errorMessage

**Key Methods:**
- `loadCategories()` - Load with alphabetical sorting of regular categories
- `fetchCategories()` - Async fetch wrapper
- `createCategory()`, `updateCategory()`, `deleteCategory()` - CRUD operations

**Notable Features:**
- Always inserts "All" (all-snippets) and "Uncategory" (uncategory) special categories
- Alphabetical sorting of user-created categories
- Delegates storage to LocalStorageService

---

### SnippetUsage.swift (287 LOC)
**Purpose:** Usage statistics tracking for snippet analytics  
**Key Structures:**
- `SnippetUsage` - Tracks command, usageCount, lastUsedDate, firstUsedDate
- `UsageTracker` - ObservableObject managing usage data

**Notable Features:**
- Command-based tracking (v2 migration from ID-based)
- Computed properties: daysSinceLastUse, formattedLastUsed
- Batch save management via background queue
- Dual storage support (legacy ID-based, new command-based)

---

### ShareExportData.swift (93 LOC)
**Purpose:** Data models for import/export/sharing functionality  
**Key Structures:**
- `ShareExportData` - Minimal export format (excludes internal IDs, usage stats)
- `ShareSnippet` - Shareable snippet with optional categoryName hint
- `ConflictResolution` enum - User actions on import conflicts
- `ShareImportResult` - Tracks import statistics
- `SnippetConflictInfo` - Detailed conflict information

**Notable Feature:** ShareSnippet converts image file paths to Base64 for portable sharing.

---

## Services (14 files, 5,882 LOC)

### TextReplacementService.swift (1,421 LOC)
**Purpose:** Core text monitoring and replacement engine  
**Key Classes:**
- `TextReplacementService` - Main service with singleton pattern
- `TrieNode` - Embedded efficient suffix-based snippet matching

**Architecture:**
- CGEvent tap for system-wide keyboard monitoring
- Rotating buffer tracking last 50 characters with 15-second timeout
- Trie data structure for O(m) suffix matching (m = command length)
- Thread-safe operations: concurrent reads, barrier writes via DispatchQueue
- Snippet snapshot using os_unfair_lock for callback path performance

**Key Features:**
- **Dynamic Keywords:**
  - `{clipboard}` - Current clipboard
  - `{cursor}` - Cursor positioning
  - `{timestamp}` - Unix timestamp
  - `{random-number}` - Random 1-1000
  - `{dd/mm}`, `{dd/mm/yyyy}` - Date formats
  - `{time}`, `{hh:mm}` - Time formats
  - `{uuid}` - UUID generation
  - `{weekday}`, `{month}` - Calendar info

- **Advanced Features:**
  - Cached compiled regex patterns
  - Multiple DateFormatter instances for format caching
  - Dead key state tracking for complex keyboard layouts
  - Browser-specific text insertion via BrowserCompatibleTextInsertion
  - Edge case handling per app type (Discord, browsers, VMs, terminals)

**Threading Model:**
- Main queue for UI updates
- snippetQueue (concurrent) for snippet CRUD
- Background queue for monitoring
- Utility queue for storage
- os_unfair_lock for fast callback performance

**Dependencies:** Foundation, Combine, AppKit, Carbon, CoreGraphics

---

### LocalStorageService.swift (392 LOC)
**Purpose:** Persistent data layer using UserDefaults with caching  
**Key Class:** `LocalStorageService` - Singleton managing all local persistence

**Architecture:**
- Batch-optimized saves with timer-based debouncing
- Concurrent read, barrier write via DispatchQueue
- Cache layer with max 1,000 items per cache
- Double-check locking pattern for cache initialization

**Key Methods:**
- `saveSnippets()`, `loadSnippets()` - Snippet CRUD with caching
- `saveCategories()`, `loadCategories()` - Category CRUD
- `createSnippet()`, `updateSnippet()`, `deleteSnippet()`
- `createCategory()`, `updateCategory()`, `deleteCategory()`
- `generateId()` - Creates unique UUID identifiers
- `performPendingSaves()` - Flushes batched saves on deinit

**Storage:**
- UserDefaults location: ~/Library/Preferences/Jay8448.Gen-Snippets.plist
- Keys: localSnippets, localCategories, categoryOrders, snippetUsageData_v2

**Dependencies:** Foundation, Combine

---

### AccessibilityPermissionManager.swift (198 LOC)
**Purpose:** Handle macOS accessibility permissions (required for CGEvent tap)  
**Key Class:** `AccessibilityPermissionManager` - Singleton

**Key Methods:**
- `requestAccessibilityPermissions()` - Prompt user if needed
- `isAccessibilityEnabled()` - Check current status
- `showAccessibilityPermissionAlert()` - Manual alert display
- `openAccessibilityPreferences()` - Open System Settings

**Features:**
- Automatic permission check on app launch
- Retry timer for monitoring permission changes (up to 30 retries)
- Handles permission granted during session
- Graceful fallback if permissions denied

**Dependencies:** Foundation, AppKit, os.log

---

### GlobalHotkeyManager.swift (158 LOC)
**Purpose:** Register and manage global hotkeys (default: Cmd+Ctrl+S for search)  
**Key Class:** `GlobalHotkeyManager` - Singleton

**Architecture:**
- Event monitors for global and local keyboard events
- Hotkey check timer for periodic re-registration validation
- NotificationCenter observer for shortcut updates

**Key Methods:**
- `setupGlobalHotkey()` - Register hotkey from UserDefaults
- `registerHotkey()` - Internal registration with event listeners
- `updateShortcut()` - Handle custom shortcut changes
- `openSnippetSearch()` - Trigger ModernSnippetSearchView

**Storage:** UserDefaults keys:
- SearchShortcutKeyCode
- SearchShortcutModifiers

**Dependencies:** AppKit, Carbon

---

### BrowserCompatibleTextInsertion.swift (175 LOC)
**Purpose:** Browser-specific text insertion handling  
**Key Class:** `BrowserCompatibleTextInsertion` - Static utility

**Features:**
- Detects web browsers via bundle ID
- Special timing delays for browsers vs. standard apps
- Clipboard-based paste for web apps (more reliable than key events)
- Longer delays for Discord, Firefox compatibility
- Stores/restores original clipboard content

**Supported Browsers:**
- Chrome, Safari, Firefox, Edge, Brave, Opera, Vivaldi

**Key Methods:**
- `insertText(_:previousContent:)` - Smart routing
- `insertTextForBrowser()` - Clipboard paste with timing
- `insertTextStandard()` - Direct text insertion

**Dependencies:** Foundation, AppKit, Carbon

---

### OptimizedSnippetMatcher.swift (395 LOC)
**Purpose:** High-performance snippet matching algorithms  
**Key Classes:**
- `SuffixTree` - O(m) suffix-based matching with thread-safe nodes
- `BloomFilter` - Quick negative lookups (probabilistic)
- `OptimizedSnippetMatcher` - Main matcher coordinating searches

**Architecture:**
- Suffix tree for matching any command suffix in text
- Bloom filter for fast "command doesn't exist" checks
- Thread-safe node locking within suffix tree

**Key Methods:**
- `findMatches(in:)` - Returns all matching snippets
- `findBestMatch(in:)` - Returns longest matching command
- `updateSnippets()` - Rebuild indexes when snippets change

**Performance:** O(m + k) where m = command length, k = matches found.

**Dependencies:** Foundation

---

### RichContentService.swift (494 LOC)
**Purpose:** File-based rich content storage and management  
**Key Class:** `RichContentService` - Singleton

**Storage Structure:**
- Base path: ~/Library/Application Support/GenSnippets/RichContent/
- Files organized by snippet ID and content type

**Key Methods:**
- `storeImage()`, `storeImageFromPath()` - Save images as PNG
- `storeFile()` - Store arbitrary files
- `loadImage()`, `loadImageSmart()` - Load with Base64 fallback
- `migrateSnippetImages()` - One-time Base64→File migration
- `imageItemToBase64()` - Convert file→Base64 for sharing

**Features:**
- PNG format for images
- MIME type detection
- UUID-based file naming (prevents collisions)
- Legacy Base64 support for backward compatibility
- Smart loader tries file path first, falls back to Base64

**Supported MIME Types:**
- image/png, image/jpeg, image/gif, image/webp
- text/plain, text/html
- application/* (generic)

**Dependencies:** Foundation, AppKit, UniformTypeIdentifiers

---

### ShareService.swift (296 LOC)
**Purpose:** Import/export and sharing functionality  
**Key Class:** `ShareService` - Singleton

**Key Methods:**
- `exportCategory()`, `exportSnippets()` - Create ShareExportData
- `writeToFile()` - Serialize to JSON
- `generateExportFilename()` - Create timestamped filenames
- `parseShareFile()` - Deserialize JSON import
- `detectConflicts()` - Find command collisions
- `importSnippets()` - Perform import with conflict resolution
- `resolveConflict()` - Apply user's conflict resolution choice

**Features:**
- Category-aware exports
- Conflict detection by command
- Detailed import statistics (imported, skipped, overwritten, renamed)
- Portable JSON format with pretty printing
- Rich content support in shared snippets

**Dependencies:** Foundation, LocalStorageService

---

### MetafieldService.swift (377 LOC)
**Purpose:** Template variable/placeholder support  
**Key Classes:**
- `MetafieldService` - Regex-based template parsing
- `Metafield` - Individual template variable with key, value, default
- `MetafieldInputPanel` - NSPanel for interactive metafield input

**Features:**
- Regex pattern: `{{key}}` or `{{key:default}}`
- Deduplication of repeated metafield keys
- Real-time preview of replacement
- Interactive input dialog before expansion

**Key Methods:**
- `containsMetafields()` - Quick check
- `extractMetafields()` - Parse all variables
- `replaceMetafields()` - Substitute with values

**Use Case:** Advanced templating for snippets needing user input at expansion time.

**Dependencies:** Foundation, AppKit

---

### EdgeCaseHandler.swift (316 LOC)
**Purpose:** App-specific behavior customization  
**Key Classes:**
- `EdgeCaseHandler` - Static utility for app detection
- `AppCategory` enum - Categories with custom behavior params

**App Categories Detected:**
- standard
- browser (web apps)
- terminal (bash, zsh, etc.)
- passwordField (secure text fields disabled)
- virtualMachine (VirtualBox, Parallels)
- remoteDesktop (Microsoft Remote Desktop)
- electronApp (Slack, Teams, etc.)
- discord (special handling)
- ide (Xcode, VS Code)
- game (disable expansion)
- sshSession (terminal connections)
- unknown

**Customizations Per Category:**
- `shouldDisableExpansion` - Boolean per app type
- `deletionDelay` - Milliseconds to wait before deleting command
- `pasteDelay` - Milliseconds between paste events
- `useSimpleDeletion` - Disable Shift+Arrow (prevents escape sequences)

**Detection Methods:**
- `isPasswordField()` - Check IsSecureEventInputEnabled()
- `isDiscord()`, `isTerminal()`, `isBrowser()` - Bundle ID matching
- `isSSHSession()` - ps aux check (SLOW, deferred until needed)

**Dependencies:** Foundation, AppKit, Carbon

---

### iCloudSyncService.swift (31 LOC)
**Purpose:** Placeholder for future iCloud sync feature  
**Status:** Incomplete/stub implementation
**Note:** Not actively used; included for future expansion.

---

### UpdaterService.swift (32 LOC)
**Purpose:** Sparkle framework integration for auto-updates  
**Key Class:** `UpdaterService` - ObservableObject singleton

**Key Properties:**
- `canCheckForUpdates` - @Published Boolean
- `automaticallyChecksForUpdates` - Get/set property

**Key Methods:**
- `checkForUpdates()` - Manually trigger update check

**Dependencies:** Foundation, Sparkle

---

### SandboxMigrationService.swift (65 LOC)
**Purpose:** One-time migration from sandboxed to non-sandboxed UserDefaults  
**Context:** v2.7.0 transition from ENABLE_APP_SANDBOX=YES to NO  
**Key Class:** `SandboxMigrationService` - Singleton

**Key Methods:**
- `migrateIfNeeded()` - Perform migration if not completed

**Migration Logic:**
1. Check if already migrated (key: SandboxMigrationCompleted_v2.7.0)
2. Skip if non-sandboxed UserDefaults has data
3. Check sandboxed plist at ~/Library/Containers/[bundleID]/...
4. Copy all non-Apple keys to current UserDefaults
5. Mark migration complete

**Dependencies:** Foundation

---

### LocalizationService.swift (59 LOC)
**Purpose:** Multi-language support (English, Vietnamese)  
**Key Classes:**
- `LocalizationService` - Singleton managing language state
- `Language` enum - Supported languages with localization codes

**Features:**
- System language detection on first launch
- Language persistence in UserDefaults
- NotificationCenter-based language change broadcasting

**Key Methods:**
- `setLanguage()` - Switch language and post notification
- `localizedString()` - Retrieve translated string

**Dependencies:** Foundation, Combine

---

## Views (18 files, 7,166 LOC)

### ContentView.swift (62 LOC)
**Purpose:** Root view wrapper for main window  
**Key Structures:**
- `ContentView` - Main container displaying ThreeColumnView
- Quit dialog with background vs. full quit options

**Features:**
- Min window size: 780×550
- Custom quit alert sheet (macOS 11.5 compatible)
- Notification handling for quit and hide operations

---

### ThreeColumnView.swift (1,112 LOC)
**Purpose:** Main three-column layout (categories | snippets | details)  
**Key Structures:**
- `ThreeColumnView` - Master layout with all major interactions
- `DeleteAlertType` - Alert types for delete confirmations
- `ShareExportItem` - Category or snippets for export

**Published State:**
- categoryViewModel, snippetsViewModel - Data sources
- selectedSnippet, searchText, categorySearchText - Filters
- isMultiSelectMode, selectedSnippetIds - Bulk operations
- currentToast - Toast notifications
- Various sheet states (addSnippet, settings, insights, export, share)

**Key Features:**
- Filtered snippet list per selected category
- Search across command and content
- Bulk delete/move/export operations
- Category editing (add, rename, delete)
- Snippet CRUD with toast feedback
- Dark/light mode support
- Keyboard event monitoring for multi-select
- Splitter-based resizable columns (sidebarWidth, snippetListWidth)

**Dependencies:**
- CategoryViewModel, LocalSnippetsViewModel
- ShareService, RichContentService
- All view components

---

### SnippetDetailView.swift (1,245 LOC)
**Purpose:** Detailed view of single snippet (command, content, category, rich content)  
**Key Structures:**
- `SnippetDetailView` - Main detail panel
- `RichContentPreview` - Preview rich content (images, files, URLs)

**Features:**
- Read-only display of snippet command, content, description
- Rich content preview (images with gallery, file list, URLs)
- Category display with change option
- Usage statistics (times used, last used date)
- Copy to clipboard buttons
- Keyboard shortcuts for quick actions
- Responsive layout for different content types

**Dependencies:**
- RichContentService for loading rich content
- UsageTracker for statistics
- Toast for feedback

---

### AddSnippetSheet.swift (732 LOC)
**Purpose:** Modal for creating/editing snippets  
**Key Structures:**
- `AddSnippetSheet` - Main form with all input fields
- `ContentTypePickerSection` - Rich content type selector
- `RichContentInputSection` - File/image/URL input handlers
- `MetafieldPreviewSection` - Template variable preview

**Features:**
- Command/content text editing
- Description optional field
- Category picker dropdown
- Content type selection (plain text, image, URL, file)
- File/image drag-and-drop support
- Image preview with removal
- Rich content item list with reordering
- Metafield detection and preview
- Validation (required fields, no duplicate commands)
- Cancel/Save buttons with loading state

**Notable Pattern:** Supports both create and edit modes with prefilled data.

**Dependencies:**
- LocalSnippetsViewModel for CRUD
- RichContentService for file handling
- MetafieldService for template detection
- Validation logic

---

### ModernSnippetSearchView.swift (611 LOC)
**Purpose:** Global hotkey search interface (Cmd+Ctrl+S)  
**Key Structures:**
- `ModernSnippetSearchView` - Floating search window content
- Search results with live filtering

**Features:**
- Instant search as user types
- Results ranked by relevance
- Quick insert button (expands snippet immediately)
- Copy button for snippet content
- Fuzzy/exact command matching
- Keyboard navigation (arrow keys, Enter)
- Auto-returns focus to previous app after insert
- Minimal UI for distraction-free operation

**Dependencies:**
- LocalSnippetsViewModel for snippet data
- TextReplacementService for expansion
- UsageTracker for statistics

---

### ModernSettingsView.swift (310 LOC)
**Purpose:** Advanced settings panel  
**Features:**
- Accessibility permission status
- Auto-update toggle
- Custom hotkey recording
- Rich content directory management
- Data import/export options
- Usage statistics reset
- Appearance preferences

**Dependencies:**
- AccessibilityPermissionManager
- UpdaterService
- GlobalHotkeyManager
- ShareService

---

### SettingsView.swift (177 LOC)
**Purpose:** Legacy/simplified settings view  
**Features:** Subset of ModernSettingsView for compatibility.

---

### SimpleSettingsView.swift (265 LOC)
**Purpose:** Minimal settings alternative  
**Features:** Core settings without advanced options.

---

### AddSnippetSheet.swift (732 LOC)
**Purpose:** Modal dialog for creating/editing snippets with rich content support  
(Detailed above)

---

### ExportImportView.swift (221 LOC)
**Purpose:** Data backup and restore interface  
**Features:**
- Full data export to JSON
- Import from JSON with conflict detection
- File picker for import selection
- Progress indication
- Error handling with detailed messages

**Dependencies:** ShareService, ValidationScript

---

### ShareExportSheet.swift (396 LOC)
**Purpose:** Share individual snippets or categories  
**Features:**
- Select specific snippets to export
- Generate shareable JSON file
- Open file sharing dialog
- AirDrop/Mail integration

---

### ShareImportSheet.swift (703 LOC)
**Purpose:** Import shared snippets with conflict resolution  
**Features:**
- Drag-and-drop file import
- Conflict preview with action selection
- Bulk conflict resolution
- Import result summary

**Conflict Resolutions:**
- Skip - Ignore conflicting snippet
- Overwrite - Replace existing
- Rename - Create with new command name

---

### CategoryDialogs.swift (263 LOC)
**Purpose:** Category creation, editing, deletion modals  
**Key Components:**
- AddCategorySheet - Create new category
- EditCategorySheet - Rename category
- DeleteCategoryAlert - Confirm deletion

**Features:**
- Name and description inputs
- Validation (no empty names)
- Confirmation dialogs

---

### CategoryPickerSheet.swift (204 LOC)
**Purpose:** Modal for assigning snippet to category  
**Features:**
- List of all categories with "Uncategorized" option
- Selection radio button
- Cancel/Confirm buttons

---

### ConflictResolutionView.swift (296 LOC)
**Purpose:** User interface for resolving import conflicts  
**Features:**
- Side-by-side comparison of snippets
- Action selection (skip, overwrite, rename)
- Suggested rename with editing
- Batch resolution options

---

### InsightsView.swift (391 LOC)
**Purpose:** Usage statistics and analytics dashboard  
**Features:**
- Total snippets count
- Total expansions count
- Most-used snippets ranking
- Recently used snippets
- Category statistics
- Data export as CSV
- Charts/graphs with visual indicators

**Dependencies:** UsageTracker, LocalSnippetsViewModel

---

### MenuBarView.swift (191 LOC)
**Purpose:** Menu bar icon popover content  
**Features:**
- Quick access to main app
- Recent snippets list
- Settings shortcut
- Quit option

---

### SnippetSearchView.swift (336 LOC)
**Purpose:** Legacy search interface (predates ModernSnippetSearchView)  
**Status:** Maintained for compatibility

---

### StatusBarView.swift (100 LOC)
**Purpose:** Status indicator at bottom of main window  
**Features:**
- Snippet count display
- Selection count in multi-select mode
- Search result count
- Loading indicator

---

### ShortcutRecorderView.swift (275 LOC)
**Purpose:** Custom hotkey recorder dialog  
**Features:**
- Key combination capture
- Modifier key display (Cmd, Ctrl, Option, Shift)
- Conflict detection
- Reset to default button

**Dependencies:** GlobalHotkeyManager

---

### ShortcutsGuideView.swift (235 LOC)
**Purpose:** Help modal showing keyboard shortcuts  
**Features:**
- All available shortcuts listed
- macOS-style presentation
- Searchable/filterable list

---

### ButtonStyles.swift (41 LOC)
**Purpose:** Reusable button styling components  
**Key Styles:**
- `ModernButtonStyle` - Primary, secondary, destructive variants
- `PillButtonStyle` - Compact pill-shaped buttons
- `TransparentButtonStyle` - Borderless hover effects

---

## Components (1 file, 185 LOC)

### ToastView.swift (185 LOC)
**Purpose:** Toast notification component  
**Key Structures:**
- `ToastType` enum - success, error, info, warning with colors
- `Toast` struct - Message, duration, type
- `ToastView` - Reusable toast display

**Features:**
- Auto-dismiss after duration
- Icon with background color
- Close button
- Hover state tracking
- DSColors and DSTypography integration

---

## Controllers (1 file, 136 LOC)

### SnippetSearchWindowController.swift (136 LOC)
**Purpose:** Window management for global search (hotkey-triggered)  
**Key Class:** `SnippetSearchWindowController` - NSWindowController

**Features:**
- Floating NSPanel with nonactivatingPanel style
- Automatic focus to previous app after selection
- Window reuse/persistence across hotkey invocations
- Adaptive content (ModernSnippetSearchView on macOS 12+)
- Hides main windows when in background-only mode

**Architecture:**
- Singleton pattern for shared window instance
- Tracks previousApp to restore focus
- Cleanup for orphaned window references

---

## Extensions (1 file, 6 LOC)

### String+Localization.swift (6 LOC)
**Purpose:** Convenience extension for string localization  
**Key Extension:**
- `String.localized` property - Returns NSLocalizedString

**Usage:** Enables `"Key".localized` syntax throughout codebase.

---

## File Statistics

| Directory | Files | LOC | Notes |
|-----------|-------|-----|-------|
| Root | 4 | 2,171 | App entry, design, validation, stress test |
| Models | 6 | 1,024 | Data structures, view models, usage tracking |
| Services | 14 | 5,882 | Business logic, storage, monitoring, sharing |
| Views | 18 | 7,166 | UI components, sheets, dialogs |
| Controllers | 1 | 136 | Window/scene management |
| Components | 1 | 185 | Reusable UI elements |
| Extensions | 1 | 6 | Utility extensions |
| **Total** | **48** | **16,063** | - |

---

## Key Architectural Patterns

### 1. Singleton Services
- TextReplacementService, LocalStorageService, AccessibilityPermissionManager
- Shared instances for app-wide access
- Thread-safe implementations with locks/queues

### 2. ObservableObject + @Published
- LocalSnippetsViewModel, CategoryViewModel, SnippetUsage
- SwiftUI reactive updates via Combine
- State changes trigger UI re-renders

### 3. Thread-Safe Concurrency
- DispatchQueue(concurrent) for reader-writer patterns
- os_unfair_lock for callback fast path
- NSLock within suffix tree nodes

### 4. Data Flow
```
UserDefaults
   ↓
LocalStorageService (cached reads/batched writes)
   ↓
{LocalSnippetsViewModel, CategoryViewModel}
   ↓
Views (ThreeColumnView, ModernSnippetSearchView)
   ↓
TextReplacementService (monitors keyboard, applies replacements)
```

### 5. Rich Content Architecture
- File-based storage in ~/Library/Application Support/GenSnippets/RichContent/
- Base64 fallback for legacy compatibility
- Smart loaders try file first, fall back to Base64

### 6. Error Handling
- Optional returns for failures (file operations, parsing)
- Toast notifications for user feedback
- Detailed error messages in views

---

## Notable Implementation Details

### Dynamic Keywords
- Extensive keyword replacement (clipboard, date, time, UUID, random)
- Cached DateFormatters to avoid expensive allocations
- Regex pattern caching for performance

### App-Specific Customization
- EdgeCaseHandler detects 11 app categories
- Per-app deletion delays, paste delays, simplification flags
- Prevents escape sequences in terminals, handles Discord timing

### Migration Support
- Sandbox data migration (v2.7.0 transition)
- Base64 image → file-based storage migration
- ID-based → command-based usage tracking

### Localization
- English and Vietnamese support
- System language auto-detection
- Persistent user language choice

---

## Files NOT in CLAUDE.md (New/Updated)

1. **MetafieldService.swift** - Template variable support (advanced feature)
2. **EdgeCaseHandler.swift** - App-specific behavior customization (recent refinement)
3. **ShareExportData.swift** - Import/export data models
4. **RichContentService.swift** - File-based content storage (enhanced version)
5. **ShareService.swift** - Export/import orchestration
6. **ShareExportSheet.swift** - UI for category/snippet sharing
7. **ShareImportSheet.swift** - UI for import with conflict resolution
8. **ConflictResolutionView.swift** - Conflict UX component
9. **ValidationScript.swift** - Data validation utility
10. **StressTest.swift** - Performance testing utility
11. **SandboxMigrationService.swift** - Sandbox transition helper (v2.7.0)
12. **UpdaterService.swift** - Sparkle integration wrapper

These represent either recent additions or enhanced versions of existing functionality not documented in the original CLAUDE.md.

---

## Code Quality Observations

**Strengths:**
- Clear separation of concerns (Models, Views, Services)
- Comprehensive threading model with proper synchronization
- Rich error handling with user-facing feedback
- Excellent documentation via CLAUDE.md
- Reusable design system (DSColors, DSTypography, DSSpacing)

**Areas for Improvement:**
- ThreeColumnView (1,112 LOC) and SnippetDetailView (1,245 LOC) could benefit from component extraction
- No automated test coverage (note: complex due to system-level CGEvent tap)
- iCloudSyncService incomplete/unused
- Mixed UI frameworks for compatibility (SwiftUI + legacy NSPanel code)

**Testing Challenges:**
- CGEvent tap integration requires system permissions (hard to mock)
- Global hotkey registration requires event tap permissions
- Keyboard monitoring requires accessibility permissions
- Clipboard operations require integration testing

---

## Unresolved Questions

1. Is iCloudSyncService intended for future use, or should it be removed?
2. What is the test coverage strategy given CGEvent tap integration challenges?
3. Should large views (ThreeColumnView 1,112 LOC, SnippetDetailView 1,245 LOC) be refactored into smaller components?
4. Are there plans to support more languages beyond English and Vietnamese?
5. What is the performance target for snippet matching with 10,000+ snippets?
