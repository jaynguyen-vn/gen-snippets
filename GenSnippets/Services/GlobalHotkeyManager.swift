import AppKit
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private init() {
        // Listen for shortcut updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateShortcut),
            name: NSNotification.Name("UpdateSearchShortcut"),
            object: nil
        )
    }
    
    func setupGlobalHotkey() {
        // Request accessibility permissions if needed
        let options = NSDictionary(object: kCFBooleanTrue as Any,
                                   forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        registerHotkey()
    }
    
    private func registerHotkey() {
        // Remove existing monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Get custom shortcut from UserDefaults
        let keyCode = UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode")
        let modifierValue = UserDefaults.standard.integer(forKey: "SearchShortcutModifiers")
        
        // Use defaults if not set
        let finalKeyCode = keyCode == 0 ? 1 : keyCode // Default: S key (keyCode 1)
        let finalModifiers = modifierValue == 0 ? [NSEvent.ModifierFlags.control, NSEvent.ModifierFlags.command] : NSEvent.ModifierFlags(rawValue: UInt(modifierValue))
        
        // Set up global event monitor with custom shortcut
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if self.matchesShortcut(event: event, keyCode: finalKeyCode, modifiers: finalModifiers) {
                DispatchQueue.main.async {
                    SnippetSearchWindowController.showSearchWindow()
                }
            }
        }
        
        // Also add local monitor for when app is active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.matchesShortcut(event: event, keyCode: finalKeyCode, modifiers: finalModifiers) {
                SnippetSearchWindowController.showSearchWindow()
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func matchesShortcut(event: NSEvent, keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        let eventModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return Int(event.keyCode) == keyCode && eventModifiers == modifiers
    }
    
    @objc private func updateShortcut() {
        registerHotkey()
    }
}