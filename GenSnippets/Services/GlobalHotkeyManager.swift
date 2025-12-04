import AppKit
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var hotkeyCheckTimer: Timer?
    
    private var shortcutObserver: Any?

    private init() {
        // Listen for shortcut updates with proper observer storage
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateSearchShortcut"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateShortcut()
        }

        // Start timer to periodically check and re-register hotkeys if needed
        startHotkeyCheckTimer()
    }
    
    deinit {
        // Capture timer reference to avoid sync deadlock
        let timer = hotkeyCheckTimer
        hotkeyCheckTimer = nil

        // Invalidate timer on main thread without blocking
        if Thread.isMainThread {
            timer?.invalidate()
        } else {
            DispatchQueue.main.async {
                timer?.invalidate()
            }
        }

        // Remove event monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        // Remove notification observer
        if let observer = shortcutObserver {
            NotificationCenter.default.removeObserver(observer)
            shortcutObserver = nil
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
        let finalKeyCode = keyCode == 0 ? 14 : keyCode // Default: E key (keyCode 14)
        let finalModifiers = modifierValue == 0 ? [NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command] : NSEvent.ModifierFlags(rawValue: UInt(modifierValue))
        
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
    
    private func updateShortcut() {
        registerHotkey()
    }
    
    private func startHotkeyCheckTimer() {
        // Ensure timer operations happen on main thread
        let setupTimer = { [weak self] in
            self?.hotkeyCheckTimer?.invalidate()
            self?.hotkeyCheckTimer = nil

            // Reduced frequency from 5s to 30s to minimize overhead
            self?.hotkeyCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.checkAndReregisterHotkeysIfNeeded()
            }
        }

        if Thread.isMainThread {
            setupTimer()
        } else {
            DispatchQueue.main.async {
                setupTimer()
            }
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
        
        // Re-register only every 5 minutes to reduce overhead (was 30 seconds)
        let now = Date()
        if let lastRegistration = UserDefaults.standard.object(forKey: "LastHotkeyRegistration") as? Date {
            if now.timeIntervalSince(lastRegistration) > 300 { // 5 minutes
                print("[GlobalHotkeyManager] 🔄 Refreshing hotkey registration...")
                registerHotkey()
                UserDefaults.standard.set(now, forKey: "LastHotkeyRegistration")
            }
        } else {
            UserDefaults.standard.set(now, forKey: "LastHotkeyRegistration")
        }
    }
}