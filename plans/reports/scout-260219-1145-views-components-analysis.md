# GenSnippets UI Architecture Scout Report

**Date:** 2026-02-19  
**Scope:** Views (21 files), Components (1 file), Root-level Swift files (4 files)  
**Total LOC:** ~10,375 lines

---

## Executive Summary

GenSnippets UI is built on a three-column hierarchical layout pattern with clear separation of concerns. The design system is comprehensive with centralized design tokens. Navigation flows through modal sheets and notifications, with strong state management via ViewModels. The codebase shows maturity but has opportunities for component extraction and testing.

---

## Root-Level Swift Files (4 files, ~2,057 LOC)

### 1. GenSnippetsApp.swift (~531 lines)
**Role:** Main app entry point and lifecycle management

**Key Structures:**
- `GenSnippetsApp` - @main SwiftUI app entry point
- `AppDelegate` - NSApplicationDelegate managing menu bar, dock, and window lifecycle

**Architecture Patterns:**
- Window management: Captures main window into strong reference to prevent deallocation in background mode
- Menu bar popover integration with NSStatusItem for menu bar icon
- Accessibility permission checking and alerts
- Notification-based communication between UI and app delegate
- Global hotkey setup for snippet search

**Service Integration:**
- TextReplacementService (keyboard monitoring)
- GlobalHotkeyManager (snippet search hotkey)
- LocalStorageService (data persistence)
- AccessibilityPermissionManager (permissions)

**Notable Patterns:**
- Strong reference to mainWindow prevents SwiftUI deallocation in accessory mode
- Window identifier tagging for reliable restoration
- Proper deinit cleanup with NotificationCenter observer removal
- Multiple activation policy toggles (.regular vs .accessory)
- Event monitor lifecycle management

**Recent Changes:**
- Fixed keystroke hangs via keystroke detection mechanism
- Improved window restoration when switching background/foreground modes
- Added debug logging for window management
- Proper cleanup of local event monitor

---

### 2. DesignSystem.swift (~1,071 lines)
**Role:** Centralized design tokens and reusable component styles

**Structure:** 11 token categories organized as static structures

**Categories:**

1. **DSColors** - Color palette
   - Window/control/text backgrounds
   - Text colors (primary, secondary, tertiary, placeholder)
   - Status colors (success, error, warning, info) with backgrounds
   - Border colors (subtle, focused)
   - Shadow colors (light, medium, dark)
   - Gradients

2. **DSTypography** - Font hierarchy
   - Display sizes (large, medium, small)
   - Headings (H1-H3)
   - Body (large, regular, small)
   - Labels (regular, small, tiny)
   - Captions
   - Code (large, regular, small)
   - Section headers

3. **DSSpacing** - Spacing scale
   - 8 levels: xxxs (2pt) to massive (48pt)
   - Consistent 2pt increments for visual rhythm

4. **DSRadius** - Corner radius tokens
   - xxs (2pt) to full (9999pt)
   - Named for purpose: xxs for badges, sm for buttons, md for cards, xl for dialogs

5. **DSShadow** - Elevation levels
   - 5 levels: none to xl
   - Each with color, radius, x/y offset
   - Purpose-named (light for hover, medium for floating, dark for modals)

6. **DSAnimation** - Animation timings and springs
   - Duration constants: instant (0.1s) to slower (0.4s)
   - Spring animations (quick, normal, bouncy, smooth)
   - Easing functions (easeOut, easeInOut)

7. **DSIconSize** - Icon sizing scale
   - 8 levels: xxs (10pt) to huge (32pt)

8. **DSLayout** - Layout constants
   - Sidebar: 160-280pt width
   - Snippet list: 220-380pt width
   - Detail view: 350pt minimum
   - Modal sizes: small (300pt), medium (400pt), large (500pt)
   - Row heights: category (36pt), snippet (72pt), settings (48pt)

**Reusable Components:**

1. **Style Structs (ButtonStyle, ToggleStyle, etc.)**
   - DSButtonStyle: 4 variants (primary, secondary, tertiary, destructive, ghost) × 3 sizes
   - DSToggleStyle: Custom capsule toggle with animation
   - DSCardStyle: 3 elevation levels
   - DSInputStyle: Focused/unfocused states
   - DSListRowStyle: Selection and hover states
   - DSBadgeStyle: 5 variants

2. **Glassmorphism Effects**
   - DSVisualEffectBlur: NSViewRepresentable wrapping NSVisualEffectView
   - DSGlassmorphism: Overlay + border + shadow for modals/floating panels
   - DSModalBackground: Light blur background for dialogs
   - DSFrostedCard: Subtle blur for cards

3. **Utility Components**
   - DSSectionHeader: Uppercase section labels
   - DSEmptyState: Icon + title + description + action CTA
   - DSCloseButton: Circular button with hover state
   - DSIconButton: Small icon-only button with hover
   - DSShortcutBadge: Keyboard shortcut display (Cmd+S format)
   - DSDivider: Divider with optional label
   - ResizableTextEditor: Drag-to-resize text editor with handle

**Extension Helpers:**
- View extensions for applying styles: `.dsCard()`, `.dsInput()`, `.dsListRow()`, `.dsBadge()`, `.dsShadow()`, `.dsGlass()`, `.dsModalBackground()`, `.dsFrostedCard()`

**Notable Patterns:**
- Comprehensive design token system enables consistency across app
- Type-safe style variants prevent invalid combinations
- Animation definitions ensure consistent motion across UI
- Color palette supports both light and dark modes via Color(NSColor) usage
- Shadow levels mapped to elevation purposes

---

### 3. ValidationScript.swift (~50+ lines)
**Role:** Non-XCTest validation for TextReplacementService

**Key Classes:**
- TextReplacementValidator: Test runner with assertEqual/assertTrue helpers

**Purpose:**
- Unit-testing TextReplacementService without XCTest framework
- Trie data structure validation
- Keyword replacement logic testing
- Suffix matching verification

---

### 4. StressTest.swift (~50+ lines)
**Role:** Event tap stress testing under load

**Key Methods:**
- Rapid typing simulation (300 iterations over 30s)
- CPU load generation during typing
- Event tap failure monitoring

**Purpose:**
- Validate keyboard monitoring under high load
- Test system under CPU stress
- Detect keystroke hang scenarios

---

## Views Layer (21 files, ~8,133 LOC)

### Primary Navigation Views

**1. ContentView.swift (~62 lines)**
- Minimal container wrapping ThreeColumnView
- Handles quit confirmation dialog via sheet
- Posts notifications for app lifecycle events
- Navigation integration point

**2. ThreeColumnView.swift (~1,112 lines)**
- **Purpose:** Main UI layout organizing snippets and categories
- **Layout:** HSplitView with three resizable columns
  - Sidebar (160-280pt): Category list with search
  - Center (220-380pt): Snippet list with search
  - Right (350pt+): Snippet detail view
- **Features:** Bulk operations, multi-select, import/export, sharing, insights
- **Key StateObjects:** CategoryViewModel, LocalSnippetsViewModel
- **State Management:**
  - selectedSnippet, selectedSnippetIds, searchText, categorySearchText
  - showAddCategorySheet, showAddSnippetSheet, showExportImportSheet
  - showSettingsSheet, showInsightsSheet, showShortcutsGuide
  - showMoveSheet (move snippet to category), shareExportItem
  - isMultiSelectMode, currentToast
  - Keyboard event monitor for shortcuts (Cmd+N, Cmd+Shift+N, etc.)
- **Pre-computed Properties:** snippetCountByCategory, categoryNameById for scroll performance
- **Sheet Integrations:** 8 modal sheets (add category, edit category, add snippet, export/import, settings, insights, shortcuts, move, share)
- **Key Notifications:** RefreshData, RefreshAllData, ShowSettings, SnippetUsageUpdated

---

### Detail & Edit Views

**3. SnippetDetailView.swift (~1,245 lines)** - Largest view
- **Purpose:** Display and edit individual snippet
- **Features:**
  - Command field with validation
  - Content editor with resizable drag handle
  - Description field
  - Rich content support (plain text, URL, file-based multi-file)
  - Placeholder menu (cursor, time, date, utility, clipboard)
  - Category selector
  - Delete confirmation
  - Usage statistics display
  - Copy/paste tracking
- **Key States:** command, content, description, hasChanges, isSaving, focusedField
- **Rich Content States:** selectedContentType, richContentItems, urlString
- **Keyboard Support:** Cmd+Delete to cut, Cmd+A to select all
- **Notable Pattern:** Resizable editor with drag handle for content field

**4. AddSnippetSheet.swift (~732 lines)**
- **Purpose:** Create new snippet modal
- **Features:** Same as SnippetDetailView but for creation
- **States:** command, content, description, isCreating, errorMessage, showPlaceholderMenu
- **Rich Content States:** selectedContentType, richContentItems, urlString, hasImageInClipboard
- **Key Feature:** Categorization during creation, pending snippet ID tracking
- **Async Handling:** Focus management, error messages, image clipboard detection

---

### Search Views

**5. ModernSnippetSearchView.swift (~611 lines)**
- **Purpose:** Global snippet search via hotkey (Cmd+Ctrl+S)
- **Target:** macOS 12.0+ with modern OS features
- **Features:**
  - Full-text search (command, description, content)
  - Cached filtering for performance
  - Keyboard navigation (arrow keys, Enter)
  - Copy to clipboard action
  - Return to previous app functionality
  - Snippet selection with visual feedback
- **States:** searchText, selectedSnippetId, hoveredSnippetId, copiedSnippetId, isSearchFocused
- **Performance:** Cached filtered snippets, invalidation checks before recompute
- **Size:** 880×600pt frame
- **Integration:** SnippetSearchWindowController for window management

**6. SnippetSearchView.swift (~336 lines)**
- **Purpose:** Fallback search for older macOS versions (<12.0)
- **Features:** Basic search, snippet selection, insertion
- **Simpler Than:** ModernSnippetSearchView

---

### Settings & Configuration Views

**7. SimpleSettingsView.swift (~265 lines)**
- **Purpose:** Settings UI for macOS 12.0+
- **Features:**
  - Start at login toggle
  - Status bar icon visibility
  - Global hotkey customization (ShortcutRecorderView)
  - App information section
  - Theme selection (if applicable)
- **Integration:** SMAppService for launch agent management

**8. ModernSettingsView.swift (~277 lines)**
- **Purpose:** Enhanced settings for modern macOS
- **Features:** Extended configuration options over SimpleSettingsView

**9. SettingsView.swift (~177 lines)**
- **Purpose:** Legacy settings for macOS <12.0
- **Fallback:** When SimpleSettingsView unavailable

---

### Export/Import & Sharing Views

**10. ExportImportView.swift (~221 lines)**
- **Purpose:** Bulk data import/export
- **Features:**
  - JSON file picker for import
  - Generate shareable export file
  - Conflict resolution for imports (ShareImportSheet)
  - Post-import refresh notification

**11. ShareExportSheet.swift (~396 lines)**
- **Purpose:** Share snippet data (category or selected snippets)
- **Features:**
  - Multiple export format options
  - QR code generation
  - Share sheet integration
  - Format conversion utilities

**12. ShareImportSheet.swift (~703 lines)**
- **Purpose:** Import shared snippet data
- **Features:**
  - Conflict detection when importing
  - Category merging
  - Duplicate snippet handling
  - Preview before confirming import

**13. ConflictResolutionView.swift (~296 lines)**
- **Purpose:** Resolve conflicts during import
- **Features:**
  - Show conflicting snippets side-by-side
  - User choice: keep existing, replace, or skip
  - Batch conflict resolution

---

### Category Management Views

**14. CategoryDialogs.swift (~263 lines)**
- **Purpose:** Add/edit category modals
- **Views:**
  - AddCategorySheet: Create new category
  - EditCategorySheet: Edit existing category
- **Features:** Name validation, color selection, emoji support
- **Integrated With:** CategoryViewModel for CRUD

**15. CategoryPickerSheet.swift (~204 lines)**
- **Purpose:** Select target category for moving snippets
- **Features:**
  - List of categories with icons/colors
  - Show snippet count being moved
  - Nested category support (if hierarchical)
  - onSelect callback pattern

---

### Insights & Guide Views

**16. InsightsView.swift (~391 lines)**
- **Purpose:** Usage statistics and analytics
- **Features:**
  - Most used snippets ranking
  - Category usage breakdown
  - Time-based analytics
  - Usage trends visualization
- **Integration:** UsageTracker.shared for statistics

**17. ShortcutsGuideView.swift (~235 lines)**
- **Purpose:** Help view showing all keyboard shortcuts
- **Content:**
  - Search: Option+Cmd+E
  - New snippet: Cmd+N
  - New category: Cmd+Shift+N
  - Settings: Cmd+,
  - Save: Cmd+S
- **Format:** Organized sections with visual shortcuts display

---

### Menu Bar & Status

**18. MenuBarView.swift (~191 lines)**
- **Purpose:** Popover menu when clicking menu bar icon
- **Features:**
  - Quick statistics (total snippets, categories, version)
  - Open app button
  - Clear all data option
  - Version display
- **Integration:** CategoryViewModel, LocalSnippetsViewModel
- **Visual:** VisualEffectBackground blur effect

**19. StatusBarView.swift (~100 lines)**
- **Purpose:** Bottom status bar in main window
- **Features:**
  - Keyboard shortcuts display (6 shortcuts)
  - Credits link to developer
  - Visual shortcut badges
- **Component:** StatusBarShortcut with symbol mapping (Cmd→⌘, Shift→⇧, etc.)
- **Layout:** Horizontal scrollable shortcuts + right-aligned credit

---

### Specialized Input Views

**20. ShortcutRecorderView.swift (~275 lines)**
- **Purpose:** Record global hotkey combinations
- **Features:**
  - Key code + modifier flags capture
  - Visual feedback during recording
  - Validation of shortcuts
  - Carbon-based hotkey registration support
- **Integration:** GlobalHotkeyManager for activation

---

### Utility Views

**21. ButtonStyles.swift (~41 lines)**
- **Purpose:** Custom button style implementations
- **Styles:**
  - ModernButtonStyle: Primary/secondary/destructive variants
  - Custom state handling (pressed, hovered)
  - Accessibility support

---

## Components Layer (1 file, 185 LOC)

### ToastView.swift (~185 lines)
- **Purpose:** Toast/banner notification component
- **Types:** Success, error, info, warning with color/icon mapping
- **Structure:**
  - Toast: Identifiable struct with type, message, duration
  - ToastView: Display component with auto-dismiss
  - ToastModifier: ZStack wrapper for positioning
  - ToastManager: Singleton for easy access
  - View extension: `.toast()` modifier for easy application
- **Features:**
  - Auto-dismiss after duration
  - Dismiss button
  - Hover feedback
  - Smooth transitions with spring animation
  - Left accent line matching type color
  - Max width 420pt for readability

---

## Data Flow & State Management

### ViewModel Integration

**CategoryViewModel**
- Load/save categories
- Alphabetical sorting
- Create/edit/delete category operations
- Selection state (selectedCategory)

**LocalSnippetsViewModel** (extends SnippetsViewModel)
- Load/save snippets
- CRUD operations
- Batch operations (multi-select delete/move)
- Search/filter
- Usage tracking updates

### Notification-Based Communication
- **RefreshData**: Post-import refresh
- **RefreshAllData**: Post-clear-all refresh
- **ShowSettings**: Open settings sheet
- **SnippetUsageUpdated**: Usage stats changed
- **ShowQuitDialog**: Quit confirmation
- **HideDockIcon/ShowDockIcon**: Visibility toggle
- **HideMenuBarIcon/ShowMenuBarIcon**: Status bar icon toggle
- **StatusBarIconVisibilityChanged**: Preference change

---

## Navigation Patterns

### Modal Sheet Flow
```
ContentView (ThreeColumnView)
├── Add Category Sheet
├── Edit Category Sheet  
├── Add Snippet Sheet
├── Export/Import Sheet
├── Settings Sheet (Simple/Modern/Legacy)
├── Insights Sheet
├── Shortcuts Guide Sheet
├── Move Snippet Sheet
└── Share Export Sheet
    └── Share Import Sheet (on conflict)
        └── Conflict Resolution Sheet (if needed)
```

### Menu Bar Flow
```
Menu Bar Icon (NSStatusItem)
└── Popover (MenuBarView)
    └── Open App → Shows/restores main window
```

### Global Search Flow
```
Global Hotkey (Cmd+Ctrl+S)
└── SnippetSearchWindowController
    └── ModernSnippetSearchView (macOS 12+)
        └── Insert snippet & return to previous app
```

---

## Layout Architecture

### Three-Column System (ThreeColumnView)

```
┌─────────────────────────────────────────┐
│                                         │
│  Categories  │  Snippets  │  Details   │
│  160-280pt   │ 220-380pt  │  350pt+    │
│              │            │            │
│ - All        │ Filtered   │ Command    │
│ - Uncategory │ list by    │ Content    │
│ - Custom     │ category   │ Description│
│   (sorted)   │ - Search   │ Category   │
│   - Search   │ - Click    │ Delete btn │
│   - Add new  │   to select│ Usage info │
│              │ - Rename   │            │
│              │ - Delete   │            │
│              │ - Bulk ops │            │
│              │            │            │
└──────────────────────────────────────────┘
├─ StatusBarView (28pt height) ──────────┤
```

---

## Design System Application

### Color Usage
- **Primary text:** DSColors.textPrimary (headings, content)
- **Secondary text:** DSColors.textSecondary (labels, hints)
- **Accent:** DSColors.accent (active states, CTAs)
- **Status:** DSColors.success/error/warning/info (toast, validation)

### Spacing Usage
- **Padding:** DSSpacing.xl (20pt) - view margins
- **Gap:** DSSpacing.md (12pt) - between sections
- **Divider:** DSSpacing.sm (8pt) - small gaps
- **Compact:** DSSpacing.xs/xxs (6pt/4pt) - dense lists

### Typography Usage
- **Page Title:** DSTypography.displaySmall (20pt, semibold)
- **Headings:** DSTypography.heading2 (16pt, semibold)
- **Body:** DSTypography.body (13pt, regular)
- **Code:** DSTypography.code (13pt, monospaced)
- **Labels:** DSTypography.label (13pt, medium)
- **Captions:** DSTypography.caption (11pt, regular)

### Shadow Usage
- **Cards:** DSShadow.sm (subtle elevation)
- **Popovers:** DSShadow.lg (strong shadow)
- **Modals:** DSShadow.xl (maximum shadow)

---

## Notable Patterns & Practices

### Performance Optimizations
1. **Cached filtered snippets** in ModernSnippetSearchView
2. **Pre-computed lookup tables** in ThreeColumnView (snippetCountByCategory)
3. **Lazy loading** of detail view only when selected
4. **Resizable editor** with manual height tracking to avoid constant recomputation

### Accessibility
1. **Keyboard shortcuts** for all main actions
2. **Accessibility descriptions** on images
3. **Focus management** with @FocusState
4. **NSCursor management** on hover states
5. **Screen reader hints** in tooltip-style content

### Memory Management
1. **Weak self** in notification handlers
2. **Deinit cleanup** of observers
3. **Strong reference** to mainWindow to prevent GC during accessory mode
4. **Event monitor lifecycle** management in AppDelegate
5. **@State variables** scoped to views, not leaking to services

### State Management Patterns
1. **Single source of truth** via ViewModels
2. **@StateObject** for long-lived view models
3. **@ObservedObject** for injected view models
4. **@Published** properties in ViewModels
5. **Notification-based** for cross-view communication
6. **Callbacks** (onSelect, onDelete) for sheet callbacks

---

## Areas for Improvement

### Code Organization
1. **ThreeColumnView.swift (1,112 LOC)** - Consider extracting:
   - Category sidebar into CategorySidebarView
   - Snippet list into SnippetListView
   - Each sheet into separate files

2. **SnippetDetailView.swift (1,245 LOC)** - Largest file, extract:
   - PlaceholderMenuView for rich content UI
   - KeywordReplacementHelper
   - RichContentEditor components

3. **ButtonStyles.swift (41 LOC)** - Sufficient but could benefit from:
   - Hover state animations
   - Accessibility label support

### Testing Gaps
1. No XCTest unit tests (only ValidationScript.swift)
2. No view model tests
3. No integration tests
4. Stress test available but not integrated into CI/CD

### Documentation Gaps
1. No SwiftUI Preview providers for all views
2. Limited inline documentation in large views
3. No architecture documentation (present in CLAUDE.md, not in code)

### Design System Gaps
1. Animation definitions could be more comprehensive
2. Component composition examples missing
3. Spacing scale could benefit from relative/contextual values

---

## File Size Distribution

| File | LOC | Category | Notes |
|------|-----|----------|-------|
| SnippetDetailView.swift | 1,245 | Detail/Edit | **Large - candidate for extraction** |
| ThreeColumnView.swift | 1,112 | Navigation | **Large - candidate for extraction** |
| AddSnippetSheet.swift | 732 | Modal | Well-scoped |
| ShareImportSheet.swift | 703 | Modal | Complex conflict logic |
| ModernSnippetSearchView.swift | 611 | Search | Good focus |
| ShareExportSheet.swift | 396 | Modal | Moderate complexity |
| InsightsView.swift | 391 | Analytics | Well-scoped |
| SnippetSearchView.swift | 336 | Search | Fallback, simpler |
| ConflictResolutionView.swift | 296 | Modal | Specialized |
| ModernSettingsView.swift | 277 | Settings | Well-scoped |
| ShortcutRecorderView.swift | 275 | Input | Well-scoped |
| SimpleSettingsView.swift | 265 | Settings | Well-scoped |
| CategoryDialogs.swift | 263 | Modal | Dual-purpose |
| ShortcutsGuideView.swift | 235 | Help | Well-scoped |
| ExportImportView.swift | 221 | Modal | Moderate complexity |
| CategoryPickerSheet.swift | 204 | Modal | Well-scoped |
| MenuBarView.swift | 191 | Status | Well-scoped |
| ToastView.swift | 185 | Component | Well-scoped |
| SettingsView.swift | 177 | Settings | Legacy, simpler |
| StatusBarView.swift | 100 | Status | Well-scoped |
| ContentView.swift | 62 | Container | Minimal, focused |
| ButtonStyles.swift | 41 | Utility | Minimal, focused |
| **Total Views + Components** | **8,318** | | 21 files |
| GenSnippetsApp.swift | 531 | App | Well-scoped |
| DesignSystem.swift | 1,071 | Tokens | Comprehensive |
| ValidationScript.swift | 50+ | Testing | Non-XCTest |
| StressTest.swift | 50+ | Testing | Load testing |
| **Total Root-Level** | **~1,700** | | 4 files |

---

## Key Dependencies Summary

### Core Services Used by Views
- **TextReplacementService.shared** - Text expansion engine
- **LocalStorageService.shared** - Data persistence
- **GlobalHotkeyManager.shared** - Hotkey setup
- **AccessibilityPermissionManager.shared** - Permission checks
- **UsageTracker.shared** - Analytics
- **ToastManager.shared** - Notifications

### ViewModels
- **CategoryViewModel** - Category state/CRUD
- **LocalSnippetsViewModel** - Snippet state/CRUD
- **Inherits from SnippetsViewModel**

### Models
- **Snippet** - Data model for snippet
- **Category** - Data model for category
- **Toast/ToastType** - Notification UI model
- **RichContentItem/RichContentType** - Multi-file content support

### macOS Frameworks
- **SwiftUI** - UI framework
- **AppKit** - NSWindow, NSStatusBar, NSMenu, NSPasteboard, etc.
- **Combine** - @Published, ObservableObject
- **ServiceManagement** - Launch agent management
- **UniformTypeIdentifiers** - File type support (UTType)
- **Carbon** (implicit via GlobalHotkeyManager) - Global hotkeys

---

## Recent Changes Observed

### Latest Commits Impact
1. **v2.8.1** - Debugger report added
2. **v2.8.0** - Image storage refactored from Base64 to file-based
3. **v2.7.1** - App Sandbox disabled, UX improved
4. **KeyStroke Hang Fix** - Terminal app stability (iTerm2, Ghostty)
5. **Usage Tracking Migration** - ID-based → command-based tracking

### UI-Related Changes
- MenuBarView improvements for background mode
- Window restoration reliability enhanced
- New conflict resolution UI during import
- Enhanced settings with hotkey customization
- Toast notifications for user feedback

---

## Unresolved Questions

1. **Component Extraction Strategy** - Should SnippetDetailView and ThreeColumnView be split into smaller composable views? What extraction pattern preferred?

2. **Testing Infrastructure** - Should ValidationScript and StressTest be moved to XCTest framework for CI/CD integration?

3. **Preview Providers** - Should all Views have SwiftUI Preview providers for live preview development?

4. **Accessibility Compliance** - Have these views been tested against WCAG 2.1 or Apple's accessibility guidelines?

5. **Localization** - I see `.localized` usage but unclear if full i18n infrastructure is complete. Status?

6. **Dark Mode** - All design tokens use NSColor which respects system appearance. Have all views been tested in dark mode?

7. **Performance Baselines** - Are there performance targets for scrolling snippet lists, search filtering, etc.?

8. **iCloudSync Integration** - I see iCloudSyncService exists but documentation mentions "incomplete". Should UI prepare for sync status indicators?

