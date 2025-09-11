import AppKit
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var hotkeyCheckTimer: Timer?
    
    private init() {
        // Listen for shortcut updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateShortcut),
            name: NSNotification.Name("UpdateSearchShortcut"),
            object: nil
        )
        
        // Start timer to periodically check and re-register hotkeys if needed
        startHotkeyCheckTimer()
    }
    
    deinit {
        hotkeyCheckTimer?.invalidate()
        hotkeyCheckTimer = nil
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
                // Note: Global monitors can't consume events, but we handle it in local monitor
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
    
    private func startHotkeyCheckTimer() {
        hotkeyCheckTimer?.invalidate()
        hotkeyCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAndReregisterHotkeysIfNeeded()
        }
    }
    
    private func checkAndReregisterHotkeysIfNeeded() {
        // NSEvent monitors don't have a direct way to check if they're still active,
        // but we can test if they're working by checking if the monitors are nil
        // or by periodically re-registering them to ensure they stay active
        
        // If monitors are nil, re-register
        if globalEventMonitor == nil || localEventMonitor == nil {
            print("[GlobalHotkeyManager] ⚠️ Hotkey monitors were nil, re-registering...")
            registerHotkey()
        }
        
        // Additionally, re-register every 30 seconds to ensure they stay active
        let now = Date()
        if let lastRegistration = UserDefaults.standard.object(forKey: "LastHotkeyRegistration") as? Date {
            if now.timeIntervalSince(lastRegistration) > 30 {
                print("[GlobalHotkeyManager] 🔄 Refreshing hotkey registration...")
                registerHotkey()
                UserDefaults.standard.set(now, forKey: "LastHotkeyRegistration")
            }
        } else {
            UserDefaults.standard.set(now, forKey: "LastHotkeyRegistration")
        }
    }
}