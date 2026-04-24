import SwiftUI
import ServiceManagement
import AppKit
import Sparkle

@main
struct GenSnippetsApp: App {
    @State private var isQuitting = false

    // For macOS 11 compatibility
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Sparkle auto-updater
    @ObservedObject private var updaterService = UpdaterService.shared

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
                Button("Check for Updates...") {
                    updaterService.checkForUpdates()
                }
                .disabled(!updaterService.canCheckForUpdates)

                Divider()

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
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dockMenu: NSMenu?
    private var shouldTerminate = false

    // Track if app is running in background (menu bar only) mode
    private(set) var isRunningInBackground = false

    // True only when app launched as login item (boot) — window is a zombie and must be recreated.
    // False when user chose "Run in Background" — window is valid, just hidden.
    private var launchedAsLoginItem = false

    // Strong reference to main window — prevents deallocation during background mode
    // This is the root cause fix: weak reference allowed SwiftUI to deallocate the window
    // when activation policy changed to .accessory, making the app unable to reopen.
    private var mainWindow: NSWindow?

    // Identifier used to tag and reliably find the main content window
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("GenSnippetsMainWindow")

    @Published private(set) var startAtLogin: Bool = false

    private let loginItemIdentifier = "com.gensnippets.launcher"

    // Store notification observers to properly remove them
    private var notificationObservers: [NSObjectProtocol] = []
    private var localEventMonitor: Any?

    deinit {
        // Remove all notification observers
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()

        // Remove local event monitor
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions — suppress alert in background mode to avoid
        // a random dialog appearing during boot
        if !isRunningInBackground {
            if !AccessibilityPermissionManager.shared.isAccessibilityEnabled() {
                AccessibilityPermissionManager.shared.showAccessibilityPermissionAlert()
            }
        }

        // Check if status bar icon should be shown (default to true if not set)
        // IMPORTANT: Force show menu bar icon when running in background mode,
        // otherwise the app becomes a ghost process with no way to access it
        let shouldShowStatusBar = UserDefaults.standard.object(forKey: "ShowStatusBarIcon") as? Bool ?? true
        print("[AppDelegate] Status bar icon preference on launch: \(shouldShowStatusBar), background mode: \(isRunningInBackground)")
        if shouldShowStatusBar || isRunningInBackground {
            setupMenuBarItem()
        }
        setupDockMenu()

        // If in background mode, hide any windows immediately (before the 0.5s delay)
        // to prevent a brief window flash during boot
        if isRunningInBackground {
            for window in NSApplication.shared.windows {
                if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                    window.orderOut(nil)
                }
            }
        }

        // Tag and capture the main window for reliable restoration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.captureMainWindow()

            // Safety net: hide any windows that WindowGroup may have created after our
            // immediate hide above (SwiftUI can defer window creation)
            if self.isRunningInBackground {
                for window in NSApplication.shared.windows {
                    if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                        window.orderOut(nil)
                    }
                }
                NSLog("GenSnippets: Hidden windows for background mode")
            }
        }
        
        // Always start monitoring for text commands
        TextReplacementService.shared.startMonitoring()

        // Load snippets directly from storage so text replacement works immediately,
        // even when SwiftUI views haven't been initialized (e.g. background mode)
        let snippets = LocalStorageService.shared.loadSnippets()
        TextReplacementService.shared.updateSnippets(snippets)
        NSLog("GenSnippets: Loaded %d snippets for text replacement", snippets.count)
        
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

        // Listen for show dock icon request
        let showDockObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowDockIcon"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showDockIcon()
        }
        notificationObservers.append(showDockObserver)

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
        
        // Handle keyboard shortcuts with proper cleanup
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
        isRunningInBackground = true

        // Capture main window before hiding (in case it wasn't captured yet)
        captureMainWindow()

        // Hide all main windows (but not panels like the search window)
        for window in NSApplication.shared.windows {
            if !(window is NSPanel) && window.className != "NSStatusBarWindow" {
                window.orderOut(nil)
            }
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        NSLog("GenSnippets: Entered background mode, mainWindow retained: \(mainWindow != nil)")
    }

    @objc private func showDockIcon() {
        let wasBackgroundSinceLaunch = isRunningInBackground
        isRunningInBackground = false
        NSApplication.shared.setActivationPolicy(.regular)

        // Allow macOS time to fully process the activation policy change
        // (0.15s can be too short during boot when system is under load)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Abort if user switched back to background during the delay
            guard !self.isRunningInBackground else { return }

            // Login-item launch: window is a zombie (created in .accessory mode before
            // SwiftUI fully rendered). Discard it and create a fresh window.
            if self.launchedAsLoginItem {
                self.launchedAsLoginItem = false
                NSLog("GenSnippets: First open after login-item launch, creating fresh window")
                self.mainWindow = nil
                self.createAndShowMainWindow()
                return
            }

            // Normal restore (user chose "Run in Background" then reopened, or other cases)
            if let window = self.mainWindow {
                self.applyHiddenTitleBarStyle(to: window)
                self.ensureReasonableWindowSize(window)
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSLog("GenSnippets: Restored retained main window")
                return
            }

            if let window = self.findMainWindow() {
                self.applyHiddenTitleBarStyle(to: window)
                self.ensureReasonableWindowSize(window)
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                self.mainWindow = window
                NSLog("GenSnippets: Restored window by identifier")
                return
            }

            NSLog("GenSnippets: No window found, creating new one")
            self.createAndShowMainWindow()
        }
    }

    /// Finds the main window by identifier, falling back to class-based search
    private func findMainWindow() -> NSWindow? {
        // First: look by identifier
        if let window = NSApplication.shared.windows.first(where: {
            $0.identifier == Self.mainWindowIdentifier
        }) {
            return window
        }
        // Fallback: look for non-panel, non-status-bar window
        return NSApplication.shared.windows.first(where: {
            !(($0 is NSPanel) || $0.className == "NSStatusBarWindow")
        })
    }

    /// Tags and retains the main content window for reliable restoration
    private func captureMainWindow() {
        // Don't re-capture if we already have a valid window
        if let existing = mainWindow, existing.contentView != nil {
            existing.identifier = Self.mainWindowIdentifier
            existing.delegate = self
            return
        }
        // Find and tag the main window
        if let window = NSApplication.shared.windows.first(where: {
            !(($0 is NSPanel) || $0.className == "NSStatusBarWindow")
        }) {
            window.identifier = Self.mainWindowIdentifier
            window.delegate = self
            mainWindow = window
            NSLog("GenSnippets: Main window captured and tagged")
        }
    }

    // Intercept Cmd+W: hide window instead of destroying it to preserve SwiftUI state
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.identifier == Self.mainWindowIdentifier {
            sender.orderOut(nil)
            return false // Prevent close — just hide
        }
        return true
    }

    /// Enforces the hidden-title-bar look that matches SwiftUI's `HiddenTitleBarWindowStyle`.
    /// Called on every window restore/create path to guard against style drift after long
    /// background sleeps or when a fallback NSWindow is instantiated manually.
    private func applyHiddenTitleBarStyle(to window: NSWindow) {
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }

    /// Ensures the window is at least a reasonable size when restoring from background.
    /// SwiftUI may have created it with a tiny frame while in .accessory mode.
    private func ensureReasonableWindowSize(_ window: NSWindow) {
        let minReasonableWidth: CGFloat = 780
        let minReasonableHeight: CGFloat = 550
        let frame = window.frame
        if frame.width < minReasonableWidth || frame.height < minReasonableHeight {
            let defaultRect = NSRect(x: 0, y: 0, width: 1100, height: 700)
            window.setFrame(defaultRect, display: false)
            window.center()
            NSLog("GenSnippets: Window was too small (%.0fx%.0f), resized to default", frame.width, frame.height)
        }
    }

    /// Creates a new main window when none exists
    private func createAndShowMainWindow() {
        // Guard: if mainWindow was restored by another code path, just show it
        if let existing = mainWindow, existing.contentView != nil {
            ensureReasonableWindowSize(existing)
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSLog("GenSnippets: Reused existing main window instead of creating new")
            return
        }

        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "GenSnippets"
        window.identifier = Self.mainWindowIdentifier
        window.delegate = self
        // Match SwiftUI WindowGroup's HiddenTitleBarWindowStyle — hide title chrome so
        // SwiftUI content flows behind traffic lights (fixes blank title bar after background)
        applyHiddenTitleBarStyle(to: window)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow = window

        NSLog("GenSnippets: Created new main window")
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
        // Ensure main window is captured (fallback if initial 0.5s delay was too early)
        if mainWindow == nil {
            captureMainWindow()
        }

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
        // Save all data before quitting
        LocalStorageService.shared.forceSave()
        UsageTracker.shared.forceSave()
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

    // Handle app reopen (from Spotlight, dock click, etc.)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isRunningInBackground {
            showDockIcon()
            return false
        }

        // Even when not in background mode, ensure main window is visible
        // This handles the case where window was closed but app is still running
        if !flag {
            if let window = mainWindow {
                applyHiddenTitleBarStyle(to: window)
                ensureReasonableWindowSize(window)
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            } else if let window = findMainWindow() {
                applyHiddenTitleBarStyle(to: window)
                ensureReasonableWindowSize(window)
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                mainWindow = window
            } else {
                createAndShowMainWindow()
            }
            return false
        }

        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save all pending data before terminating (including Sparkle updates)
        LocalStorageService.shared.forceSave()
        UsageTracker.shared.forceSave()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminate {
            return .terminateNow
        }
        NotificationCenter.default.post(name: NSNotification.Name("ShowQuitDialog"), object: nil)
        return .terminateCancel
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Detect login item launch → start in background mode immediately
        // This must happen BEFORE WindowGroup creates its window
        if shouldStartInBackground() {
            isRunningInBackground = true
            launchedAsLoginItem = true
            NSApplication.shared.setActivationPolicy(.accessory)
            NSLog("GenSnippets: Detected login item launch, starting in background mode")
        }

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

    /// Detect if the app was launched as a login item (system startup) rather than by the user
    private func shouldStartInBackground() -> Bool {
        // Only auto-background if Start at Login is configured
        if #available(macOS 13.0, *) {
            guard SMAppService.mainApp.status == .enabled else { return false }
        } else {
            return false
        }

        // Method 1: Apple Event descriptor — macOS sets 'logi' when launched as login item
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           let descriptor = event.paramDescriptor(forKeyword: keyAEPropData) {
            let launchedAsLoginItem = descriptor.enumCodeValue == 0x6C6F6769 // 'logi'
            if launchedAsLoginItem {
                NSLog("GenSnippets: Apple Event confirms login item launch")
                markBackgroundLaunchThisBoot()
                return true
            }
        }

        // Method 2: System uptime heuristic — if booted < 2 min ago, likely a login launch
        // Guard: skip if we already launched in background this boot cycle
        // (prevents false positive when user force-quits and reopens manually within 2 min)
        let uptime = ProcessInfo.processInfo.systemUptime
        if uptime < 120 {
            if hasAlreadyLaunchedInBackgroundThisBoot() {
                NSLog("GenSnippets: Uptime %.0fs < 120s but already background-launched this boot, skipping", uptime)
                return false
            }
            NSLog("GenSnippets: System uptime %.0fs < 120s, assuming login item launch", uptime)
            markBackgroundLaunchThisBoot()
            return true
        }

        return false
    }

    /// Track boot-cycle background launches to prevent false positives on re-launch
    private func markBackgroundLaunchThisBoot() {
        let bootTime = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        UserDefaults.standard.set(bootTime, forKey: "LastBackgroundLaunchBootTime")
    }

    private func hasAlreadyLaunchedInBackgroundThisBoot() -> Bool {
        let savedBootTime = UserDefaults.standard.double(forKey: "LastBackgroundLaunchBootTime")
        guard savedBootTime > 0 else { return false }
        let currentBootTime = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        // Same boot cycle if boot times match within 5 seconds tolerance
        return abs(savedBootTime - currentBootTime) < 5
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