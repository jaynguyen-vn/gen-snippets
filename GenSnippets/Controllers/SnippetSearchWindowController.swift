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
        
        let window = NSWindow(
            contentViewController: hostingController
        )
        
        window.title = "Snippet Search"
        window.titlebarAppearsTransparent = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 860, height: 580))
        window.minSize = NSSize(width: 800, height: 500)
        
        self.init(window: window)
        
        // Set window delegate
        window.delegate = self
        
        // Center the window on screen
        window.center()
        
        // Set window level to floating and make it appear above all apps
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        
        // Make window key and order front when created
        window.makeKeyAndOrderFront(nil)
        
        // Activate the app temporarily to ensure proper focus
        NSApp.activate(ignoringOtherApps: true)
        
        // Store the shared instance
        SnippetSearchWindowController.shared = self
    }
    
    static func showSearchWindow() {
        // Save the currently active app before activating our app
        previousApp = NSWorkspace.shared.frontmostApplication
        
        if let existingWindow = shared?.window {
            // If window already exists, bring it to front
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            
            // Force focus to the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let contentView = existingWindow.contentView,
                   let textField = contentView.firstResponder(ofType: NSTextField.self) {
                    existingWindow.makeFirstResponder(textField)
                }
            }
        } else {
            // Create new window
            let controller = SnippetSearchWindowController()
            controller.showWindow(nil)
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
        SnippetSearchWindowController.shared = nil
    }
}