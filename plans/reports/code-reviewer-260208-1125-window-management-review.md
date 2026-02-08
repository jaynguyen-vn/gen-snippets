# Code Review: Window Management -- Remaining Issues

## Scope
- **Files**: GenSnippetsApp.swift, MenuBarView.swift, ContentView.swift, SnippetSearchWindowController.swift, GlobalHotkeyManager.swift, ThreeColumnView.swift, ModernSnippetSearchView.swift, SnippetSearchView.swift, MetafieldService.swift
- **LOC**: ~1,700 across reviewed files
- **Focus**: All code paths that create, show, hide, close, or restore windows

## Overall Assessment
The primary fix (strong `mainWindow` reference + identifier-based lookup) is solid and addresses the root cause. However, several remaining issues could still cause "app can't open" or related failures under specific edge-case scenarios.

---

## Critical Issues (P0/P1)

### ISSUE 1: `NSApp.keyWindow?.close()` Can Destroy the Main Window (P1)
**File**: `GenSnippets/Views/ModernSnippetSearchView.swift:47`, `GenSnippets/Views/SnippetSearchView.swift:55,200`

```swift
NSApp.keyWindow?.close()
```

**Failure scenario**:
1. User opens search panel (NSPanel) via hotkey
2. User clicks on the main window while search panel is still visible -- main window becomes key
3. User selects a snippet in search panel, which calls `NSApp.keyWindow?.close()`
4. This closes the **main window**, not the search panel
5. `close()` deallocates the window (unlike `orderOut`), destroying the SwiftUI view hierarchy
6. `mainWindow` in AppDelegate still holds a reference to a closed/zombie window
7. Next attempt to show the app calls `makeKeyAndOrderFront` on a closed window -- nothing visible happens

**Why `mainWindow` reference doesn't save you**: The strong reference prevents deallocation of the NSWindow object, but a closed NSWindow cannot be re-shown with `makeKeyAndOrderFront`. The window's content view gets torn down on close. The `captureMainWindow` validity check (`existing.contentView != nil`) would catch this, but `showDockIcon` doesn't call `captureMainWindow` first -- it goes straight to `self.mainWindow` and calls `makeKeyAndOrderFront` on it.

**Severity**: P1 -- app becomes unopenable until restart

**Fix**: In `ModernSnippetSearchView` and `SnippetSearchView`, replace `NSApp.keyWindow?.close()` with explicit panel targeting:
```swift
// Instead of NSApp.keyWindow?.close()
if let panel = NSApp.keyWindow as? NSPanel {
    panel.close()
}
```
Or use `SnippetSearchWindowController.shared?.window?.close()` directly.

---

### ISSUE 2: `applicationWillTerminate` Posts Quit Dialog After Termination Begins (P1)
**File**: `GenSnippets/GenSnippetsApp.swift:482-489`

```swift
func applicationWillTerminate(_ notification: Notification) {
    LocalStorageService.shared.forceSave()
    if !shouldTerminate {
        NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
    }
}
```

**Failure scenario**:
1. macOS initiates termination (system shutdown, force quit from Activity Monitor)
2. `applicationShouldTerminate` returns `.terminateCancel`, halting termination
3. `applicationWillTerminate` is **also** called (it shouldn't be when cancel is returned, but the ordering of `shouldTerminate` and `applicationShouldTerminate` suggests defensive coding was intended)
4. If a code path somehow sets `shouldTerminate=false` after a cancelled quit, the quit dialog tries to show on a potentially-hidden window
5. The `ShowQuitDialog` notification sets `isQuitting=true` in ContentView, which presents a sheet -- but if the window is already being torn down or hidden, the sheet has no window to attach to

The real problem: `applicationShouldTerminate` and `applicationWillTerminate` both try to show the quit dialog. If macOS calls `applicationWillTerminate` (e.g., during logout sequence where cancel is ignored), posting a UI notification is futile and can leave state inconsistent.

**Severity**: P1 -- can prevent clean quit, leaving app in limbo state

**Fix**: Remove the quit dialog logic from `applicationWillTerminate`. It should only save data:
```swift
func applicationWillTerminate(_ notification: Notification) {
    LocalStorageService.shared.forceSave()
}
```

---

### ISSUE 3: ContentView Quit Dialog Sheet Blocks Window Restoration (P1)
**File**: `GenSnippets/Views/ContentView.swift:50-58`

```swift
.onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
    if !isQuitting {
        isQuitting = true
    }
}
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowQuitDialog"))) { _ in
    isQuitting = true
}
```

**Failure scenario**:
1. User presses Cmd+Q while app is in foreground
2. `applicationShouldTerminate` is called, returns `.terminateCancel`, posts `ShowQuitDialog`
3. `isQuitting = true`, sheet appears
4. User clicks "Run in Background" -- `hideDockIcon()` is called
5. App enters background mode with window ordered out
6. Later, user clicks dock icon or Spotlight to reopen
7. `showDockIcon` calls `mainWindow.makeKeyAndOrderFront(nil)`
8. Window reappears **but the quit sheet may still be attached** (`isQuitting` might still be `true` if the notification fired again)
9. Additionally, `willTerminateNotification` listener sets `isQuitting = true` unconditionally -- any spurious terminate notification leaves the dialog stuck open

The `willTerminateNotification` observer is especially dangerous: this macOS notification fires when the app IS terminating, at which point showing a sheet is meaningless and can block the window from appearing correctly on restore.

**Severity**: P1 -- quit dialog can appear unexpectedly on window restore

**Fix**:
- Remove the `willTerminateNotification` observer from ContentView (the quit dialog is already handled via `ShowQuitDialog`)
- In the "Run in Background" handler, ensure `isQuitting` is set to `false` BEFORE posting `HideDockIcon`

---

### ISSUE 4: `hideDockIcon` Calls `NSApp.hide` Before `setActivationPolicy(.accessory)` (P1)
**File**: `GenSnippets/Views/ContentView.swift:20-23`

```swift
Button("Run in Background".localized) {
    NSApplication.shared.hide(nil)
    NotificationCenter.default.post(name: NSNotification.Name("HideDockIcon"), object: nil)
    isQuitting = false
}
```

Combined with `GenSnippets/GenSnippetsApp.swift:221-236`:
```swift
@objc private func hideDockIcon() {
    isRunningInBackground = true
    captureMainWindow()
    for window in NSApplication.shared.windows {
        if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
            window.orderOut(nil)
        }
    }
    NSApplication.shared.setActivationPolicy(.accessory)
}
```

**Failure scenario**:
1. User clicks "Run in Background"
2. `NSApplication.shared.hide(nil)` is called -- this hides the app AND triggers macOS to mark windows as "hidden by app"
3. Then `hideDockIcon` calls `window.orderOut(nil)` and `setActivationPolicy(.accessory)`
4. When restoring via `showDockIcon`, `makeKeyAndOrderFront` may not work because the window has both "hidden by app" AND "ordered out" states
5. macOS may require `unhide` or `activate` before `makeKeyAndOrderFront` works on a hidden-by-app window

**Severity**: P1 -- potential "app can't open" on some macOS versions

**Fix**: Remove the `NSApplication.shared.hide(nil)` call from ContentView's "Run in Background" button. The `hideDockIcon` method already handles window hiding via `orderOut`. The `hide` call is redundant and introduces conflicting window state.

---

## High Priority (P2)

### ISSUE 5: Race Condition Between `setActivationPolicy` and Window Operations
**File**: `GenSnippets/GenSnippetsApp.swift:238-266`

```swift
@objc private func showDockIcon() {
    isRunningInBackground = false
    NSApplication.shared.setActivationPolicy(.regular)  // Line 240

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in  // Line 242
        ...
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
```

The 0.15s delay is a best-effort workaround. `setActivationPolicy(.regular)` is asynchronous internally -- macOS needs time to register the app in the Dock, update window server state, etc. On a slow or heavily loaded system, 0.15s may not be enough. On a fast system, it's wasted latency.

**Severity**: P2 -- intermittently fails on slow machines

**Fix**: Instead of a fixed delay, observe `NSApplication.didBecomeActiveNotification` or use a retry loop with backoff. Or increase the delay to 0.3s as a pragmatic fix.

---

### ISSUE 6: `captureMainWindow` Called After 0.5s Delay -- Window May Not Exist Yet
**File**: `GenSnippets/GenSnippetsApp.swift:103-105`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
    self?.captureMainWindow()
}
```

**Failure scenario**:
1. App launches
2. SwiftUI's `WindowGroup` creates the main window, but on a slow machine (or during system login where many apps launch) the window creation takes > 0.5s
3. `captureMainWindow` fires, finds no window, does nothing
4. `mainWindow` remains `nil`
5. User immediately hides to background -- `captureMainWindow` inside `hideDockIcon` may also fail if window hasn't appeared yet

**Severity**: P2 -- rare on fast hardware but possible on login-at-startup

**Fix**: Add a fallback in `applicationDidBecomeActive` to capture the window if it hasn't been captured yet:
```swift
func applicationDidBecomeActive(_ notification: Notification) {
    if mainWindow == nil { captureMainWindow() }
    // ... existing code
}
```

---

### ISSUE 7: `AppDelegate.shared` Singleton Is Never Used But Creates Confusion
**File**: `GenSnippets/GenSnippetsApp.swift:48`

```swift
static let shared = AppDelegate()
```

`AppDelegate` is instantiated by SwiftUI via `@NSApplicationDelegateAdaptor`. The `static let shared = AppDelegate()` creates a SECOND AppDelegate instance. Nobody calls `AppDelegate.shared`, so it's inert -- but if any future code uses it, operations would happen on the wrong instance (one that never received `applicationDidFinishLaunching`).

Meanwhile, `SnippetSearchWindowController` accesses the app delegate correctly via `NSApp.delegate as? AppDelegate`.

**Severity**: P2 -- latent bug, no current impact

**Fix**: Remove `static let shared = AppDelegate()`.

---

### ISSUE 8: `createAndShowMainWindow` Creates Disconnected Window
**File**: `GenSnippets/GenSnippetsApp.swift:301-319`

```swift
private func createAndShowMainWindow() {
    let contentView = ContentView()
    let hostingController = NSHostingController(rootView: contentView)
    let window = NSWindow(...)
    window.contentViewController = hostingController
    ...
}
```

**Failure scenario**: When this fallback fires, it creates a standalone `ContentView` that is NOT part of SwiftUI's `WindowGroup` lifecycle. This means:
- `@StateObject` view models in ContentView/ThreeColumnView are fresh instances, not the ones that loaded data
- The window won't be managed by SwiftUI's window management
- Opening a second time might create another window (WindowGroup may also try to create one)
- Environment objects from the `WindowGroup` hierarchy are missing

This is the "last resort" path, but if Issues 1/3/4 above trigger, users WILL hit this.

**Severity**: P2 -- functional degradation (data may not load, duplicate windows possible)

**Fix**: Before creating a new window, check if calling `NSApp.activate(ignoringOtherApps: true)` alone triggers SwiftUI to recreate the WindowGroup window. If not, consider storing the original window's content view controller and reattaching it.

---

## Medium Priority

### ISSUE 9: Search Window `close()` Nullifies Shared Instance -- Next Hotkey Press Creates New Window
**File**: `GenSnippets/Controllers/SnippetSearchWindowController.swift:131-139`

```swift
func windowWillClose(_ notification: Notification) {
    if SnippetSearchWindowController.shared === self {
        SnippetSearchWindowController.shared = nil
    }
    self.window?.delegate = nil
}
```

This is not a bug per se, but `close()` destroys the panel entirely. Every time the user closes the search (Escape key calls `window.close()`) and reopens (hotkey), a brand new `NSPanel` + `NSHostingController` + SwiftUI view hierarchy is created and destroyed. This is:
- Wasteful (allocation + layout on every open)
- Could accumulate if close/open happens rapidly

**Severity**: P3 -- performance/resource waste, not a "can't open" issue

**Fix**: Use `orderOut` instead of `close()` in the search views to hide the panel without destroying it. Keep the shared instance alive.

---

### ISSUE 10: `MetafieldService` Calls `NSApp.activate` During Background Mode
**File**: `GenSnippets/Services/MetafieldService.swift:349`

```swift
NSApp.activate(ignoringOtherApps: true)
panel.makeKeyAndOrderFront(nil)
```

**Failure scenario**: If `MetafieldService` shows its input panel while the app is in background mode (`.accessory`), calling `NSApp.activate` will bring the app to foreground, potentially showing the main window and changing user expectations.

**Severity**: P3 -- visual glitch, main window may flash briefly

---

### ISSUE 11: No Guard Against Duplicate `ShowQuitDialog` Notifications
**File**: `GenSnippets/Views/ContentView.swift:56-58`

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowQuitDialog"))) { _ in
    isQuitting = true
}
```

Multiple sources can fire `ShowQuitDialog` simultaneously:
- `applicationShouldTerminate`
- `applicationWillTerminate`
- `handleDockQuit`
- Cmd+Q local event monitor
- Dock menu item

If `isQuitting` is already `true` (sheet showing), SwiftUI handles this gracefully (no-op). But the `applicationShouldTerminate` + `applicationWillTerminate` double-fire means two notifications arrive in quick succession, and the quit dialog's "Quit" button posts `ConfirmedQuit` which triggers `NSApp.terminate(nil)`, which calls `applicationShouldTerminate` AGAIN. This recursive loop is broken by `shouldTerminate` flag, but it's fragile.

**Severity**: P3 -- works today but fragile

---

## Positive Observations

1. **Strong mainWindow reference** -- Correctly prevents SwiftUI from deallocating the window during `.accessory` mode
2. **Identifier-based window lookup** -- Good fallback strategy with `findMainWindow()`
3. **Three-tier window restoration** (retained -> identifier -> create new) -- Defense in depth
4. **Proper `weak self` usage** throughout notification observers and async blocks
5. **Observer cleanup in `deinit`** -- Prevents retain cycles
6. **`applicationShouldTerminateAfterLastWindowClosed` returns false** -- Correct for menu bar app
7. **Search panel uses `nonactivatingPanel`** -- Correctly avoids activating main app when searching

---

## Recommended Actions (Priority Order)

1. **[P1] Fix `NSApp.keyWindow?.close()` in search views** -- Replace with explicit panel-targeted close to prevent accidental main window destruction (Issue 1)
2. **[P1] Remove `willTerminateNotification` observer from ContentView** -- It conflicts with the quit dialog flow (Issue 3)
3. **[P1] Remove `NSApplication.shared.hide(nil)` from "Run in Background" button** -- Conflicting window state with `orderOut` (Issue 4)
4. **[P1] Strip quit dialog logic from `applicationWillTerminate`** -- Only save data there (Issue 2)
5. **[P2] Add mainWindow nil-check in `applicationDidBecomeActive`** -- Fallback capture (Issue 6)
6. **[P2] Remove `static let shared = AppDelegate()`** -- Prevent future confusion (Issue 7)
7. **[P2] Increase activation policy delay or add retry** -- Harden for slow systems (Issue 5)
8. **[P3] Use `orderOut` instead of `close()` for search panel** -- Reuse instead of recreate (Issue 9)

---

## Unresolved Questions

1. Has `createAndShowMainWindow` (Issue 8) ever been hit in production? If so, how does it behave with SwiftUI's WindowGroup?
2. Does `MetafieldService.promptForMetafields` get called while in background mode? If yes, Issue 10 needs elevation to P2.
3. On macOS 15 (Sequoia), has the `setActivationPolicy` timing changed? The 0.15s delay may need adjustment.
