import SwiftUI
import AppKit
import Carbon

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifierFlags: NSEvent.ModifierFlags
    
    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.keyCode = keyCode
        field.modifierFlags = modifierFlags
        field.shortcutDelegate = context.coordinator
        return field
    }
    
    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifierFlags = modifierFlags
        nsView.updateDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ShortcutRecorderFieldDelegate {
        let parent: ShortcutRecorderView
        
        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }
        
        func shortcutRecorderFieldDidChange(_ field: ShortcutRecorderField) {
            parent.keyCode = field.keyCode
            parent.modifierFlags = field.modifierFlags
        }
    }
}

protocol ShortcutRecorderFieldDelegate: AnyObject {
    func shortcutRecorderFieldDidChange(_ field: ShortcutRecorderField)
}

class ShortcutRecorderField: NSTextField {
    weak var shortcutDelegate: ShortcutRecorderFieldDelegate?
    var keyCode: Int = 49 // Default: Space
    var modifierFlags: NSEvent.ModifierFlags = .option // Default: Option
    private var isRecording = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isEditable = false
        isBordered = true
        focusRingType = .default
        alignment = .center
        updateDisplay()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        // Don't auto-start recording when becoming first responder
        // User needs to click to start recording
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        // Only allow resigning when not recording
        if isRecording {
            return false
        }
        return super.resignFirstResponder()
    }
    
    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            window?.makeFirstResponder(self)
            startRecording()
        } else {
            // If already recording, stop on second click
            stopRecording()
        }
        // Don't call super to prevent default behavior
    }
    
    override func keyDown(with event: NSEvent) {
        print("[ShortcutRecorder] keyDown - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags)")
        
        if !isRecording {
            // Don't start recording on keyDown - user needs to click first
            return
        }
        
        // Check if it's Escape to cancel
        if event.keyCode == 53 { // Escape
            print("[ShortcutRecorder] Escape pressed - canceling")
            stopRecording()
            return
        }
        
        // Check if it's Delete to clear
        if event.keyCode == 51 { // Delete
            print("[ShortcutRecorder] Delete pressed - clearing")
            keyCode = 0
            modifierFlags = []
            updateDisplay()
            stopRecording()
            shortcutDelegate?.shortcutRecorderFieldDidChange(self)
            return
        }
        
        // Record the shortcut - require at least one modifier
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        print("[ShortcutRecorder] Relevant modifiers: \(relevantModifiers)")
        
        // Allow recording if modifiers are pressed
        if !relevantModifiers.isEmpty {
            print("[ShortcutRecorder] Recording shortcut - keyCode: \(event.keyCode), modifiers: \(relevantModifiers)")
            keyCode = Int(event.keyCode)
            modifierFlags = relevantModifiers
            updateDisplay()
            
            // Notify delegate before stopping to avoid focus issues
            shortcutDelegate?.shortcutRecorderFieldDidChange(self)
            
            // Stop recording but keep focus
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording()
            }
        } else {
            print("[ShortcutRecorder] No modifiers pressed - waiting for modifier key")
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            // Update display to show current modifiers
            let tempString = ShortcutRecorderField.stringForModifiers(event.modifierFlags)
            stringValue = tempString.isEmpty ? "Type shortcut..." : tempString
        }
    }
    
    private func startRecording() {
        print("[ShortcutRecorder] Starting recording")
        isRecording = true
        backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2)
        stringValue = "Type shortcut..."
        needsDisplay = true
    }
    
    private func stopRecording() {
        print("[ShortcutRecorder] Stopping recording")
        isRecording = false
        backgroundColor = .clear
        updateDisplay()
        needsDisplay = true
        // Keep focus after recording
        window?.makeFirstResponder(self)
    }
    
    func updateDisplay() {
        stringValue = ShortcutRecorderField.stringForShortcut(keyCode: keyCode, modifiers: modifierFlags)
    }
    
    static func stringForShortcut(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        if keyCode == 0 && modifiers.isEmpty {
            return "Click to record shortcut"
        }
        
        var string = ""
        
        // Add modifiers
        string += stringForModifiers(modifiers)
        
        // Add key - always show the key if we have one
        if let keyString = stringForKeyCode(keyCode) {
            string += keyString
        } else if keyCode > 0 {
            // Fallback for unknown keys
            string += "Key\(keyCode)"
        }
        
        return string.isEmpty ? "Click to record shortcut" : string
    }
    
    static func stringForModifiers(_ modifiers: NSEvent.ModifierFlags) -> String {
        var string = ""
        if modifiers.contains(.control) { string += "⌃" }
        if modifiers.contains(.option) { string += "⌥" }
        if modifiers.contains(.shift) { string += "⇧" }
        if modifiers.contains(.command) { string += "⌘" }
        return string
    }
    
    static func stringForKeyCode(_ keyCode: Int) -> String? {
        switch keyCode {
        // Letters
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        
        // Numbers
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        
        // Special keys
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        
        // Punctuation
        case 27: return "-"
        case 24: return "="
        case 33: return "["
        case 30: return "]"
        case 39: return "'"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 47: return "."
        case 50: return "`"
        
        default: return "Key\(keyCode)"
        }
    }
}