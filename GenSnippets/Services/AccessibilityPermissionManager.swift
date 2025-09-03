import Foundation
import AppKit
import os.log

class AccessibilityPermissionManager {
    static let shared = AccessibilityPermissionManager()
    private var isShowingAlert = false
    private let logger = OSLog(subsystem: "Jay8448.Gen-Snippets", category: "Accessibility")
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 5
    private var hasTriedAutomaticPermission = false
    private var permissionGrantedDuringSession = false
    
    // MARK: - Public Interface
    
    /// Check and request accessibility permissions if needed
    /// - Returns: true if permissions are granted, false otherwise
    @discardableResult
    func requestAccessibilityPermissions() -> Bool {
        let result = AXIsProcessTrusted()
        NSLog("🔐 AccessibilityPermissionManager: Checking permissions - \(result)")
        
        if !result {
            tryAutomaticPermission()
        }
        
        return result
    }
    
    /// Check if accessibility permissions are enabled
    /// - Returns: true if permissions are granted, false otherwise
    func isAccessibilityEnabled() -> Bool {
        let result = AXIsProcessTrusted()
        NSLog("🔐 AccessibilityPermissionManager: Checking if accessibility is enabled - \(result)")
        return result
    }
    
    /// Show the accessibility permission alert manually
    /// - Returns: true if the alert was shown, false if it's already showing
    @discardableResult
    func showAccessibilityPermissionAlert() -> Bool {
        if isShowingAlert {
            NSLog("🔐 AccessibilityPermissionManager: Alert already showing, skipping...")
            return false
        }
        
        isShowingAlert = true
        NSLog("🔐 AccessibilityPermissionManager: Showing permission alert")
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        GenSnippets needs accessibility access to function properly.

        How to enable:
        1. Click 'Open System Settings'
        2. Select 'Privacy & Security' from the sidebar
        3. Scroll down and click 'Accessibility'
        4. Click the '+' button below the app list.
        5. Navigate to the Applications folder.
        6. Find and select 'GenSnippets', then click Open.
        7. Enable the permission by checking the box next to 'GenSnippets'.
        8. Restart GenSnippets:
        - Quit the app completely.
        - Open GenSnippets again.
        
        Once restarted, GenSnippets will automatically detect the granted permission.
        """
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        NSLog("🔐 AccessibilityPermissionManager: Alert response - \(response)")
        
        isShowingAlert = false
        
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
        
        return true
    }
    
    /// Check if permissions were granted during this session and app needs restart
    func needsRestartAfterPermissionGrant() -> Bool {
        return permissionGrantedDuringSession
    }
    
    // MARK: - Private Implementation
    
    private init() {
        NSLog("🔐 AccessibilityPermissionManager: Initializing...")
        debugPrintAppInfo()
    }
    
    private func debugPrintAppInfo() {
        NSLog("=== 🔐 App Debug Information ===")
        // Print bundle information
        NSLog("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Not found")")
        NSLog("Bundle URL: \(Bundle.main.bundleURL.path)")
        NSLog("Executable URL: \(Bundle.main.executableURL?.path ?? "Not found")")
        
        // Print process information
        NSLog("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        NSLog("Process Name: \(ProcessInfo.processInfo.processName)")
        
        // Print AX trust status
        let trusted = AXIsProcessTrusted()
        let trustStatus = AXIsProcessTrustedWithOptions(nil)
        NSLog("AX Trust Status - Trusted: \(trusted), With Options: \(trustStatus)")
        
        // Print sandbox status
        if let sandboxContainer = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] {
            NSLog("Sandbox Container ID: \(sandboxContainer)")
        }
        
        NSLog("=== 🔐 End Debug Information ===")
    }
    
    private func tryAutomaticPermission() {
        guard !hasTriedAutomaticPermission else { return }
        hasTriedAutomaticPermission = true
        
        NSLog("🔐 AccessibilityPermissionManager: Attempting automatic permission...")
        
        // First, try to launch System Events
        launchSystemEvents()
        
        // Wait longer for System Events to launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            
            let script = """
            try
                -- First make sure System Events is running and ready
                tell application "System Events"
                    launch
                    delay 1
                    set frontmost to true
                    delay 1
                end tell
                
                -- Then try to navigate System Settings
                tell application "System Settings"
                    activate
                    delay 1
                    
                    tell application "System Events"
                        tell process "System Settings"
                            -- Wait for the window to appear
                            repeat until exists window 1
                                delay 0.5
                            end repeat
                            
                            -- Click Privacy & Security
                            try
                                click menu item "Privacy & Security" of menu "View" of menu bar 1
                                delay 1
                                
                                -- Wait for the main window content
                                repeat until exists group 1 of window 1
                                    delay 0.5
                                end repeat
                                
                                tell window 1
                                    tell group 1
                                        -- Find and click Accessibility in the sidebar
                                        tell scroll area 1
                                            tell table 1
                                                repeat with i from 1 to count rows
                                                    if name of row i contains "Accessibility" then
                                                        select row i
                                                        exit repeat
                                                    end if
                                                end repeat
                                            end tell
                                        end tell
                                        
                                        delay 1
                                        
                                        -- Try to find and click our app's checkbox
                                        tell scroll area 2
                                            tell table 1
                                                repeat with aRow in rows
                                                    if name of aRow contains "GenSnippets" then
                                                        if exists checkbox 1 of aRow then
                                                            if value of checkbox 1 of aRow is 0 then
                                                                click checkbox 1 of aRow
                                                                NSLog("🔐 Found and clicked checkbox for GenSnippets")
                                                            end if
                                                        end if
                                                        exit repeat
                                                    end if
                                                end repeat
                                            end tell
                                        end tell
                                    end tell
                                end tell
                                
                                return "Successfully navigated and attempted to enable accessibility"
                            on error errMsg
                                NSLog("🔐 Navigation error: " & errMsg)
                                return "Navigation error: " & errMsg
                            end try
                        end tell
                    end tell
                end tell
            on error systemErr
                NSLog("🔐 System Events error: " & systemErr)
                return "System Events error: " & systemErr
            end try
            """
            
            NSLog("🔐 AccessibilityPermissionManager: Executing automation script...")
            if let scriptObject = NSAppleScript(source: script) {
                var error: NSDictionary?
                let result = scriptObject.executeAndReturnError(&error)
                NSLog("🔐 AccessibilityPermissionManager: Script result - \(result.stringValue ?? "no result")")
                
                if let error = error {
                    NSLog("🔐 AppleScript error details:")
                    error.forEach { key, value in
                        NSLog("🔐 \(key): \(value)")
                    }
                    // If automatic method fails, start the retry timer and show alert
                    self.startRetryTimer()
                    self.showAccessibilityPermissionAlert()
                }
            }
        }
    }
    
    private func startRetryTimer() {
        NSLog("🔐 AccessibilityPermissionManager: Starting retry timer")
        stopRetryTimer() // Stop any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.retryPermissionCheck()
        }
    }
    
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
        retryCount = 0
    }
    
    private func retryPermissionCheck() {
        retryCount += 1
        NSLog("🔐 AccessibilityPermissionManager: Retry attempt \(retryCount)/\(maxRetries)")
        
        let currentStatus = AXIsProcessTrusted()
        NSLog("🔐 AccessibilityPermissionManager: Current accessibility status - \(currentStatus)")
        
        if currentStatus {
            NSLog("🔐 AccessibilityPermissionManager: Permission granted on retry!")
            stopRetryTimer()
            permissionGrantedDuringSession = true
            NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionGranted"), object: nil)
            showRestartRequiredAlert()
        } else if retryCount >= maxRetries {
            NSLog("🔐 AccessibilityPermissionManager: Max retries reached, stopping timer")
            stopRetryTimer()
            if !isShowingAlert {
                showAccessibilityPermissionAlert()
            }
        }
    }
    
    /// Shows an alert informing the user they need to restart the app after granting permissions
    private func showRestartRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Restart Required"
            alert.informativeText = """
            Thank you for granting accessibility permissions!
            
            To ensure all features work properly, please quit and reopen GenSnippets.
            
            Would you like to quit now?
            """
            alert.alertStyle = .informational
            
            alert.addButton(withTitle: "Quit Now")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            NSLog("🔐 AccessibilityPermissionManager: Restart alert response - \(response)")
            
            if response == .alertFirstButtonReturn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    private func openAccessibilityPreferences() {
        NSLog("🔐 AccessibilityPermissionManager: Opening System Settings")
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func launchSystemEvents() {
        if #available(macOS 11.0, *) {
            if let systemEventsURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.SystemEvents") {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: systemEventsURL, configuration: config) { running, error in
                    if let error = error {
                        NSLog("🔐 Error launching System Events: \(error)")
                    }
                }
            }
        } else {
            NSWorkspace.shared.launchApplication(withBundleIdentifier: "com.apple.SystemEvents", 
                                               options: [], 
                                               additionalEventParamDescriptor: nil, 
                                               launchIdentifier: nil)
        }
    }
    
    deinit {
        stopRetryTimer()
    }
} 