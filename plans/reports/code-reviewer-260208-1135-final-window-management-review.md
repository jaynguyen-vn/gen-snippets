# Final Window Management Review

**Reviewer:** code-reviewer
**Date:** 2026-02-08
**Scope:** Adversarial second-pass review of all window management code paths
**Focus:** "App runs in background but can't be opened" failure mode

## Files Reviewed

- `/GenSnippets/GenSnippetsApp.swift` (550 lines) -- AppDelegate, lifecycle, show/hide
- `/GenSnippets/Views/ContentView.swift` (59 lines) -- quit dialog
- `/GenSnippets/Views/MenuBarView.swift` (192 lines) -- "Open App" button
- `/GenSnippets/Controllers/SnippetSearchWindowController.swift` (140 lines) -- search panel
- `/GenSnippets/Views/ModernSnippetSearchView.swift` (614 lines) -- modern search close
- `/GenSnippets/Views/SnippetSearchView.swift` (337 lines) -- legacy search close
- `/GenSnippets/Services/GlobalHotkeyManager.swift` (159 lines) -- hotkey triggers
- `/GenSnippets/Services/MetafieldService.swift` (relevant panel code)

## Previously Fixed Issues (Confirmed Fixed)

All 8 issues from first review confirmed resolved. Not re-reported.

---

## NEW Issues Found

### Issue 1: Escape key in both search views uses `NSApp.keyWindow` -- can close main window

**P1 -- High**

**File:** `ModernSnippetSearchView.swift:589-593`
```swift
} else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
    if let window = NSApp.keyWindow {
        window.close()
        SnippetSearchWindowController.returnToPreviousApp()
    }
    return true
```

**File:** `SnippetSearchView.swift:247-248` (via `getWindow()`)
```swift
func getWindow() -> NSWindow? {
    return NSApp.keyWindow
}
```
Used at line 320-322:
```swift
if let window = parent.getWindow() {
    window.close()
    SnippetSearchWindowController.returnToPreviousApp()
}
```

**Failure scenario:**
1. User opens search panel (NSPanel, floating, nonactivatingPanel)
2. User clicks on the main window (it becomes keyWindow)
3. User presses Escape while focus returns to the search text field
4. `NSApp.keyWindow` returns the *main window* (not the panel)
5. `window.close()` closes the main window
6. Main window is gone; app effectively becomes unopenable if it then goes to background

**Note:** The `nonactivatingPanel` style means the panel tries not to become keyWindow of the app. When the main window *is* visible and the user clicks it, `NSApp.keyWindow` will be the main window, not the panel. This Escape handler will then close the wrong window.

**In practice:** This is somewhat mitigated because the search text field typically grabs first-responder status in the panel. But the race condition is real: if a user clicks the main window and then quickly presses Escape, `NSApp.keyWindow` returns the main window.

**Fix:** Replace `NSApp.keyWindow` with direct panel reference:
```swift
// ModernSnippetSearchView
if let panel = SnippetSearchWindowController.shared?.window {
    panel.close()
    SnippetSearchWindowController.returnToPreviousApp()
}

// SnippetSearchView -- same pattern
func getWindow() -> NSWindow? {
    return SnippetSearchWindowController.shared?.window
}
```

---

### Issue 2: `createAndShowMainWindow` does not check if old `mainWindow` is still alive but hidden

**P2 -- Medium**

**File:** `GenSnippetsApp.swift:299-317`
```swift
private func createAndShowMainWindow() {
    let contentView = ContentView()
    let hostingController = NSHostingController(rootView: contentView)
    let window = NSWindow(...)
    ...
    mainWindow = window
}
```

**Failure scenario:**
1. App enters background mode. `hideDockIcon()` calls `orderOut(nil)` on all non-panel windows. `mainWindow` is retained.
2. An edge case causes the 0.15s delayed `showDockIcon` closure to see `self.mainWindow == nil` (unlikely but possible if a Swift runtime optimization releases and re-creates the AppDelegate adaptor).
3. `createAndShowMainWindow()` creates a new NSWindow and sets `mainWindow = window`.
4. The old window (still retained elsewhere, e.g., by SwiftUI's WindowGroup internal tracking) is now orphaned.
5. SwiftUI WindowGroup may still reference the old window, causing two separate window hierarchies with separate ContentView state.

**Mitigating factor:** The strong `mainWindow` reference makes step 2 unlikely. However, the function itself has no guard against double creation. If called twice in rapid succession (e.g., dock click + "Open App" button in quick succession), two windows are created.

**Fix:** Add a guard at the top of `createAndShowMainWindow`:
```swift
private func createAndShowMainWindow() {
    // Prevent double creation
    if let existing = mainWindow, existing.contentView != nil {
        existing.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return
    }
    // ... existing creation code
}
```

---

### Issue 3: No guard against concurrent `ShowDockIcon`/`HideDockIcon` notifications

**P2 -- Medium**

**File:** `GenSnippetsApp.swift:219-263`

**Failure scenario:**
1. User clicks "Run in Background" (posts `HideDockIcon`).
2. `hideDockIcon()` sets `isRunningInBackground = true`, calls `orderOut(nil)` on all windows, then `setActivationPolicy(.accessory)`.
3. Before the 0.5s window capture delay from `applicationDidFinishLaunching` completes, user immediately clicks "Open App" from menu bar popover (posts `ShowDockIcon`).
4. `showDockIcon()` sets `isRunningInBackground = false` and `setActivationPolicy(.regular)`.
5. Then 0.15s later, the delayed block in `showDockIcon` tries to show `mainWindow`.
6. But now the delayed `hideMainWindowsIfNeeded` from `showSearchWindow` (if search was also triggered) could also fire, calling `orderOut` again.
7. Net result: window may be ordered out after being ordered front.

**This is a timing-sensitive race.** Both methods are called on main queue via NotificationCenter (`.queue: .main`), so they are serialized. However, the `DispatchQueue.main.asyncAfter(deadline: .now() + 0.15)` in `showDockIcon` means the actual window restoration is deferred, and a `HideDockIcon` notification arriving during that 0.15s gap would cause `hideDockIcon` to execute before the restoration block.

**Fix:** Add a monotonically increasing "session counter" that the delayed block checks:
```swift
private var showDockSession: Int = 0

@objc private func showDockIcon() {
    isRunningInBackground = false
    NSApplication.shared.setActivationPolicy(.regular)
    let session = showDockSession

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        guard let self = self, self.showDockSession == session, !self.isRunningInBackground else { return }
        // ... restore window
    }
}

@objc private func hideDockIcon() {
    showDockSession += 1  // Invalidate any pending show
    isRunningInBackground = true
    // ...
}
```

---

### Issue 4: `MetafieldService.showInputDialog` calls `NSApp.activate(ignoringOtherApps: true)` which can surface hidden main window

**P2 -- Medium**

**File:** `MetafieldService.swift:349`
```swift
NSApp.activate(ignoringOtherApps: true)
panel.makeKeyAndOrderFront(nil)
```

**Failure scenario:**
1. App is in background mode (`.accessory` policy).
2. User triggers a snippet with metafields (e.g., via keyboard expansion). TextReplacementService detects the match and calls MetafieldService.
3. `MetafieldService.showInputDialog` calls `NSApp.activate(ignoringOtherApps: true)`.
4. This activates the app, which may temporarily make it `.regular` and cause hidden windows to become visible (depending on macOS version behavior).
5. The metafield panel appears, but the main window might also flash or appear.

**In practice:** Since the activation policy is `.accessory`, `NSApp.activate` should not change it. But on some macOS versions, activating an accessory app can show its windows. The metafield panel is an NSPanel so it should work independently, but the `activate` call is risky.

**Fix:** Remove `NSApp.activate(ignoringOtherApps: true)` from MetafieldService and rely solely on `panel.makeKeyAndOrderFront(nil)` with `panel.level = .floating`. Or guard it:
```swift
if !(NSApp.delegate as? AppDelegate)?.isRunningInBackground ?? false {
    NSApp.activate(ignoringOtherApps: true)
}
panel.makeKeyAndOrderFront(nil)
```

---

### Issue 5: Sheet state (`isQuitting`) persists across background transitions

**P2 -- Medium**

**File:** `ContentView.swift:10, 49-51`
```swift
@State private var isQuitting = false
// ...
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowQuitDialog"))) { _ in
    isQuitting = true
}
```

**Failure scenario:**
1. User presses Cmd+Q. `isQuitting = true`, sheet appears.
2. While sheet is displayed, user clicks away (or another app activates).
3. The `ShowQuitDialog` notification was already received and `isQuitting` is true.
4. `hideDockIcon` fires (e.g., another code path triggers it), window is ordered out.
5. Later, `showDockIcon` restores the window. The sheet is still presented over it.
6. User sees a quit dialog immediately upon restoring the window, which is confusing.

**More critically:** If the user chose "Run in Background" but the sheet's `isQuitting` was not set to false before the window was ordered out, the sheet state leaks into the next session.

**Mitigating factor:** The "Run in Background" button does set `isQuitting = false` before posting `HideDockIcon`. But if `hideDockIcon` is triggered by another path (e.g., programmatically), the sheet stays.

**Fix:** Reset `isQuitting` in a `onDisappear` or listen for `HideDockIcon`:
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideDockIcon"))) { _ in
    isQuitting = false
}
```

---

### Issue 6: `SnippetSearchWindowController.showSearchWindow` hides main windows on every call when in background, but `hideMainWindowsIfNeeded` fires twice with 0.1s delay

**P1 -- High (in background mode)**

**File:** `SnippetSearchWindowController.swift:80-101`
```swift
let hideMainWindowsIfNeeded = {
    if isInBackground {
        for window in NSApplication.shared.windows {
            if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                window.orderOut(nil)
            }
        }
    }
}

// Hide any main windows that might have appeared
hideMainWindowsIfNeeded()
// ...
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    hideMainWindowsIfNeeded()
    // ...
}
```

**Failure scenario:**
1. App is in background. User triggers hotkey to open search.
2. `showSearchWindow` is called. It captures `isInBackground` as `true` at line 77.
3. `hideMainWindowsIfNeeded` is called immediately and again after 0.1s.
4. But between these two calls, suppose the user also clicks "Open App" in the menu bar popover (which posts `ShowDockIcon`).
5. `showDockIcon` sets `isRunningInBackground = false` and starts the 0.15s delayed restore.
6. At 0.1s, the `hideMainWindowsIfNeeded` closure fires. But it captured `isInBackground` as a *let constant* (value `true`) at line 77, not re-reading the property.
7. It hides all non-panel windows again, even though `isRunningInBackground` is now `false`.
8. At 0.15s, `showDockIcon`'s delayed block restores the window. This works, but there's a brief flash of the window disappearing and reappearing.

**This is a stale-capture bug.** The `isInBackground` local variable captures the value at call time, not at execution time of the delayed block.

**Fix:** Re-read the property inside the delayed block:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    if let currentDelegate = NSApp.delegate as? AppDelegate, currentDelegate.isRunningInBackground {
        for window in NSApplication.shared.windows {
            if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                window.orderOut(nil)
            }
        }
    }
    // ... focus code
}
```

---

## Edge Cases Analyzed (No Issues Found)

### Rapid dock click
- `applicationShouldHandleReopen` is called synchronously on the main thread. Even if called rapidly, each invocation checks `isRunningInBackground` and `mainWindow` state. The 0.15s delay in `showDockIcon` could theoretically overlap, but the guard `guard let self = self else { return }` and the state checks prevent double-show. **Low risk.**

### Spotlight open while in background
- Spotlight → app reopen calls `applicationShouldHandleReopen`. If `isRunningInBackground`, it calls `showDockIcon`. This works correctly. **No issue.**

### Popover interactions with window restoration
- Popover uses `.transient` behavior and `performClose`. It does not interact with the main window. `ClosePopover` notification only calls `popover?.performClose(nil)`. **No issue.**

### Strong reference cycle analysis
- `AppDelegate` holds `mainWindow: NSWindow?`. The window holds a `contentViewController` (NSHostingController) which holds `ContentView`. ContentView does not reference AppDelegate. **No cycle.**
- `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate` in the App struct holds a strong reference to AppDelegate. This is expected and required. **No cycle.**

### Window ordering issues
- `makeKeyAndOrderFront` is used consistently. `activate(ignoringOtherApps: true)` ensures the window comes to front. **No issue.**

---

## Summary

| # | Issue | Priority | Risk |
|---|-------|----------|------|
| 1 | Escape key `NSApp.keyWindow` can close main window | P1 | Main window closed unexpectedly |
| 2 | `createAndShowMainWindow` no double-creation guard | P2 | Duplicate windows, state desync |
| 3 | No concurrent Show/Hide notification guard | P2 | Window restoration cancelled by stale hide |
| 4 | MetafieldService `activate` can surface hidden windows | P2 | Main window flash in background mode |
| 5 | Sheet state persists across background transitions | P2 | Confusing UX on restore |
| 6 | Stale `isInBackground` capture in search controller | P1 | Hides windows after user explicitly restored |

### Overall Assessment

The previous review's fixes are solid. The remaining issues are mostly timing-related edge cases and one genuine bug (Issue 1 -- Escape closing wrong window via `NSApp.keyWindow`). Issues 1 and 6 are the most likely to cause user-facing problems. Issues 2-5 require specific timing to trigger but represent real code quality gaps.

### Recommended Fix Order
1. **Issue 1** -- Replace `NSApp.keyWindow` in both search views (quick, high impact)
2. **Issue 6** -- Fix stale capture in search controller delayed block
3. **Issue 3** -- Add session counter to show/hide transitions
4. **Issue 2** -- Add double-creation guard
5. **Issue 5** -- Reset sheet state on hide
6. **Issue 4** -- Guard MetafieldService activate call
