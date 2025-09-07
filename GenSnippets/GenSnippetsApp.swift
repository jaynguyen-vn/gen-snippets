import SwiftUI
import ServiceManagement
import AppKit

@main
struct GenSnippetsApp: App {
    @State private var isQuitting = false
    
    // For macOS 11 compatibility
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize app
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Start text monitoring service
                    TextReplacementService.shared.startMonitoring()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
                }
            }
        }
    }
    
    // Alert to confirm if user wants to quit or run in background
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

// AppDelegate to handle menu bar item for macOS 11 compatibility
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let shared = AppDelegate()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dockMenu: NSMenu?
    private var shouldTerminate = false
    
    @Published private(set) var startAtLogin: Bool = false
    
    private let loginItemIdentifier = "com.gensnippets.launcher"
    
    // Store notification observers to properly remove them
    private var notificationObservers: [NSObjectProtocol] = []
    
    deinit {
        // Remove all notification observers
        notificationObservers.forEach { 
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions first
        if !AccessibilityPermissionManager.shared.isAccessibilityEnabled() {
            AccessibilityPermissionManager.shared.showAccessibilityPermissionAlert()
        }
        
        // Check if status bar icon should be shown (default to true if not set)
        let shouldShowStatusBar = UserDefaults.standard.object(forKey: "ShowStatusBarIcon") as? Bool ?? true
        print("[AppDelegate] Status bar icon preference on launch: \(shouldShowStatusBar)")
        if shouldShowStatusBar {
            setupMenuBarItem()
        }
        setupDockMenu()
        
        // Always start monitoring for text commands
        TextReplacementService.shared.startMonitoring()
        
        // Setup global hotkey for snippet search
        GlobalHotkeyManager.shared.setupGlobalHotkey()
        
        
        // Listen for accessibility permission granted
        let accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AccessibilityPermissionGranted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAccessibilityPermissionGranted()
        }
        notificationObservers.append(accessibilityObserver)
        
        // Listen for snippets updates
        let snippetsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SnippetsUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let snippets = notification.object as? [Snippet] {
                TextReplacementService.shared.updateSnippets(snippets)
            }
        }
        notificationObservers.append(snippetsObserver)
        
        // Listen for hide menu bar icon request
        let hideMenuBarObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HideMenuBarIcon"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hideMenuBarIcon()
        }
        notificationObservers.append(hideMenuBarObserver)
        
        // Listen for show menu bar icon request
        let showMenuBarObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowMenuBarIcon"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showMenuBarIcon()
        }
        notificationObservers.append(showMenuBarObserver)
        
        // Listen for hide dock icon request
        let hideDockObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HideDockIcon"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hideDockIcon()
        }
        notificationObservers.append(hideDockObserver)
        
        // Listen for confirmed quit
        let confirmedQuitObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ConfirmedQuit"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfirmedQuit()
        }
        notificationObservers.append(confirmedQuitObserver)
        
        // Listen for close popover request
        let closePopoverObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClosePopover"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closePopover()
        }
        notificationObservers.append(closePopoverObserver)
        
        // Listen for status bar icon visibility changes
        let statusBarObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StatusBarIconVisibilityChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleStatusBarIconVisibilityChanged(notification)
        }
        notificationObservers.append(statusBarObserver)
        
        // Handle keyboard shortcuts
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Command+Q for quit dialog
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
                return nil // Consume the event
            }
            
            // Custom shortcut for snippet search (handled by GlobalHotkeyManager)
            
            return event
        }
    }
    
    
    @objc private func hideDockIcon() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    @objc private func showDockIcon() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    @objc private func hideMenuBarIcon() {
        statusItem?.isVisible = false
        UserDefaults.standard.set(false, forKey: "showStatusBarIcon")
        NotificationCenter.default.post(name: NSNotification.Name("StatusBarIconChanged"), object: nil)
    }
    
    @objc private func showMenuBarIcon() {
        if statusItem == nil {
            setupMenuBarItem()
        } else {
            statusItem?.isVisible = true
        }
        UserDefaults.standard.set(true, forKey: "showStatusBarIcon")
        NotificationCenter.default.post(name: NSNotification.Name("StatusBarIconChanged"), object: nil)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Check if accessibility permissions were granted while app was inactive
        if !AccessibilityPermissionManager.shared.isAccessibilityEnabled() {
            // If still not enabled, don't show alert automatically on activation
            // This prevents alert from showing every time app becomes active
        } else {
            // If permissions are now enabled and we previously showed an alert, notify user
            NSLog("🔐 AppDelegate: App became active with accessibility permissions enabled")
            
            // Check if we need to show the restart alert
            if AccessibilityPermissionManager.shared.needsRestartAfterPermissionGrant() {
                // Show restart alert if permissions were granted during this session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let alert = NSAlert()
                    alert.messageText = "Restart Required"
                    alert.informativeText = """
                    Accessibility permissions have been granted!
                    
                    To ensure all features work properly, please quit and reopen GenSnippets.
                    
                    Would you like to quit now?
                    """
                    alert.alertStyle = .informational
                    
                    alert.addButton(withTitle: "Quit Now")
                    alert.addButton(withTitle: "Later")
                    
                    let response = alert.runModal()
                    
                    if response == .alertFirstButtonReturn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NSApp.terminate(nil)
                        }
                    }
                }
            }
        }
    }
    
    private func setupMenuBarItem() {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "repeat", accessibilityDescription: "GenSnippets")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create the popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 600)
        popover?.behavior = .transient
        popover?.appearance = NSAppearance(named: .vibrantLight)
        
        // Create the SwiftUI view for the popover
        let menuBarView = MenuBarView()
        
        // Create the hosting controller
        let hostingController = NSHostingController(rootView: menuBarView)
        popover?.contentViewController = hostingController
    }
    
    @objc private func togglePopover() {
        if let popover = popover, let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    @objc private func handleConfirmedQuit() {
        shouldTerminate = true
        NSApp.terminate(nil)
    }
    
    @objc private func handleAccessibilityPermissionGranted() {
        NSLog("🔐 AppDelegate: Accessibility permission granted notification received")
        // The restart alert is now handled in AccessibilityPermissionManager
    }
    
    @objc private func handleStatusBarIconVisibilityChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let isVisible = userInfo["isVisible"] as? Bool {
            print("[AppDelegate] Status bar icon visibility changed to: \(isVisible)")
            if isVisible {
                showMenuBarIcon()
            } else {
                hideMenuBarIcon()
            }
        }
    }
    
    private func setupDockMenu() {
        // Create dock menu
        dockMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleDockQuit), keyEquivalent: "")
        quitItem.target = self
        dockMenu?.addItem(quitItem)
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return dockMenu
    }
    
    @objc private func handleDockQuit() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Only allow termination if confirmed through our dialog
        if !shouldTerminate {
            NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminate {
            return .terminateNow
        }
        NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
        return .terminateCancel
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Get the main menu
        if let mainMenu = NSApp.mainMenu {
            // Find the application menu (first menu)
            if let appMenu = mainMenu.items.first?.submenu {
                // Find and modify the Quit menu item
                if let quitMenuItem = appMenu.items.last {
                    quitMenuItem.action = #selector(handleDockQuit)
                    quitMenuItem.target = self
                }
            }
        }
    }
    
    private func checkLoginItemStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            startAtLogin = service.status == .enabled
        } else {
            // For macOS 12 and earlier
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                startAtLogin = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            }
        }
    }
    
    @objc func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                    startAtLogin = false
                } else {
                    try service.register()
                    startAtLogin = true
                }
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        } else {
            // For macOS 12 and earlier
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                startAtLogin.toggle()
                _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, startAtLogin)
            }
        }
    }
    
    @objc private func closePopover() {
        popover?.performClose(nil)
    }
} 