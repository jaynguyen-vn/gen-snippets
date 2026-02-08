# Window Visibility Investigation Report

**Date:** 2026-02-08
**Issue:** macOS menu bar app runs in background but sometimes cannot be opened/shown
**Workaround:** Force quit and relaunch
**Status:** Root causes identified with recommended fixes

---

## Executive Summary

Identified **5 critical root causes** causing window visibility failures. Primary issue: SwiftUI WindowGroup doesn't guarantee window persistence after `.accessory` mode, combined with race conditions in window restoration logic. App relies on fallback window creation that may fail silently.

**Impact:** Users unable to access app UI when running in background mode; requires force quit.

**Recommended Priority:** P0 - Immediate fix required.

---

## Root Causes & Evidence

### 1. SwiftUI WindowGroup Deallocation After Accessory Mode

**File:** `GenSnippetsApp.swift:223-228`

```swift
@objc private func hideDockIcon() {
    isRunningInBackground = true
    // ... hide windows ...
    NSApplication.shared.setActivationPolicy(.accessory)
}

@objc private func showDockIcon() {
    isRunningInBackground = false
    NSApplication.shared.setActivationPolicy(.regular)
    // Window restoration 150ms later
}
```

**Why this causes the issue:**
- SwiftUI `WindowGroup` windows may be **deallocated** when activation policy changes to `.accessory`
- No explicit window retention mechanism exists
- `weak var mainWindow` (line 59) becomes `nil` after deallocation
- Window restoration at line 231-250 searches for already-gone windows

**Evidence:** Comment at line 245: "If no window found (may have been deallocated after long background)"

**Fix approach:**
- Use explicit `NSWindow` creation instead of SwiftUI WindowGroup
- OR retain window reference strongly during background mode
- OR use `.handlesKeyEquivalents = true` on window to prevent deallocation

---

### 2. Race Condition in Window Search Logic

**File:** `GenSnippetsApp.swift:234-243`

```swift
for window in NSApplication.shared.windows {
    if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self?.mainWindow = window
        foundWindow = true
        NSLog("GenSnippets: Main window restored successfully")
        break
    }
}
```

**Why this causes the issue:**
- Window search uses **className check** which is fragile
- Multiple window types can exist (settings sheets, export dialogs, etc.)
- May grab wrong window type or invisible window
- No validation that found window is actually the main ContentView window

**Fix approach:**
- Tag main window with unique identifier using `window.identifier = NSUserInterfaceItemIdentifier("MainWindow")`
- Search by identifier instead of className
- Validate window has valid contentViewController

---

### 3. Fallback Window Creation May Fail Silently

**File:** `GenSnippetsApp.swift:254-276`

```swift
private func createAndShowMainWindow() {
    if NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil) {
        NSLog("GenSnippets: Triggered new window via sendAction")
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        for window in NSApplication.shared.windows {
            // Same fragile search logic
        }
        // Fallback: Create window manually
        self?.createWindowManually()
    }
}
```

**Why this causes the issue:**
- `sendAction(Selector(("newWindowForTab:")))` is **private API** - may fail silently on different macOS versions
- 300ms delay arbitrary - SwiftUI may need more time on slow systems
- If both sendAction fails AND manual creation fails, user sees nothing
- No error reporting or retry mechanism

**Fix approach:**
- Skip unreliable sendAction, go directly to manual creation
- Add timeout and retry logic
- Show user-facing error if all attempts fail

---

### 4. MenuBarView Window Activation Logic Bug

**File:** `MenuBarView.swift:35-37`

```swift
if let window = NSApplication.shared.windows.first {
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

**Why this causes the issue:**
- Assumes `windows.first` is main window - **WRONG**
- Could be search panel, settings sheet, or status bar window
- No validation of window type
- Called 100ms after showing dock icon - may execute before window restoration completes at 150ms

**Fix approach:**
- Use same window identifier approach as fix #2
- Coordinate with showDockIcon() timing
- OR just call showDockIcon() notification directly

---

### 5. applicationShouldHandleReopen Inconsistent Behavior

**File:** `GenSnippetsApp.swift:434-441`

```swift
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if isRunningInBackground {
        showDockIcon()
        return false // We handle it ourselves
    }
    return true
}
```

**Why this causes the issue:**
- When `flag=true` but window is actually invisible (off-screen, minimized), returns `true` and does nothing
- When in background mode, calls showDockIcon() but returns `false`, preventing default window restoration
- If showDockIcon() fails, user has no window and no fallback
- Doesn't check actual window visibility, only relies on `flag` parameter

**Fix approach:**
- Always check actual window visibility state, not just `flag`
- Implement forced window restoration regardless of flag when needed
- Add logging to track reopen attempts

---

## Additional Contributing Factors

### 6. No Window State Persistence
- No tracking of window minimized/hidden state
- No restoration of window position after background mode
- Users may think app "didn't open" if window appears off-screen

### 7. Timing Dependencies Throughout Codebase
- Multiple async delays (100ms, 150ms, 300ms) create race conditions
- No coordination between different window restoration paths
- May fail on slower Macs or under heavy load

### 8. Lack of Window Lifecycle Logging
- Missing logs for critical window state changes
- Hard to diagnose user reports without instrumentation
- Only 3 NSLog statements in entire window management flow

---

## Recommended Solutions (Prioritized)

### Immediate Fix (P0)
**Replace SwiftUI WindowGroup with NSWindow-based architecture:**

1. Remove WindowGroup from GenSnippetsApp.swift body
2. Create persistent NSWindow in AppDelegate.init()
3. Store window in strong property (not weak)
4. Handle window hide/show explicitly instead of relying on activation policy

**Pseudo-code:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow! // Strong reference

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = createMainWindow()
        // ... rest of setup
    }

    private func createMainWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: ContentView()))
        window.identifier = NSUserInterfaceItemIdentifier("MainWindow")
        window.center()
        return window
    }

    @objc private func showDockIcon() {
        NSApplication.shared.setActivationPolicy(.regular)
        mainWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
```

### Short-term Fix (P1)
**Add window identifier and validation:**

1. Tag main window on first appearance
2. Update all window search logic to use identifier
3. Validate window is visible before claiming success

### Medium-term Improvements (P2)
1. Add comprehensive logging for window lifecycle
2. Implement window state persistence (position, minimized state)
3. Add user-facing error alerts when window restoration fails
4. Remove timing dependencies via proper coordination

---

## Testing Recommendations

**Reproduction scenarios:**
1. Run app → Hide dock icon → Wait 30+ minutes → Try to open from menu bar
2. Run app → Hide dock icon → Open multiple apps → Try to open from menu bar
3. Run app in background → Connect/disconnect external display → Try to open
4. Run app → Sleep Mac → Wake → Try to open from menu bar

**Success criteria:**
- Window appears within 500ms of click
- Window is visible and interactive
- Works after prolonged background operation (1+ hour)
- Works across display configuration changes

---

## Performance Impact

**Current bottlenecks:**
- Multiple async delays total 550ms minimum for window restoration
- Fragile fallback chain may retry multiple times
- No window pooling/reuse strategy

**Recommended optimizations:**
- Reduce window restoration to <100ms
- Eliminate async delays via direct window management
- Pre-create window during launch instead of lazy creation

---

## Security Considerations

- Private API usage (`newWindowForTab:`) may be rejected in App Store review
- Accessibility permission checks are properly implemented
- No security issues identified in window management flow

---

## Unresolved Questions

1. What is exact macOS version distribution of affected users? (May affect SwiftUI WindowGroup behavior)
2. Does issue occur more frequently on external displays or multi-monitor setups?
3. Are there any Console.app error messages when window fails to appear?
4. Does issue correlate with specific macOS versions (11.x vs 12.x vs 13.x)?
5. Can issue be reproduced with minimal test app using same architecture?
