# Research Report: Modern SwiftUI Best Practices for macOS App Development (2024-2025)

**Report Date:** December 4, 2025
**Research Scope:** SwiftUI patterns for macOS, menu bar apps, layout systems, UI components, styling, animations, and accessibility
**Target:** GenSnippets macOS application modernization

---

## Executive Summary

SwiftUI on macOS 14-15 has matured significantly with powerful declarative patterns for building native-feeling applications. Key findings:

1. **NavigationSplitView** is the modern standard for three-column layouts, replacing NavigationView with superior macOS integration and responsiveness.
2. **Menu bar apps** require hybrid AppKit-SwiftUI approach: NSStatusItem for system integration + NSPopover for UI presentation + SwiftUI for the visual layer.
3. **Modern macOS styling** leverages built-in materials (.ultraThinMaterial, .regularMaterial, .thickMaterial) with implicit vibrancy, eliminating need for manual NSVisualEffectView wrapping.
4. **Table component** provides native macOS table UI with sorting, selection, and accessibility built-in; superior to List for data-heavy interfaces.
5. **State management** critical: use @State for local UI, @Environment for system values, granular property passing to avoid unnecessary re-renders.
6. **Animations** should be purpose-driven: matchedGeometryEffect for hero transitions, .transition() for entry/exit, .animation(value:) for state-tied changes.
7. **Accessibility** non-negotiable: VoiceOver testing, Dynamic Type support, keyboard navigation, semantic labels mandatory for macOS apps.

---

## Research Methodology

**Sources Consulted:** 5 deep-dive Gemini research queries covering macOS SwiftUI patterns, menu bar development, UI components, code patterns, and accessibility.

**Date Range:** Current 2024-2025 macOS development guidance (latest WWDC 2024 sessions, current framework documentation).

**Key Search Terms:** NavigationSplitView, menu bar apps, NSStatusItem, macOS materials, Table component, matchedGeometryEffect, VoiceOver, Dynamic Type, SwiftUI accessibility, toolbar patterns, settings windows.

---

## Key Findings

### 1. NavigationSplitView: Modern Three-Column Architecture

**Status:** Production-ready standard for macOS 13+ (preferred over NavigationView).

**Core Structure:**
```swift
NavigationSplitView {
    // Sidebar (column 1)
} content: {
    // Content/list (column 2)
} detail: {
    // Detail view (column 3)
}
```

**Column Visibility Control:**
- `.all` - Shows all three columns (default macOS desktop behavior)
- `.doubleColumn` - Hides detail until selected
- `.detailOnly` - Shows only detail view
- `.automatic` - System determines best layout

**Style Options:**
- `.balanced` - Equal column widths, detail alongside content
- `.prominentDetail` - Detail takes precedence, content overlays sidebar

**Column Width Management:**
```swift
.navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 350)
```

**Key Advantages:**
- Automatic responsive behavior (collapses on narrow screens)
- Native macOS feel with proper drag handles
- Translucent sidebar with material background
- Keyboard navigation built-in
- Accessibility features inherent

---

### 2. Menu Bar App Development Pattern

**Hybrid Architecture Required:** SwiftUI UI layer + AppKit system integration

**Two Approaches:**

#### Approach A: MenuBarExtra (Simpler, Limited Control)
```swift
@main
struct GenSnippetsApp: App {
    var body: some Scene {
        MenuBarExtra("GenSnippets", systemImage: "text.badge.plus") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window) // Popover-style behavior
    }
}
```
**Pros:** Minimal code, automatic handling
**Cons:** Limited customization, fixed behavior

#### Approach B: NSStatusItem + NSPopover (Full Control, Recommended)
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.badge.plus",
                                 accessibilityDescription: "GenSnippets")
            button.action = #selector(togglePopover(_:))
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 300)
        popover?.behavior = .transient // Hides when clicking outside
        popover?.contentViewController = NSHostingController(rootView: MenuBarContentView())
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true) // Bring to front
            }
        }
    }
}

@main
struct GenSnippetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

**Window Management for Main Window:**
```swift
class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.contentView = NSHostingView(rootView: ContentView())
        self.init(window: window)
    }

    func showWindow() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

**Background/Agent Mode (LSUIElement):**

Add to Info.plist:
```xml
<key>LSUIElement</key>
<true/>
```

Effects:
- Hides from Dock
- Hides from Cmd+Tab switcher
- No automatic menu bar
- Requires programmatic menu construction

**Programmatic Activation Policy:**
```swift
// In AppDelegate.applicationDidFinishLaunching
NSApp.setActivationPolicy(.accessory) // Background mode
NSApp.setActivationPolicy(.regular)   // Normal windowed mode
```

**Menu Construction for LSUIElement Apps:**
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu

    appMenu.addItem(withTitle: "About GenSnippets",
                   action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                   keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Preferences...",
                   action: #selector(openPreferences),
                   keyEquivalent: ",")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit GenSnippets",
                   action: #selector(NSApplication.terminate(_:)),
                   keyEquivalent: "q")

    NSApp.mainMenu = mainMenu
}

@objc func openPreferences() {
    mainWindowController?.showWindow()
}
```

**Spotlight Integration:**
```swift
import CoreSpotlight

func indexSnippet(id: String, title: String, content: String, category: String) {
    let attributeSet = CSSearchableItemAttributeSet(itemContentType: "public.text")
    attributeSet.title = title
    attributeSet.contentDescription = content
    attributeSet.keywords = [category, "snippet", title]

    let item = CSSearchableItem(
        uniqueIdentifier: id,
        domainIdentifier: "com.yourcompany.GenSnippets.snippets",
        attributeSet: attributeSet
    )

    CSSearchableIndex.default().indexSearchableItems([item]) { error in
        if let error = error {
            print("Error indexing: \(error.localizedDescription)")
        }
    }
}

// Handle Spotlight selection
func application(_ application: NSApplication,
                continue userActivity: NSUserActivity,
                restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
    if userActivity.activityType == CSSearchableItemActionType {
        if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            mainWindowController?.showWindow()
            // Navigate to snippet with this ID
            return true
        }
    }
    return false
}
```

---

### 3. Modern macOS UI Components & Styling

#### Toolbar Pattern
```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text("Main Content")
                .toolbar {
                    // Navigation button (left side)
                    ToolbarItem(placement: .navigation) {
                        Button(action: toggleSidebar) {
                            Label("Toggle Sidebar", systemImage: "sidebar.left")
                        }
                    }

                    // Principal title (center)
                    ToolbarItem(placement: .principal) {
                        Text("My App Title").font(.headline)
                    }

                    // Primary actions (right side)
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Item") { }
                    }

                    // Status indicator (right, after primary)
                    ToolbarItem(placement: .status) {
                        Text("Ready").font(.caption)
                    }
                }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
        )
    }
}
```

**ToolbarItemPlacement Options:**
- `.navigation` - Sidebar/back button area
- `.principal` - Center title area
- `.primaryAction` - Right side, primary actions
- `.status` - Far right status area
- `.automatic` - System decides placement
- `.secondaryAction` - Secondary/overflow menu

#### Settings Window
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @AppStorage("enableFeatureX") private var enableFeatureX = true
    @AppStorage("username") private var username = "Guest"

    var body: some View {
        Form {
            Toggle("Enable Feature X", isOn: $enableFeatureX)
            TextField("Username", text: $username)

            Section("Advanced") {
                Button("Reset All Settings") {
                    // Reset action
                }
            }
        }
        .padding()
        .frame(width: 400, height: 200)
        .navigationTitle("Preferences")
    }
}
```

#### Materials & Vibrancy (macOS 12+)
```swift
VStack(spacing: 20) {
    // Ultra thin material - least prominent
    Text("Ultra Thin Material")
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)

    // Regular material - balanced
    Text("Regular Material")
        .padding()
        .background(.regularMaterial)
        .cornerRadius(10)

    // Thick material - most prominent
    Text("Thick Material")
        .padding()
        .background(.thickMaterial)
        .cornerRadius(10)

    // Specialized materials
    Text("Sidebar Material")
        .padding()
        .background(.sidebar)
        .cornerRadius(10)

    Text("Bar Material")
        .padding()
        .background(.bar)
        .cornerRadius(10)
}
```

**Material Properties:**
- Automatically adapts to light/dark mode
- Includes built-in blur effect
- Vibrancy handled implicitly (text remains readable)
- No need for NSVisualEffectView wrapper in modern apps
- Respects system wallpaper color tint

#### Table Component (Superior to List for Data)
```swift
struct SnippetTableView: View {
    @State private var snippets: [Snippet] = []
    @State private var selectedSnippet: Snippet.ID?
    @State private var sortOrder: [KeyPathComparator<Snippet>] = [
        .init(\.command, order: .forward)
    ]

    var body: some View {
        Table(snippets, selection: $selectedSnippet, sortOrder: $sortOrder) {
            TableColumn("Command", value: \.command) { snippet in
                Text(snippet.command)
                    .font(.monospace)
            }

            TableColumn("Category", value: \.category) { snippet in
                Text(snippet.category)
            }

            TableColumn("Uses", value: \.usageCount) { snippet in
                Text("\(snippet.usageCount)")
                    .alignment(.trailing)
            }
        }
        .onChange(of: sortOrder) { oldValue, newValue in
            snippets.sort(using: newValue)
        }
    }
}
```

**Table Advantages:**
- Native macOS sorting/column reordering
- Built-in hover effects
- Selection handling
- Accessibility features included
- Better performance for large datasets than List

---

### 4. Navigation & Layout Patterns

#### Complete Three-Column Example
```swift
struct ContentView: View {
    @State private var categories: [String] = ["SwiftUI", "Python", "SQL"]
    @State private var snippets: [Snippet] = []
    @State private var selectedCategory: String? = "SwiftUI"
    @State private var selectedSnippet: Snippet.ID?

    private var filteredSnippets: [Snippet] {
        guard let category = selectedCategory else { return snippets }
        return snippets.filter { $0.category == category }
    }

    var body: some View {
        NavigationSplitView {
            // COLUMN 1: Categories Sidebar
            List(categories, id: \.self, selection: $selectedCategory) { category in
                Text(category)
                    .badge(snippets.filter { $0.category == category }.count)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) {
                        Label("Toggle", systemImage: "sidebar.left")
                    }
                }
            }
        } content: {
            // COLUMN 2: Snippets Table
            Table(filteredSnippets, selection: $selectedSnippet) {
                TableColumn("Command", value: \.command) { snippet in
                    Text(snippet.command)
                }
                TableColumn("Category", value: \.category) { snippet in
                    Text(snippet.category)
                }
            }
            .navigationTitle("Snippets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addSnippet) {
                        Label("Add", systemImage: "plus.circle")
                    }
                }
            }
        } detail: {
            // COLUMN 3: Detail View
            if let selectedSnippet = selectedSnippet,
               let snippet = snippets.first(where: { $0.id == selectedSnippet }) {
                DetailView(snippet: snippet)
            } else {
                Text("Select a snippet")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
        )
    }

    private func addSnippet() {
        // Implementation
    }
}
```

---

### 5. Animations & Transitions

#### State-Driven Animations
```swift
struct AnimationExample: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            // Implicit animation tied to state
            Text("Content")
                .frame(height: isExpanded ? 200 : 50)
                .animation(.easeInOut(duration: 0.3), value: isExpanded)

            Button(isExpanded ? "Collapse" : "Expand") {
                isExpanded.toggle()
            }
        }
    }
}
```

#### Transition Patterns
```swift
struct TransitionExample: View {
    @State private var showDetail = false

    var body: some View {
        VStack {
            if showDetail {
                DetailView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Button("Toggle Detail") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDetail.toggle()
                }
            }
        }
    }
}
```

#### Hero Transition with matchedGeometryEffect
```swift
struct HeroTransitionExample: View {
    @State private var selectedID: UUID?
    @Namespace private var heroNamespace

    var body: some View {
        if selectedID == nil {
            // Grid view
            ScrollView {
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    ForEach(items) { item in
                        ItemCard(item: item)
                            .matchedGeometryEffect(
                                id: item.id,
                                in: heroNamespace,
                                properties: .frame,
                                anchor: .topLeading
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedID = item.id
                                }
                            }
                    }
                }
            }
        } else if let selected = items.first(where: { $0.id == selectedID }) {
            // Detail view with matched geometry
            VStack {
                selected.image
                    .matchedGeometryEffect(
                        id: selected.id,
                        in: heroNamespace,
                        properties: .frame,
                        anchor: .topLeading
                    )

                VStack(alignment: .leading) {
                    Text(selected.title)
                    Text(selected.description)
                }
                .transition(.opacity)

                Spacer()

                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedID = nil
                    }
                }
            }
        }
    }
}
```

**matchedGeometryEffect Best Practices:**
- Limit to 5-6 simultaneous matches (performance)
- Use `.properties(.frame)` to animate only frame, not all properties
- Apply to element level, not container level
- Apply cornerRadius *after* matchedGeometryEffect
- Don't add separate `.animation()` modifier
- Declare @Namespace at parent level scoping matched views

---

### 6. Accessibility (VoiceOver, Dynamic Type, Keyboard)

#### Semantic Labels & Hints
```swift
struct AccessibleSnippetRow: View {
    let snippet: Snippet

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(snippet.command)
                    .font(.headline)
                Text(snippet.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(snippet.usageCount)")
        }
        .accessibilityElement(children: .combine) // Combine children into single element
        .accessibilityLabel("Snippet: \(snippet.command)")
        .accessibilityValue(snippet.category)
        .accessibilityHint("Double-tap to edit or view details")
    }
}
```

#### Dynamic Type Support
```swift
struct DynamicTypeExample: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 8) {
            Text("Heading")
                .font(.title)
                .dynamicTypeSize(.medium ... .xxxLarge) // Limit size range

            Text("Body text")
                .font(.body)
                .lineLimit(nil) // Allow wrapping for large text
        }
    }
}
```

#### Keyboard Navigation
```swift
struct KeyboardNavigableList: View {
    @State private var selectedIndex: Int = 0
    let items: [String]

    var body: some View {
        VStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(item) {
                    selectedIndex = index
                }
                .focusable(selectedIndex == index)
                .keyboardShortcut(String(index + 1))
            }
        }
        .onKeyPress { press in
            if press.key == .upArrow {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            } else if press.key == .downArrow {
                selectedIndex = min(items.count - 1, selectedIndex + 1)
                return .handled
            }
            return .ignored
        }
    }
}
```

#### VoiceOver Testing Checklist
- Cmd+F5 to enable VoiceOver on macOS
- Tab through all interactive elements
- Verify all buttons have descriptive labels
- Test with screen reader active
- Ensure focus indicators visible
- Test with Accessibility Inspector (Xcode)

#### Custom Control Accessibility
```swift
struct CustomToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack {
                Text(label)
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn ? .green : .gray)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .offset(x: isOn ? 10 : -10)
                    )
                    .frame(width: 40, height: 24)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double-tap to toggle")
        .accessibilityAddTraits(.isToggle)
    }
}
```

#### Reduced Motion Support
```swift
struct ReducedMotionExample: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Text("Content")
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.3),
                value: isShowing
            )
    }
}
```

---

## Comparative Analysis

### NavigationSplitView vs. NavigationView
| Feature | NavigationSplitView | NavigationView |
|---------|-------------------|-----------------|
| macOS native feel | ✅ Yes | ⚠️ Partial |
| Responsive collapse | ✅ Yes | ❌ No |
| Three-column support | ✅ Yes | ❌ Limited |
| Sidebar styling | ✅ Native | ⚠️ Custom required |
| WWDC 2024 status | ✅ Recommended | ⚠️ Legacy |

### Menu Bar Approaches
| Approach | MenuBarExtra | NSStatusItem |
|----------|-------------|-------------|
| Code complexity | ✅ Simple | ⚠️ Moderate |
| Customization | ❌ Limited | ✅ Full |
| Window control | ⚠️ Basic | ✅ Advanced |
| Spotlight support | ⚠️ No | ✅ Yes |
| Recommended for GenSnippets | ❌ No | ✅ Yes |

### Materials vs. NSVisualEffectView
| Aspect | SwiftUI Materials | NSVisualEffectView |
|--------|------------------|------------------|
| Code simplicity | ✅ Declarative | ❌ Imperative |
| Performance | ✅ Optimized | ⚠️ System overhead |
| Vibrancy handling | ✅ Automatic | ⚠️ Manual |
| Dark mode support | ✅ Built-in | ⚠️ Manual |
| Recommended | ✅ Yes | ❌ Legacy |

---

## Implementation Recommendations

### Quick Start Guide for GenSnippets Modernization

**Phase 1: Navigation Architecture**
1. Replace NavigationView with NavigationSplitView
2. Implement three-column: Categories (sidebar) → Snippets (table) → Details
3. Add column width controls with `.navigationSplitViewColumnWidth()`
4. Implement sidebar toggle button in toolbar

**Phase 2: Menu Bar Integration**
1. Set up NSStatusItem with NSPopover for menu bar presence
2. Configure Info.plist with LSUIElement = true
3. Build programmatic menu for preferences/quit
4. Implement Spotlight indexing for snippet search

**Phase 3: UI Modernization**
1. Replace custom backgrounds with `.background(.regularMaterial)`
2. Convert settings to Settings scene pattern
3. Update toolbars with proper placements
4. Implement Table component for snippet lists

**Phase 4: Animations & Polish**
1. Add state-driven animations to list selections
2. Implement transition for detail view appearance
3. Use matchedGeometryEffect for category→detail flow
4. Respect reduced motion settings

**Phase 5: Accessibility**
1. Add accessibilityLabel to all buttons/icons
2. Test with VoiceOver enabled (Cmd+F5)
3. Support Dynamic Type by avoiding fixed font sizes
4. Implement keyboard navigation for snippet selection
5. Use Accessibility Inspector to verify no warnings

---

## Code Examples

### Complete Minimal Three-Column App
```swift
import SwiftUI

@main
struct GenSnippetsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        Settings {
            SettingsView()
        }
    }
}

struct ContentView: View {
    @State private var categories = ["SwiftUI", "Python", "SQL"]
    @State private var selectedCategory: String? = "SwiftUI"
    @State private var selectedSnippetID: UUID?

    var body: some View {
        NavigationSplitView {
            List(categories, id: \.self, selection: $selectedCategory) { category in
                Text(category)
            }
            .navigationTitle("Categories")
        } content: {
            SnippetTable(category: selectedCategory ?? "")
        } detail: {
            if let id = selectedSnippetID {
                SnippetDetail(snippetID: id)
            } else {
                Text("Select a snippet")
            }
        }
    }
}

struct SnippetTable: View {
    let category: String
    @State private var snippets: [Snippet] = []
    @State private var selectedID: UUID?

    var body: some View {
        Table(snippets, selection: $selectedID) {
            TableColumn("Command", value: \.command) { s in Text(s.command) }
            TableColumn("Uses", value: \.usageCount) { s in Text("\(s.usageCount)") }
        }
        .navigationTitle("Snippets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) { Label("Add", systemImage: "plus") }
            }
        }
    }
}

struct SnippetDetail: View {
    let snippetID: UUID

    var body: some View {
        VStack(alignment: .leading) {
            Text("Snippet Details")
                .font(.title)
            Spacer()
        }
        .padding()
    }
}

struct SettingsView: View {
    @AppStorage("autoExpand") private var autoExpand = true

    var body: some View {
        Form {
            Toggle("Auto-expand snippets", isOn: $autoExpand)
        }
        .frame(width: 400, height: 200)
    }
}

struct Snippet: Identifiable {
    let id = UUID()
    let command: String
    let usageCount: Int
}
```

### Menu Bar App Template
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status item setup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.badge.plus",
                                 accessibilityDescription: "GenSnippets")
            button.action = #selector(togglePopover)
        }

        // Popover setup
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 300)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        // Main window setup
        mainWindowController = MainWindowController()

        // Menu setup
        setupMenu()

        // Spotlight indexing
        indexAllSnippets()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About GenSnippets",
                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                       keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences...",
                       action: #selector(openPreferences),
                       keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit GenSnippets",
                       action: #selector(NSApplication.terminate(_:)),
                       keyEquivalent: "q")

        NSApp.mainMenu = mainMenu
    }

    @objc func openPreferences() {
        mainWindowController?.showWindow()
    }

    private func indexAllSnippets() {
        import CoreSpotlight
        // Implement Spotlight indexing
    }
}

@main
struct GenSnippetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("Quick Search")
            TextField("Type to search...", text: .constant(""))
            List {
                Text("Recent snippet 1")
                Text("Recent snippet 2")
            }
        }
        .padding()
    }
}

class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.setFrameAutosaveName("MainWindow")
        window.contentView = NSHostingView(rootView: MainWindowView())
        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MainWindowView: View {
    var body: some View {
        ContentView()
    }
}
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Over-Animation Reducing Motion
**Problem:** Animations ignore accessibility settings.
**Solution:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(
    reduceMotion ? .none : .easeInOut(duration: 0.3),
    value: someState
)
```

### Pitfall 2: matchedGeometryEffect Performance
**Problem:** Too many matched views cause frame drops.
**Solution:** Limit to 5-6 simultaneous matches, use `.properties(.frame)` to animate only frame.

### Pitfall 3: NavigationSplitView Column Collapse Issues
**Problem:** Detail view disappears when selecting content.
**Solution:** Use `.navigationSplitViewStyle(.balanced)` for sustained detail visibility.

### Pitfall 4: Material Background Vibrancy
**Problem:** Text hard to read on material backgrounds.
**Solution:** Materials include implicit vibrancy; if custom foreground color needed, reduce opacity rather than removing vibrancy.

### Pitfall 5: Menu Bar App Window Elevation
**Problem:** Popover behind other windows.
**Solution:** Always call `NSApp.activate(ignoringOtherApps: true)` when showing popover.

### Pitfall 6: Accessibility Labels Ignored
**Problem:** VoiceOver reads generic labels.
**Solution:** Test with VoiceOver enabled (Cmd+F5), verify each button has unique `.accessibilityLabel`.

---

## Resources & References

### Official Documentation
- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [NavigationSplitView Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Table Documentation](https://developer.apple.com/documentation/swiftui/table)
- [Accessibility for SwiftUI](https://developer.apple.com/accessibility/swiftui/)

### WWDC Sessions
- WWDC 2024: "What's New in SwiftUI" (navigation & layout focus)
- WWDC 2024: "Design for macOS"
- WWDC 2023: "The SwiftUI Layout Protocol"
- WWDC 2023: "Explore App Store Connect for macOS"

### Community Resources
- Swift Forums (swiftlang.org/forums)
- Stack Overflow tags: swiftui, macos-app, swiftui-accessibility
- GitHub: hummingbird-project/hummingbird (reference implementations)

### Recommended Tutorials
- raywenderlich.com - SwiftUI macOS courses
- hackingwithswift.com - Paul Hudson's SwiftUI guides
- objc.io - Advanced SwiftUI patterns

---

## Appendices

### A. Glossary

**NavigationSplitView:** SwiftUI container providing responsive multi-column navigation with automatic collapse on narrow displays.

**NSStatusItem:** AppKit object representing an icon in the macOS menu bar (top-right system tray area).

**NSPopover:** AppKit window that appears relative to a UI element and disappears when clicking outside.

**Material:** SwiftUI visual effect providing translucent background with automatic vibrancy and dark mode adaptation.

**Vibrancy:** macOS visual effect making foreground content (text, icons) stand out against semi-transparent backgrounds.

**matchedGeometryEffect:** SwiftUI modifier animating position/size changes between views with matching identifiers ("hero" transitions).

**Dynamic Type:** macOS/iOS feature allowing users to adjust text size system-wide; apps must support size ranges.

**VoiceOver:** macOS accessibility feature reading screen content aloud for visually impaired users.

**Accessibility Inspector:** Xcode tool displaying accessibility information and warnings for views.

**LSUIElement:** macOS Info.plist key making app invisible in Dock and Cmd+Tab (agent/background mode).

---

## Unresolved Questions

1. **iCloud Sync Integration:** GenSnippets has partial iCloud sync; should this be modernized with SwiftUI's new data persistence patterns (CloudKit integration)? Requires separate research.

2. **Performance Testing:** No benchmarks provided for NavigationSplitView vs. NavigationView in three-column layouts with 1000+ snippets. Should profile actual app.

3. **Global Hotkey in Modern SwiftUI:** Carbon-based GlobalHotkeyManager may conflict with newer AppKit APIs. Verify compatibility.

4. **Browser Text Insertion:** BrowserCompatibleTextInsertion uses timing workarounds. Will modern macOS APIs (Accessibility framework improvements) eliminate need?

5. **Settings Window Tab Navigation:** Can Settings scene support tab-based preferences (General, Advanced, Keyboard) in macOS 14-15? Needs testing.

---

**Report Generated:** 2025-12-04
**Research Period:** 5 comprehensive Gemini queries
**Applicable Platforms:** macOS 13+, Swift 5.5+, SwiftUI 4.0+
