# GenSnippets: Code Standards & Guidelines

**Framework:** Swift 5.5+, SwiftUI, AppKit
**Architecture Pattern:** MVVM + Service Layer
**Code Style:** Apple Swift API Design Guidelines
**Last Reviewed:** March 14, 2026
**Current Version:** 2.8.2
**Sandbox Status:** Disabled (since v2.7.1)

---

## File Organization

### File Naming Conventions

| Category | Pattern | Example | Rules |
|---|---|---|---|
| **App Entry** | PascalCase | `GenSnippetsApp.swift` | Main app delegate |
| **Services** | PascalCase + "Service" | `TextReplacementService.swift` | Singleton services |
| **View Models** | PascalCase + "ViewModel" | `LocalSnippetsViewModel.swift` | Observable models |
| **Views** | PascalCase + "View" | `SnippetDetailView.swift` | SwiftUI views |
| **Models** | PascalCase | `Snippet.swift`, `Category.swift` | Data structures |
| **Design System** | `DesignSystem.swift` | Single file | Colors, fonts, tokens |
| **Controllers** | PascalCase + "Controller" | `SnippetSearchWindowController.swift` | Window/window scene management |
| **Extensions** | `SourceType+ExtensionName.swift` | `String+Localization.swift` | Swift extensions |

**File Size Targets:**
- **Services:** <400 LOC (break into multiple files if >400)
- **Views:** <300 LOC (extract sub-components if >300)
- **Models:** <200 LOC (usually small, acceptable)
- **Controllers:** <200 LOC

### Directory Structure

```
GenSnippets/
├── GenSnippetsApp.swift              // App entry point
├── DesignSystem.swift                // Design tokens
├── Services/                         // Business logic (singleton)
│   ├── TextReplacementService.swift
│   ├── LocalStorageService.swift
│   └── ...
├── Views/                            // UI components
│   ├── ThreeColumnView.swift
│   ├── AddSnippetSheet.swift
│   └── ...
├── Models/                           // Data structures
│   ├── Snippet.swift
│   ├── Category.swift
│   └── ...
├── Components/                       // Reusable UI components
│   └── ToastView.swift
├── Controllers/                      // Window management
│   └── SnippetSearchWindowController.swift
├── Extensions/                       // Swift extensions
│   └── String+Localization.swift
└── Resources/
    ├── Assets.xcassets/
    └── Localizable.strings
```

---

## Swift Code Style

### Naming Conventions

| Element | Convention | Example | Notes |
|---|---|---|---|
| **Types** | PascalCase | `Snippet`, `Category`, `TextReplacementService` | Classes, structs, enums |
| **Properties** | camelCase | `replacementText`, `isEnabled`, `lastUsed` | Computed or stored |
| **Methods** | camelCase | `saveSnippets()`, `matchCommand()` | Verb-first naming |
| **Constants** | camelCase | `maxSnippets = 1000` | Global/type constants |
| **Enums** | PascalCase | `RichContent`, `PermissionStatus` | Type names |
| **Enum Cases** | camelCase | `.plainText`, `.image`, `.url` | Case names |
| **Boolean Properties** | `is`/`has` prefix | `isEnabled`, `hasConflict` | Clarity on boolean type |
| **Closures** | camelCase | `onComplete`, `didSave` | Callback parameters |

### Code Format

**Line Length:** Max 120 characters (hard limit 140)

**Indentation:** 2 spaces (NOT tabs)

```swift
// Good
struct Snippet: Codable {
  var command: String
  var replacementText: String
  var category: String
  var isEnabled: Bool
}

// Bad (4 spaces)
struct Snippet: Codable {
    var command: String
}
```

**Brace Placement:** Opening brace on same line (K&R style)

```swift
// Good
func saveSnippets() {
  // implementation
}

// Bad
func saveSnippets()
{
  // implementation
}
```

**String Formatting:** Use Swift string interpolation, avoid NSString

```swift
// Good
let message = "Snippet '\(snippet.command)' saved"

// Bad
let message = NSString(format: "Snippet '%@' saved", snippet.command)
```

### Access Control

- **Default to `internal`** (within module)
- **`private`** - Only for true file-private implementation details
- **`fileprivate`** - Rarely used; prefer `private` + extension
- **`public`** - Never used (single-app target)

```swift
// Good: Clear encapsulation
class TextReplacementService {
  private let bufferLock = NSLock()
  private var eventTap: CFMachPort?

  func startMonitoring() { }  // internal (default)
}

// Bad: Overly exposed
class TextReplacementService {
  let bufferLock = NSLock()  // Should be private
  var eventTap: CFMachPort?  // Should be private
}
```

---

## SwiftUI Best Practices

### View Composition

Break large views into smaller, reusable components:

```swift
// SnippetDetailView (1,245 LOC) should be split:
struct SnippetDetailView: View {
  @State var snippet: Snippet

  var body: some View {
    VStack {
      SnippetDetailHeader(snippet: snippet)  // Extract
      SnippetContentEditor(snippet: $snippet)  // Extract
      SnippetRichContentPicker(snippet: $snippet)  // Extract
    }
  }
}

// New extracted component
struct SnippetContentEditor: View {
  @Binding var snippet: Snippet

  var body: some View {
    // Editor logic only
  }
}
```

**Size Targets:**
- Main views: <400 LOC
- Helper views: <200 LOC
- Single-purpose components: <100 LOC

### State Management

1. **@StateObject** - View model owned by this view
   ```swift
   struct ContentView: View {
     @StateObject var viewModel = LocalSnippetsViewModel()
   }
   ```

2. **@ObservedObject** - View model passed from parent
   ```swift
   struct ThreeColumnView: View {
     @ObservedObject var viewModel: LocalSnippetsViewModel
   }
   ```

3. **@State** - Single-value UI state only
   ```swift
   struct AddSnippetSheet: View {
     @State var commandText = ""
     @State var isExpanded = false
   }
   ```

4. **@Published** - In observable view models
   ```swift
   class LocalSnippetsViewModel: ObservableObject {
     @Published var snippets: [Snippet] = []
   }
   ```

### Avoid Common Mistakes

```swift
// ❌ Bad: Mutating published property directly
viewModel.snippets[0].command = "new"  // Does NOT trigger update

// ✅ Good: Use binding or replace entire array
viewModel.snippets[0].command = "new"
viewModel.objectWillChange.send()  // Explicit update

// OR better: Dedicated method
viewModel.updateSnippet(id: snippet.id, command: "new")
```

---

## Service Layer Design

### Singleton Pattern (Correct)

All services use thread-safe singleton:

```swift
class TextReplacementService {
  static let shared = TextReplacementService()

  private init() {
    // Initialization only once
  }

  // Public methods
  func startMonitoring() { }
}

// Usage
TextReplacementService.shared.startMonitoring()
```

### Thread Safety

**Protect shared mutable state:**

```swift
class TextReplacementService {
  private let bufferLock = NSLock()
  private var buffer: [Character] = []

  func addToBuffer(_ char: Character) {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    buffer.append(char)
  }
}
```

**Use DispatchQueue for concurrent access:**

```swift
class LocalStorageService {
  private let storageQueue = DispatchQueue(
    label: "com.gesnippets.storage",
    attributes: .concurrent
  )

  func saveSnippets(_ snippets: [Snippet]) {
    storageQueue.async(flags: .barrier) {
      // Write operation
    }
  }

  func loadSnippets() -> [Snippet] {
    storageQueue.sync {
      // Read operation
    }
  }
}
```

### Service Dependencies

Avoid circular dependencies via NotificationCenter:

```swift
// ❌ Bad: Circular dependency
class ViewModelA {
  var serviceB: ServiceB  // Strong reference
}

class ServiceB {
  var viewModelA: ViewModelA  // Strong reference → retain cycle
}

// ✅ Good: Notification-based
class ViewModelA {
  NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleServiceUpdate),
    name: NSNotification.Name("ServiceBDidUpdate"),
    object: nil
  )
}

class ServiceB {
  func update() {
    NotificationCenter.default.post(
      name: NSNotification.Name("ServiceBDidUpdate"),
      object: nil
    )
  }
}
```

---

## Error Handling

### Approach: Result Type + Logging

```swift
// Define error type
enum SnippetError: LocalizedError {
  case invalidCommand
  case saveFailed(String)
  case importConflict([Snippet])

  var errorDescription: String? {
    switch self {
    case .invalidCommand:
      return "Command cannot be empty or contain only spaces"
    case .saveFailed(let reason):
      return "Save failed: \(reason)"
    case .importConflict:
      return "Import conflicts detected"
    }
  }
}

// Use in service methods
func saveSnippet(_ snippet: Snippet) throws {
  guard !snippet.command.trimmingCharacters(in: .whitespaces).isEmpty else {
    throw SnippetError.invalidCommand
  }

  do {
    let encoded = try JSONEncoder().encode(snippet)
    // Save...
  } catch {
    throw SnippetError.saveFailed(error.localizedDescription)
  }
}

// Usage
do {
  try service.saveSnippet(snippet)
  showToast("Saved successfully")
} catch {
  showAlert(error.localizedDescription)
}
```

### Avoid Silent Failures

```swift
// ❌ Bad: Silent failure
func saveSnippets() {
  do {
    // Save logic
  } catch {
    // Ignored!
  }
}

// ✅ Good: Log or throw
func saveSnippets() throws {
  do {
    // Save logic
  } catch {
    logger.error("Save failed: \(error)")
    throw error
  }
}
```

---

## Testing Standards

### Current Status
- **No XCTest suite yet** (validation script exists as placeholder)
- **Target:** >80% coverage by v2.9

### Testing Strategy (Future)

1. **Unit Tests** (TextReplacementService)
   - Trie insertion and matching
   - Keyword replacement
   - Buffer management
   - Thread safety

2. **Integration Tests** (ViewModels + Services)
   - Snippet CRUD operations
   - Category management
   - Batch saves

3. **UI Tests** (Views)
   - Snippet form validation
   - Import flow with conflicts
   - Search functionality

### Test File Naming
```swift
// XCTest file pattern
GenSnippetsTests/
├── Services/
│   └── TextReplacementServiceTests.swift
├── Models/
│   └── SnippetTests.swift
└── Views/
    └── AddSnippetSheetTests.swift
```

---

## Design System Integration

### Using DesignSystem.swift

All UI should use DS* components from `DesignSystem.swift`:

```swift
// ❌ Bad: Raw SwiftUI
VStack(spacing: 16) {
  Text("Title")
    .font(.system(size: 18, weight: .bold))
    .foregroundColor(.blue)
}

// ✅ Good: Design system
VStack(spacing: .md) {
  Text("Title")
    .font(.dsHeadline)
    .foregroundColor(.dsAccent)
}
```

**Available Tokens:**
- **Colors:** `dsAccent`, `dsBackground`, `dsText`, `dsSecondary`, `dsBorder`
- **Typography:** `dsLargeTitle`, `dsTitle`, `dsHeadline`, `dsBody`, `dsCaption`
- **Spacing:** `.xs` (4), `.sm` (8), `.md` (16), `.lg` (24), `.xl` (32), `.xxl` (48)

---

## Performance Considerations

### Avoid Expensive Operations on Main Thread

```swift
// ❌ Bad: Blocks UI
func saveSnippets() {
  let encoded = try JSONEncoder().encode(snippets)  // Main thread
  UserDefaults.standard.set(encoded, forKey: "snippets")
}

// ✅ Good: Async
func saveSnippets() {
  DispatchQueue.global(qos: .utility).async {
    let encoded = try JSONEncoder().encode(self.snippets)
    UserDefaults.standard.set(encoded, forKey: "snippets")
  }
}
```

### Lazy Initialization

```swift
// ❌ Bad: Create every access
func getFormatter() -> DateFormatter {
  return DateFormatter()  // New instance every time
}

// ✅ Good: Cache
private let cachedFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "dd/MM/yyyy"
  return formatter
}()
```

### Memory Limits

- **Snippet Cache:** Max 1,000 snippets
- **Usage History:** Max 1,000 entries
- **Rolling Buffer:** Fixed at 50 characters
- **Event Tap Memory:** <10MB typical

---

## Security Best Practices

### Never Log Sensitive Data

```swift
// ❌ Bad: Sensitive in logs
logger.debug("User pasted: \(pastedContent)")

// ✅ Good: Generic logging
logger.debug("Paste operation completed")
```

### File Permissions

```swift
// ❌ Bad: World-readable
let path = "/tmp/snippets.json"

// ✅ Good: Restricted
let path = FileManager.default.urls(
  for: .applicationSupportDirectory,
  in: .userDomainMask
).first!.appendingPathComponent("snippets.json")
```

### Sandbox Compliance

- No home directory access (use standard directories)
- No network requests
- No shell execution
- No system framework access without entitlements

---

## Documentation Standards

### Code Comments

```swift
// ❌ Bad: Obvious comment
let count = snippets.count  // Get the count

// ✅ Good: Why, not what
// Limit to 1000 snippets to prevent UserDefaults overflow
let count = min(snippets.count, 1000)
```

### Function Documentation

```swift
/// Saves snippets to UserDefaults with batch coalescing.
/// - Parameter snippets: Array of snippets to persist
/// - Throws: SnippetError if encoding or write fails
/// - Note: Coalesces multiple calls within 0.5 seconds
func saveSnippets(_ snippets: [Snippet]) throws {
  // Implementation
}
```

### MARK Comments

```swift
class LocalSnippetsViewModel: ObservableObject {
  // MARK: - Properties
  @Published var snippets: [Snippet] = []

  // MARK: - Initialization
  init() { }

  // MARK: - Public Methods
  func addSnippet(_ snippet: Snippet) { }

  // MARK: - Private Methods
  private func validateCommand(_ command: String) -> Bool { }
}
```

---

## Common Patterns

### Binding Transformations

```swift
// Create computed binding for transformation
@Binding var snippet: Snippet

var commandBinding: Binding<String> {
  .init(
    get: { snippet.command.lowercased() },
    set: { snippet.command = $0.lowercased() }
  )
}

// Use in TextField
TextField("Command", text: commandBinding)
```

### List with Optional State

```swift
struct SnippetListView: View {
  @ObservedObject var viewModel: LocalSnippetsViewModel
  @State var selectedSnippet: Snippet?

  var body: some View {
    List(viewModel.snippets) { snippet in
      SnippetRow(snippet: snippet)
        .onTapGesture {
          selectedSnippet = snippet
        }
    }
    .sheet(item: $selectedSnippet) { snippet in
      SnippetDetailView(snippet: $viewModel.snippets[...])
    }
  }
}
```

---

## Deprecation & Removal

When deprecating code:

```swift
@available(*, deprecated, message: "Use ModernSnippetSearchView instead")
struct SnippetSearchView: View {
  var body: some View { }
}
```

Target removal:
- **v3.0** - Remove `SnippetSearchView`, `SettingsView`, `ExportImportView`, `SnippetsViewModel`

---

## Checklist for PRs

Before submitting a pull request:

- [ ] Code follows naming conventions (PascalCase types, camelCase properties)
- [ ] File size <400 LOC (services), <300 LOC (views)
- [ ] No sensitive data in logs
- [ ] No direct UserDefaults access outside LocalStorageService
- [ ] Thread-safe shared mutable state
- [ ] Uses Design System tokens (colors, fonts, spacing)
- [ ] NotificationCenter for cross-component communication
- [ ] Errors thrown or logged (no silent failures)
- [ ] Updated documentation comments if API changed
- [ ] No new third-party dependencies added
- [ ] Builds without warnings (`xcodebuild clean build`)

---

**Last Updated:** March 14, 2026
**Maintainer:** Jay Nguyen
