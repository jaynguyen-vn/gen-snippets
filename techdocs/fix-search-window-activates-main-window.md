# Fix: Search Window Activates Main Window When Running in Background

## Issue

When the app is running in background mode (menu bar only), pressing the global hotkey (Cmd+Ctrl+S) to open the snippet search window would cause the main application window to appear unexpectedly.

## Root Cause Analysis

The issue had multiple contributing factors:

### 1. NSApp.activate() Called Unconditionally
In `SnippetSearchWindowController.swift`, the original code called `NSApp.activate(ignoringOtherApps: true)` when showing the search window. This activated the entire application, which could:
- Change activation policy from `.accessory` to `.regular`
- Show the dock icon
- Trigger SwiftUI's WindowGroup to restore/show windows

### 2. NSWindow Instead of NSPanel
The search window was using `NSWindow` which requires app activation to become the key window.

### 3. No Background Mode Tracking
The app had no way to track whether it was running in background mode, making it impossible to conditionally handle window visibility.

### 4. Missing ShowDockIcon Notification Listener
`AppDelegate` was missing a listener for the `ShowDockIcon` notification, causing inconsistent state management.

### 5. Windows Not Properly Closed
When entering background mode, the app only called `NSApplication.shared.hide(nil)` which hides windows but doesn't close them. SwiftUI's WindowGroup could restore these windows on any activation event.

## Solution

### 1. Convert to NSPanel with Non-Activating Style

**File:** `Controllers/SnippetSearchWindowController.swift`

Changed from `NSWindow` to `NSPanel` with appropriate style masks:

```swift
let panel = NSPanel(
    contentViewController: hostingController
)

panel.styleMask = [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow]
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
panel.hidesOnDeactivate = false
panel.becomesKeyOnlyIfNeeded = false
```

Key changes:
- `.nonactivatingPanel`: Allows panel to become key without activating the app
- `.utilityWindow`: Marks as utility window
- `.transient`: Proper floating behavior
- `becomesKeyOnlyIfNeeded = false`: Accept keyboard input without app activation

### 2. Remove NSApp.activate() Calls

Replaced:
```swift
NSApp.activate(ignoringOtherApps: true)
existingWindow.makeKeyAndOrderFront(nil)
```

With:
```swift
existingPanel.orderFrontRegardless()
existingPanel.makeKey()
```

### 3. Add Background Mode Tracking

**File:** `GenSnippetsApp.swift`

Added flag to track background mode:
```swift
private(set) var isRunningInBackground = false
```

### 4. Properly Close Windows When Entering Background Mode

Updated `hideDockIcon()`:
```swift
@objc private func hideDockIcon() {
    isRunningInBackground = true

    // Close all main windows (but not panels like the search window)
    for window in NSApplication.shared.windows {
        if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
            window.close()
        }
    }

    NSApplication.shared.setActivationPolicy(.accessory)
}
```

### 5. Add ShowDockIcon Notification Listener

```swift
let showDockObserver = NotificationCenter.default.addObserver(
    forName: NSNotification.Name("ShowDockIcon"),
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.showDockIcon()
}
notificationObservers.append(showDockObserver)
```

### 6. Prevent Window Restoration

Added `applicationShouldHandleReopen` delegate method:
```swift
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if isRunningInBackground {
        return false
    }
    return true
}
```

### 7. Hide Main Windows When Showing Search Panel

Added safeguard in `showSearchWindow()`:
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

// Called before and after showing panel
hideMainWindowsIfNeeded()
```

## Files Changed

1. `Controllers/SnippetSearchWindowController.swift`
   - Changed NSWindow to NSPanel
   - Added non-activating style masks
   - Removed NSApp.activate() calls
   - Added main window hiding logic

2. `GenSnippetsApp.swift`
   - Added `isRunningInBackground` flag
   - Added ShowDockIcon notification listener
   - Updated `hideDockIcon()` to close windows
   - Added `applicationShouldHandleReopen()` delegate method

## Testing

1. Open the app
2. Press Cmd+Q and choose "Run in Background"
3. Verify app hides to menu bar only (no dock icon)
4. Press Cmd+Ctrl+S (or custom shortcut)
5. Verify ONLY the search panel appears, not the main window
6. Close the search panel
7. Repeat step 4-6 multiple times to ensure consistency

## Related Concepts

- **NSPanel vs NSWindow**: NSPanel is designed for auxiliary windows that don't require full app activation
- **Activation Policy**: `.accessory` hides dock icon and prevents app from appearing in Cmd+Tab
- **nonactivatingPanel**: Style mask that allows panel to receive input without activating the owning app
- **orderFrontRegardless()**: Shows window without requiring app to be active

## Date

2024-12-03
