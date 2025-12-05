import Foundation
import AppKit
import os.log

class AccessibilityPermissionManager {
    static let shared = AccessibilityPermissionManager()
    private var isShowingAlert = false
    private let logger = OSLog(subsystem: "Jay8448.Gen-Snippets", category: "Accessibility")
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 30  // Check for 60 seconds (30 * 2s)
    private var permissionGrantedDuringSession = false
    
    // MARK: - Public Interface
    
    /// Check and request accessibility permissions if needed
    /// - Returns: true if permissions are granted, false otherwise
    @discardableResult
    func requestAccessibilityPermissions() -> Bool {
        // First check without prompt
        let result = AXIsProcessTrusted()
        NSLog("🔐 AccessibilityPermissionManager: Checking permissions - \(result)")

        if !result {
            // Request with prompt - this will show system dialog AND add app to Accessibility list
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let promptResult = AXIsProcessTrustedWithOptions(options)
            NSLog("🔐 AccessibilityPermissionManager: Requested with prompt - \(promptResult)")

            // Start monitoring for permission changes
            startRetryTimer()
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
        GenSnippets needs accessibility access to monitor keyboard input and expand snippets.

        How to enable:
        1. Click 'Open System Settings' below
        2. Click the '+' button at the bottom of the list
        3. Navigate to Applications folder
        4. Select 'GenSnippets' and click Open
        5. Toggle the switch ON

        GenSnippets will automatically detect when permission is granted.
        """
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        NSLog("🔐 AccessibilityPermissionManager: Alert response - \(response)")

        isShowingAlert = false

        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
            // Also reveal app in Finder to make it easier to drag/find
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let appURL = Bundle.main.bundleURL.deletingLastPathComponent() as URL? {
                    NSWorkspace.shared.selectFile(Bundle.main.bundlePath, inFileViewerRootedAtPath: appURL.path)
                }
            }
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
        NSLog("🔐 AccessibilityPermissionManager: Opening System Settings -> Accessibility")
        // Open directly to Privacy & Security > Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    deinit {
        stopRetryTimer()
    }
} 