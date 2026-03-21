# GenSnippets: System Architecture

**Architecture Pattern:** MVVM + Service Layer with Event-Driven Communication
**Concurrency Model:** Mixed DispatchQueue + NSLock + CGEvent system thread
**Storage:** UserDefaults (JSON) with batch coalescing
**Current Version:** 2.9.8
**Last Updated:** March 21, 2026

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   User Interface Layer (SwiftUI)            │
│  ContentView → ThreeColumnView → Detail/Search/Settings      │
└────────────────────┬────────────────────────────────────────┘
                     │ @Published / @Binding
                     ↓
┌─────────────────────────────────────────────────────────────┐
│             View Model Layer (Observable)                    │
│  LocalSnippetsViewModel ← CategoryViewModel                  │
│  (Manages UI state, snippet CRUD)                           │
└────────────────────┬────────────────────────────────────────┘
                     │ NotificationCenter Events
                     ↓
┌─────────────────────────────────────────────────────────────┐
│           Service Layer (Singletons, Thread-Safe)            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Text Replacement Core                              │  │
│  │  ├─ TextReplacementService (CGEvent tap)            │  │
│  │  ├─ OptimizedSnippetMatcher (Trie + Bloom Filter)   │  │
│  │  ├─ MetafieldService ({{key:default}})             │  │
│  │  └─ RichContentService (images, files, URLs)        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Data & Integration Services                         │  │
│  │  ├─ LocalStorageService (UserDefaults + caching)     │  │
│  │  ├─ ShareService (import/export)                     │  │
│  │  └─ iCloudSyncService (disabled stub)                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  System Integration Services                         │  │
│  │  ├─ AccessibilityPermissionManager                   │  │
│  │  ├─ GlobalHotkeyManager (Carbon keyboard)            │  │
│  │  ├─ EdgeCaseHandler (app-specific timing)            │  │
│  │  ├─ BrowserCompatibleTextInsertion                   │  │
│  │  ├─ LocalizationService (en/vi)                      │  │
│  │  └─ UpdaterService (Sparkle auto-update)             │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│         Data Persistence Layer (UserDefaults)               │
│  ~/Library/Preferences/Jay8448.Gen-Snippets.plist           │
│  Keys: localSnippets, categories, snippetUsages             │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Interactions

### Text Replacement Pipeline

```
┌─────────────┐
│ System      │ CGEvent keyboard event (character typed)
│ Keyboard    │
└──────┬──────┘
       │
       ↓
┌─────────────────────────────────────────────────────────┐
│ TextReplacementService.eventTap                          │
│ (CGMachPort running on system event tap thread)          │
│                                                          │
│ 1. Capture keystroke (key code → character)              │
│ 2. Add to rolling buffer (max 50 chars)                  │
│ 3. Search Trie for suffix match (longest first)          │
└──────┬──────────────────────────────────────────────────┘
       │
       ├─ NO MATCH
       │  └─→ Event passes through, user sees typed char
       │
       └─ MATCH FOUND
          │
          ↓
          ┌─────────────────────────────────────┐
          │ 1. Delete command via backspace      │
          │    (N CGEvent for each character)    │
          └──────┬──────────────────────────────┘
                 │
                 ↓
          ┌─────────────────────────────────────┐
          │ 2. Handle metafields                │
          │    (if {{...}} present)             │
          │ MetafieldService.promptForValues()  │
          │ User enters values in dialog        │
          │ Substitute into replacement text    │
          └──────┬──────────────────────────────┘
                 │
                 ↓
          ┌─────────────────────────────────────┐
          │ 3. RichContentService               │
          │    (if image/file/URL)              │
          │    Sequential paste events          │
          └──────┬──────────────────────────────┘
                 │
                 ↓
          ┌─────────────────────────────────────┐
          │ 4. EdgeCaseHandler                  │
          │    (app-specific timing)            │
          │    - Discord: 5ms paste delay       │
          │    - Terminal: simple mode          │
          │    - Browser: 2ms paste delay       │
          └──────┬──────────────────────────────┘
                 │
                 ↓
          ┌─────────────────────────────────────┐
          │ 5. Send replacement via CGEvent     │
          │    (paste with proper delays)       │
          │ User sees replacement text          │
          └──────┬──────────────────────────────┘
                 │
                 ↓
          ┌─────────────────────────────────────┐
          │ 6. Update usage tracking            │
          │    LocalSnippetsViewModel           │
          │    (command → increment counter)    │
          │                                     │
          │ 7. Trigger batch save               │
          │    LocalStorageService              │
          │    (0.5s coalescing)                │
          └─────────────────────────────────────┘
```

### Data Flow (UI ↔ Services)

```
User Action (Add/Edit/Delete Snippet)
        │
        ↓
ThreeColumnView / AddSnippetSheet
(User enters data, clicks Save)
        │
        ↓
LocalSnippetsViewModel
(@Published var snippets: [Snippet])
        │
        ├─ Update @Published property
        │ (triggers SwiftUI re-render)
        │
        └─ Call NotificationCenter.post("snippetsDidChange")
        │
        ↓
TextReplacementService
(listener via NotificationCenter)
        │
        ├─ Reload snippets from ViewModel
        ├─ Rebuild Trie data structure
        └─ Update cached snippet index
        │
        ↓
LocalStorageService
(listener via NotificationCenter)
        │
        ├─ Schedule batch save
        │  (0.5s coalescing timer)
        │
        ↓ [0.5s delay]
        │
        └─→ UserDefaults.set()
            ~/Library/Preferences/Jay8448.Gen-Snippets.plist
```

### Metafield (Custom Placeholder) Flow

```
User types trigger: "!hello"
Snippet: "Hello {{name:John}}, welcome to {{company}}!"
        │
        ↓
MetafieldService.extractMetafields()
        │
        ├─ Parse: {{name:John}} → field="name", default="John"
        ├─ Parse: {{company}} → field="company", default=nil
        │
        ↓
MetafieldService.promptForValues()
        │
        └─→ SwiftUI Dialog appears:
            ┌─────────────────────────────┐
            │ Enter value for 'name'      │
            │ [John...................]    │ ← Prefilled default
            └─────────────────────────────┘
            ┌─────────────────────────────┐
            │ Enter value for 'company'   │
            │ [.........................]  │ ← Empty
            └─────────────────────────────┘
            [Cancel] [OK]
        │
        ↓ (User clicks OK)
        │
MetafieldService.substitute()
        │
        └─ Replace {{name:John}} with "Jane"
           Replace {{company}} with "Acme Corp"
           Result: "Hello Jane, welcome to Acme Corp!"
        │
        ↓
Insert into active application
(CGEvent paste)
```

---

## Threading Model

### Queue Assignments

| Component | Queue | Type | Purpose |
|---|---|---|---|
| **TextReplacementService** | `snippetQueue` | Concurrent | Trie matching, keyword replacement |
| **TextReplacementService** | `bufferLock` (NSLock) | Synchronous | Rolling buffer thread safety |
| **CGEvent Tap** | System event tap thread | External | Receives raw keyboard events |
| **LocalStorageService** | `storageQueue` | Concurrent | UserDefaults read/write |
| **OptimizedSnippetMatcher** | `matcherQueue` | Concurrent | Parallel suffix tree queries |
| **Main Thread** | Main (NSOperationQueue) | Sequential | All UI updates, NotificationCenter posts |

### Thread Safety Mechanisms

```swift
// 1. NSLock for simple critical sections
class TextReplacementService {
  private let bufferLock = NSLock()

  func addToBuffer(_ char: Character) {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    // Modify buffer
  }
}

// 2. DispatchQueue for complex read/write patterns
class LocalStorageService {
  private let storageQueue = DispatchQueue(
    label: "com.gesnippets.storage",
    attributes: .concurrent
  )

  // Concurrent reads
  func loadSnippets() -> [Snippet] {
    storageQueue.sync {
      // Read from UserDefaults
    }
  }

  // Exclusive writes (barrier)
  func saveSnippets(_ snippets: [Snippet]) {
    storageQueue.async(flags: .barrier) {
      // Write to UserDefaults
    }
  }
}

// 3. @Published + DispatchQueue.main for UI
class LocalSnippetsViewModel: ObservableObject {
  @Published var snippets: [Snippet] = []

  func updateSnippet(_ id: UUID, command: String) {
    DispatchQueue.main.async {
      if let index = self.snippets.firstIndex(where: { $0.id == id }) {
        self.snippets[index].command = command
      }
    }
  }
}
```

### Potential Race Conditions (Known Issues)

| Issue | Location | Impact | Mitigation |
|---|---|---|---|
| Buffer access from CGEvent tap + main thread | TextReplacementService | Rare: corrupted buffer | NSLock (already implemented) |
| PublishedSubject emission off main thread | Services → ViewModel | Rare: SwiftUI glitch | Always dispatch to main queue |
| UserDefaults write during read | LocalStorageService | Rare: incomplete reads | Barrier writes + concurrent reads |

---

## Event System (NotificationCenter)

All cross-component communication via NotificationCenter to prevent circular dependencies:

| Event | Posted By | Listeners | Payload |
|---|---|---|---|
| `snippetsDidChange` | LocalSnippetsViewModel | TextReplacementService, LocalStorageService | Updated snippet array |
| `categoryDidChange` | CategoryViewModel | UI views | Category name/color change |
| `accessibilityPermissionDidChange` | AccessibilityPermissionManager | AppDelegate, SettingsView | New permission status |
| `appLaunchedForFirstTime` | GenSnippetsApp | OnboardingView (future) | App version |
| `importDidStartProgress` | ShareService | ShareImportSheet | (String, Int, Int) - filename, current, total |
| `settingsDidChange` | ModernSettingsView | TextReplacementService | Updated settings (hotkey, timing) |
| `hotkeysDidChange` | GlobalHotkeyManager | KeyboardInputView | Hotkey binding change |
| `metafieldPromptDismissed` | MetafieldService | TextReplacementService | User cancelled input dialog |

**Usage Pattern:**

```swift
// Post event
NotificationCenter.default.post(
  name: NSNotification.Name("snippetsDidChange"),
  object: self,
  userInfo: ["snippets": updatedSnippets]
)

// Listen for event
NotificationCenter.default.addObserver(
  self,
  selector: #selector(handleSnippetChange),
  name: NSNotification.Name("snippetsDidChange"),
  object: nil
)

// Handle event
@objc func handleSnippetChange(notification: NSNotification) {
  if let snippets = notification.userInfo?["snippets"] as? [Snippet] {
    updateMatchers(snippets)
  }
}
```

**Memory Safety (weak self required):**

```swift
// ❌ Bad: Strong reference can cause retain cycles
NotificationCenter.default.addObserver(
  self,
  selector: #selector(handleUpdate),
  name: NSNotification.Name("update"),
  object: nil
)

// ✅ Good: Use block-based observer with weak self
NotificationCenter.default.addObserver(
  forName: NSNotification.Name("update"),
  object: nil,
  queue: .main
) { [weak self] _ in
  self?.handleUpdate()
}
```

---

## Data Models & Relationships

### Snippet

```swift
struct Snippet: Codable, Identifiable {
  var id: UUID                           // Unique identifier
  var command: String                    // Trigger phrase (e.g., "!email")
  var replacementText: String            // Expansion text (supports keywords, metafields)
  var category: String                   // Category name (default: "Uncategory")
  var isEnabled: Bool                    // Can be disabled without deleting
  var isFavorite: Bool                   // Star for quick access
  var richContentItems: [RichContent]    // Images, files, URLs
  var createdDate: Date                  // Metadata
  var lastModifiedDate: Date             // Metadata
}

// Relationships:
// Snippet N:1 Category (by category name string)
```

### Category

```swift
struct Category: Codable, Identifiable {
  var id: UUID                   // Unique identifier
  var name: String               // Display name (unique)
  var color: String?             // Optional hex color
  var isCollapsed: Bool          // UI state (collapsed in sidebar)
  var sortOrder: Int?            // Custom sort order
}

// Relationships:
// Category 1:N Snippet (reverse: snippets with category.name == this.name)
```

### SnippetUsage

```swift
struct SnippetUsage: Codable {
  var command: String                    // Keyed by command string (not UUID)
  var count: Int                         // Total expansions
  var lastUsed: Date                     // Most recent expansion
  var createdDate: Date                  // First tracked usage
}

// Relationships:
// SnippetUsage N:1 Snippet (by command string match)
```

### RichContent

```swift
enum RichContent: Codable {
  case plainText(String)
  case image(path: String)               // File path (migrated from Base64 in v2.8.0)
  case file(path: String)                // File system path
  case url(String)                       // HTTP/HTTPS/mailto URLs
}

// Insertion order: sequential paste events, not simultaneous
```

### Storage Schema (UserDefaults JSON)

```json
{
  "localSnippets": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "command": "!email",
      "replacementText": "john@example.com",
      "category": "Personal",
      "isEnabled": true,
      "isFavorite": false,
      "richContentItems": []
    }
  ],
  "categories": [
    {
      "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
      "name": "Personal",
      "color": "#FF6B6B",
      "isCollapsed": false
    }
  ],
  "categoryOrders": {
    "Personal": 0,
    "Work": 1,
    "Code": 2,
    "Uncategory": 999
  },
  "snippetUsages": {
    "!email": {
      "count": 42,
      "lastUsed": "2026-02-08T10:30:00Z"
    }
  }
}
```

---

## Security Architecture

### Sandbox Status (App Sandbox Disabled since v2.7.1)

**Previous (v2.6 and earlier):** Full App Sandbox enabled with entitlements
**Current (v2.7.1+):** App Sandbox disabled for improved compatibility

**Access Available:**
- Full home directory read/write (~/Documents, ~/Desktop, etc.)
- UserDefaults access
- Clipboard read/write
- System Events (keyboard simulation)
- Accessibility framework (permission required)
- Pasteboard access (NSPasteboard)
- Unrestricted file access (no container restrictions)

**Note:** Sandbox was disabled to improve compatibility with various terminal emulators (iTerm2, Ghostty) and system applications. The app still runs with Hardened Runtime enabled for security.

### Data Protection

1. **In Transit:** No network, so N/A
2. **At Rest:** Plain JSON in UserDefaults
   - Location: `~/Library/Preferences/Jay8448.Gen-Snippets.plist`
   - Permissions: User read/write only
   - Encryption: FileVault (optional, user's choice)
   - Images: File-based storage (since v2.8.0) in user's file system

3. **Memory:** No encryption of snippets in RAM
   - Risk: Malware with accessibility could read snippets
   - Mitigation: User controls accessibility permissions

### Accessibility Permission Safety

- Users must explicitly grant permission (can't be automated)
- Permission check happens on every app launch
- Revocation immediately disables text replacement
- No automatic re-request (respects user intent)

---

## Performance Characteristics

### Latency Budget (Target: <100ms end-to-end)

| Stage | Latency | Notes |
|---|---|---|
| CGEvent capture | <1ms | System kernel level |
| Buffer append | <0.1ms | NSLock + array append |
| Trie search | <5ms | O(m) where m=command length |
| Metafield prompt | 50-100ms | User dialog appears |
| Keyword replacement | <2ms | Regex match + replacement |
| RichContent insertion | 100-300ms | Multiple CGEvent + delay |
| Delete command | <10ms | N × backspace CGEvent |
| Total (plain text) | <50ms | Typical fast path |
| Total (with metafield) | 100-150ms | Includes user dialog |
| Total (with image) | 200-400ms | Includes image base64 decode |

### Memory Usage

| Component | Typical | Peak |
|---|---|---|
| App base | 20MB | 25MB |
| Snippet cache (500) | 5MB | 8MB |
| Usage tracking (500) | 2MB | 3MB |
| UI/SwiftUI | 15MB | 20MB |
| **Total (500 snippets)** | **42MB** | **56MB** |
| **Total (1000 snippets)** | **60MB** | **80MB** |

### Optimization Strategies

1. **Trie Caching:** Built once per startup, cached in memory
2. **Snippet Sorting:** Sorted by length (longest first) for priority matching
3. **Regex Compilation:** Cached once per keyword pattern
4. **Date Formatter:** Singleton cached instances
5. **Batch Saves:** 0.5s coalescing prevents excessive UserDefaults writes
6. **Lazy Loading:** Views load snippet details only when displayed

---

## Error Recovery

### CGEvent Tap Failure

```
CGEvent tap crashes/fails
  ↓
EventTap callback error detected
  ↓
Stop current event tap
  ↓
Exponential backoff:
  - 1st retry: wait 1s
  - 2nd retry: wait 2s
  - 3rd retry: wait 4s
  - ...
  - Max wait: 10s
  ↓
Attempt reinit with new tap
  ↓
Log to console if repeated failures
Notify user via alert if repeated
  ↓
User manually restart app if needed
```

### Permission Loss Recovery

```
Accessibility permission revoked by user
  ↓
CGEvent tap fails
  ↓
AccessibilityPermissionManager detects
  ↓
Post "accessibilityPermissionDidChange" event
  ↓
SettingsView shows prompt
  ↓
User re-grants permission
  ↓
TextReplacementService restarts
```

---

## Deployment Architecture

### App Signing & Distribution

```
Developer Build
  │
  ├─→ Sign with Team ID
  │   (project.pbxproj configuration)
  │
  ├─→ Create DMG (create-dmg)
  │
  ├─→ Sign DMG with EdDSA (Sparkle)
  │
  ├─→ Generate appcast.xml
  │   (version, signature, download URL)
  │
  └─→ GitHub Release
      (DMG attachment + appcast.xml push)
```

### Auto-Update Flow (Sparkle)

```
App Launch
  │
  └─→ UpdaterService (SPUStandardUpdaterController)
      │
      ├─→ Fetch appcast.xml from GitHub
      │   (raw.githubusercontent.com)
      │
      ├─→ Compare MARKETING_VERSION vs appcast version
      │
      ├─ NO UPDATE → Silent, no action
      │
      └─ UPDATE AVAILABLE
          │
          └─→ Show update dialog (Sparkle UI)
              │
              ├─ "Install Update" → Download DMG
              │   → Verify EdDSA signature
              │   → Extract & replace app
              │   → Restart
              │
              ├─ "Remind Me Later" → Check again later
              │
              └─ "Skip This Version" → Ignore this version
```

---

## Recent Architectural Changes (v2.7+)

1. ✓ **App Sandbox Disabled (v2.7.1)** - Improved compatibility with terminals and system apps
2. ✓ **Image Storage Migration (v2.8.0)** - Base64 → file-based for better performance
3. ✓ **Keystroke Hang Fixes (v2.8.1)** - Support for iTerm2 and Ghostty terminals
4. ✓ **Terminal List Sync (v2.8.1)** - EdgeCaseHandler now synced with TextReplacementService
5. ✓ **Clipboard Race Condition Fix (v2.8.2)** - Improved clipboard access timing and error recovery
6. ✓ **Event Tap Timeout Recovery (v2.8.2)** - Enhanced event tap timeout detection and recovery

## Recent Architectural Changes (v2.9.0-v2.9.8)

7. ✓ **Sparkle Auto-Update (v2.9.0)** - In-app update via Sparkle 2.x with EdDSA signing
8. ✓ **Release Script (v2.9.0)** - Automated DMG creation, signing, appcast generation, GitHub release
9. ✓ **Background Mode (v2.9.6)** - Auto-enter background mode when launched as login item
10. ✓ **Startup Snippet Loading (v2.9.7)** - Load snippets on startup for background mode text replacement
11. ✓ **Window Management (v2.9.8)** - Create fresh window when opening app after login-item background launch

## Future Architectural Improvements (v3.0+)

1. **Unit Test Suite** - Add XCTest for core services (Trie, keyword replacement)
2. **iCloud Sync Completion** - Complete partial implementation
3. **CloudKit Integration** - Optional cloud backup
4. **Snippet Marketplace** - Sharing & discovering snippets
5. **SwiftData Migration** - Replace UserDefaults with SwiftData (if targeting macOS 14+)
6. **Concurrent Rendering** - SwiftUI renderingMode optimizations
7. **Accessibility Improvements** - VoiceOver, keyboard navigation

---

**Last Updated:** March 21, 2026
**Maintainer:** Jay Nguyen
**Current Version:** 2.9.8
