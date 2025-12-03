import AppKit
import SwiftUI

extension NSView {
    func firstResponder<T: NSView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }
        for subview in subviews {
            if let found = subview.firstResponder(ofType: type) {
                return found
            }
        }
        return nil
    }
}

class SnippetSearchWindowController: NSWindowController, NSWindowDelegate {
    static var shared: SnippetSearchWindowController?
    private static var previousApp: NSRunningApplication?

    convenience init() {
        let hostingController: NSViewController
        if #available(macOS 12.0, *) {
            hostingController = NSHostingController(rootView: ModernSnippetSearchView())
        } else {
            // Fallback for macOS 11
            hostingController = NSHostingController(rootView: Text("Snippet Search requires macOS 12.0 or later"))
        }

        // Use NSPanel with nonactivatingPanel to avoid activating the app
        // This allows the search window to appear without showing the main window
        let panel = NSPanel(
            contentViewController: hostingController
        )

        panel.title = "Snippet Search"
        panel.titlebarAppearsTransparent = false
        // nonactivatingPanel allows the panel to become key without activating the app
        panel.styleMask = [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow]
        panel.setContentSize(NSSize(width: 860, height: 580))
        panel.minSize = NSSize(width: 800, height: 500)

        self.init(window: panel)

        // Set window delegate
        panel.delegate = self

        // Center the window on screen
        panel.center()

        // Set window level to floating and make it appear above all apps
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false

        // Allow the panel to become key window even when app is not active
        panel.becomesKeyOnlyIfNeeded = false

        // Store the shared instance (only if not already set)
        if SnippetSearchWindowController.shared == nil {
            SnippetSearchWindowController.shared = self
        }
    }
    
    static func showSearchWindow() {
        // Save the currently active app before showing our panel
        previousApp = NSWorkspace.shared.frontmostApplication

        // Clean up any orphaned shared instance if its window is gone
        if let existingShared = shared, existingShared.window == nil {
            shared = nil
        }

        // Check if in background mode and hide any main windows that might appear
        let appDelegate = NSApp.delegate as? AppDelegate
        let isInBackground = appDelegate?.isRunningInBackground ?? false

        // Helper to hide non-panel windows when in background mode
        let hideMainWindowsIfNeeded = {
            if isInBackground {
                for window in NSApplication.shared.windows {
                    // Skip NSPanel windows and status bar windows
                    if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                        window.orderOut(nil)
                    }
                }
            }
        }

        // Hide any main windows that might have appeared
        hideMainWindowsIfNeeded()

        if let existingPanel = shared?.window as? NSPanel {
            // If panel already exists, bring it to front without activating the app
            existingPanel.orderFrontRegardless()
            existingPanel.makeKey()

            // Force focus to the text field and ensure main windows stay hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hideMainWindowsIfNeeded()
                if let contentView = existingPanel.contentView,
                   let textField = contentView.firstResponder(ofType: NSTextField.self) {
                    existingPanel.makeFirstResponder(textField)
                }
            }
        } else {
            // Create new panel
            let controller = SnippetSearchWindowController()
            if let panel = controller.window as? NSPanel {
                panel.orderFrontRegardless()
                panel.makeKey()

                // Ensure main windows stay hidden after panel creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hideMainWindowsIfNeeded()
                }
            } else {
                controller.showWindow(nil)
            }
        }
    }
    
    static func returnToPreviousApp() {
        if let app = previousApp, app != NSRunningApplication.current {
            app.activate(options: .activateIgnoringOtherApps)
        }
        previousApp = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        // Clean up the shared reference when window closes
        if SnippetSearchWindowController.shared === self {
            SnippetSearchWindowController.shared = nil
        }

        // Ensure window delegate is cleared
        self.window?.delegate = nil
    }
}