import Foundation
import AppKit
import Carbon

// MARK: - Browser-Compatible Text Insertion Service
final class BrowserCompatibleTextInsertion {

    enum InsertionMethod {
        case clipboard      // Use clipboard paste (current method)
        case keyEvents      // Type each character individually
        case hybrid         // Smart detection based on app
    }

    private static func getCurrentAppBundleID() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private static func isWebBrowser() -> Bool {
        guard let bundleID = getCurrentAppBundleID() else { return false }

        let browserBundleIDs = [
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "com.opera.Opera",
            "com.vivaldi.Vivaldi"
        ]

        return browserBundleIDs.contains(bundleID)
    }

    // MARK: - Enhanced Insertion with Browser Detection
    static func insertText(_ text: String, previousContent: String?) {
        let isBrowser = isWebBrowser()

        #if DEBUG
        print("[BrowserCompatible] Current app is browser: \(isBrowser)")
        if let bundleID = getCurrentAppBundleID() {
            print("[BrowserCompatible] Current app: \(bundleID)")
        }
        #endif

        if isBrowser {
            insertTextForBrowser(text, previousContent: previousContent)
        } else {
            insertTextStandard(text, previousContent: previousContent)
        }
    }

    // MARK: - Browser-Specific Insertion
    private static func insertTextForBrowser(_ text: String, previousContent: String?) {
        let pasteboard = NSPasteboard.general

        // Store original clipboard
        let originalContent = pasteboard.string(forType: .string)

        // Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // Create paste events with browser-specific timing
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
           let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
           let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
           let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {

            cmdDown.flags = [.maskCommand, .maskNonCoalesced]
            vDown.flags = [.maskCommand, .maskNonCoalesced]
            vUp.flags = [.maskCommand, .maskNonCoalesced]
            cmdUp.flags = .maskNonCoalesced

            // Longer delays for browsers to ensure paste completes
            cmdDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002) // 2ms

            vDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002)

            vUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002)

            cmdUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.005) // Extra delay after paste

            // Restore clipboard after a longer delay for browsers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pasteboard.clearContents()
                if let original = originalContent ?? previousContent {
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }

    // MARK: - Standard Insertion (for non-browsers)
    private static func insertTextStandard(_ text: String, previousContent: String?) {
        let pasteboard = NSPasteboard.general

        // Store original clipboard
        let originalContent = pasteboard.string(forType: .string)

        // Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // Standard paste with faster timing
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
           let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
           let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
           let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {

            cmdDown.flags = [.maskCommand, .maskNonCoalesced]
            vDown.flags = [.maskCommand, .maskNonCoalesced]
            vUp.flags = [.maskCommand, .maskNonCoalesced]
            cmdUp.flags = .maskNonCoalesced

            // Faster timing for native apps
            cmdDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.0008) // 0.8ms

            vDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.0008)

            vUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.0008)

            cmdUp.post(tap: .cghidEventTap)

            // Restore clipboard after standard delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                if let original = originalContent ?? previousContent {
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }

    // MARK: - Alternative: Character-by-character typing
    static func typeText(_ text: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        for char in text {
            typeCharacter(char, source: source)
            Thread.sleep(forTimeInterval: 0.001) // 1ms between characters
        }
    }

    private static func typeCharacter(_ character: Character, source: CGEventSource) {
        let string = String(character)

        // Create a key event with the character
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            // Convert string to UTF16
            let utf16 = Array(string.utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            event.post(tap: .cghidEventTap)

            // Key up event
            if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                upEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                upEvent.post(tap: .cghidEventTap)
            }
        }
    }
}

// Note: The browser detection and timing improvements have been
// integrated directly into TextReplacementService.swift for better access to private methods