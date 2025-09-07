import Foundation
import Combine
import AppKit
import Carbon
import CoreGraphics

class TextReplacementService {
    static let shared = TextReplacementService()
    
    private var snippets: [Snippet] = []
    private var snippetLookup: [String: String] = [:]
    private var sortedSnippetsCache: [Snippet] = []
    private var snippetsLastUpdated: Date = Date()
    
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    private var currentInputBuffer = ""
    private let maxBufferSize = 100
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var deadKeyState: UInt32 = 0
    private var selfReference: Unmanaged<TextReplacementService>?
    private var lastKeyTime: TimeInterval = 0
    private var lastKeyCode: CGKeyCode = 0
    private var lastCharHandled: String = ""
    private var bufferClearTimer: Timer?
    private let bufferInactivityTimeout: TimeInterval = 15.0 // Clear buffer after 15 seconds of inactivity
    
    private var cachedEventSource: CGEventSource?
    
    private init() {
        cachedEventSource = CGEventSource(stateID: .hidSystemState)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("SnippetsUpdated"))
            .sink { [weak self] notification in
                if let snippets = notification.object as? [Snippet] {
                    self?.updateSnippets(snippets)
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopMonitoring()
        selfReference?.release()
    }
    
    private func setupKeyMonitor() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("[TextReplacementService] ❌ Need accessibility permissions")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }
        
        print("[TextReplacementService] ✅ Has accessibility permissions")
        
        selfReference = Unmanaged.passRetained(self)
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let service = Unmanaged<TextReplacementService>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    if flags.contains(.maskCommand) || flags.contains(.maskControl) {
                        return Unmanaged.passRetained(event)
                    }
                    
                    if keyCode == 0x33 {
                        if !service.currentInputBuffer.isEmpty {
                            service.currentInputBuffer.removeLast()
                            if service.currentInputBuffer.count >= 2 {
                                service.checkForCommands()
                            }
                        }
                        return Unmanaged.passRetained(event)
                    }
                    
                    // Prevent duplicate key processing by checking time and key code
                    let currentTime = NSDate().timeIntervalSince1970
                    let isRepeatedKey = (currentTime - service.lastKeyTime < 0.008) && CGKeyCode(keyCode) == service.lastKeyCode
                    
                    // Only process this key if it's not a repeated key from input method
                    if !isRepeatedKey {
                        service.lastKeyTime = currentTime
                        service.lastKeyCode = CGKeyCode(keyCode)
                        
                        // Try to get the character directly from the event first (better for input methods like evkey)
                        if let nsEvent = NSEvent(cgEvent: event) {
                            let characters = nsEvent.characters ?? ""
                            
                            if !characters.isEmpty {
                                #if DEBUG
                                print("[TextReplacementService] 📝 Character from NSEvent: \(characters)")
                                #endif
                                
                                // Check if we've just handled this exact same character
                                if characters != service.lastCharHandled || (currentTime - service.lastKeyTime > 0.01) {
                                    service.handleKeyPress(characters)
                                    service.lastCharHandled = characters
                                    
                                    // Reset lastCharHandled after a delay to allow for legitimate repeated characters
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if service.lastCharHandled == characters {
                                            service.lastCharHandled = ""
                                        }
                                    }
                                } else {
                                    #if DEBUG
                                    print("[TextReplacementService] ⚠️ Skipping duplicate character: \(characters)")
                                    #endif
                                }
                                
                                if service.containsCommand(service.currentInputBuffer) {
                                    return Unmanaged.passUnretained(event)
                                }
                                
                                // Return early, we've already processed the character
                                return Unmanaged.passRetained(event)
                            }
                        }
                        
                        // Fallback to UCKeyTranslate (better for standard keyboard layouts)
                        var chars: [UniChar] = [0]
                        var length: Int = 0
                        let keyboard = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
                        
                        if let layoutData = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData) {
                            let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
                            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(data),
                                                             to: UnsafePointer<UCKeyboardLayout>.self)
                            
                            let status = UCKeyTranslate(
                                keyboardLayout,
                                UInt16(keyCode),
                                UInt16(kUCKeyActionDown),
                                0,
                                UInt32(LMGetKbdType()),
                                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                &service.deadKeyState,
                                1,
                                &length,
                                &chars
                            )
                            
                            if status == noErr,
                               let char = String(bytes: Data(bytes: chars, count: length * 2),
                                               encoding: .utf16LittleEndian) {
                                #if DEBUG
                                print("[TextReplacementService] 📝 Received key: \(char)")
                                #endif
                                
                                // Check if we've just handled this exact same character
                                if char != service.lastCharHandled || (currentTime - service.lastKeyTime > 0.01) {
                                    service.handleKeyPress(char)
                                    service.lastCharHandled = char
                                    
                                    // Reset lastCharHandled after a delay to allow for legitimate repeated characters
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if service.lastCharHandled == char {
                                            service.lastCharHandled = ""
                                        }
                                    }
                                } else {
                                    #if DEBUG
                                    print("[TextReplacementService] ⚠️ Skipping duplicate character: \(char)")
                                    #endif
                                }
                                
                                if service.containsCommand(service.currentInputBuffer) {
                                    return Unmanaged.passUnretained(event)
                                }
                            }
                        }
                    } else {
                        #if DEBUG
                        print("[TextReplacementService] ⚠️ Detected repeated key - skipping")
                        #endif
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: selfReference?.toOpaque()
        ) else {
            print("[TextReplacementService] ❌ Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            print("[TextReplacementService] ✅ Added to run loop")
        }
        
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("[TextReplacementService] ✅ Key monitor setup complete")
    }
    
    private func handleKeyPress(_ char: String) {
        #if DEBUG
        print("[TextReplacementService] 🔍 Handling key press: \(char)")
        #endif
        
        // Reset the buffer clear timer whenever a key is pressed
        resetBufferClearTimer()
        
        // Skip empty characters that might come from input methods
        if char.isEmpty {
            #if DEBUG
            print("[TextReplacementService] ⚠️ Skipped empty character")
            #endif
            return
        }
        
        // Detect if character comes from an input method (like evkey)
        // by checking if it contains combining diacritical marks (common in Vietnamese)
        let containsDiacritics = char.unicodeScalars.contains { 
            ($0.value >= 0x0300 && $0.value <= 0x036F) || // Combining Diacritical Marks
            ($0.value >= 0x1AB0 && $0.value <= 0x1AFF) || // Combining Diacritical Marks Extended
            ($0.value >= 0x1DC0 && $0.value <= 0x1DFF)    // Combining Diacritical Marks Supplement
        }
        
        if containsDiacritics {
            #if DEBUG
            print("[TextReplacementService] 🔤 Detected diacritical mark in: \(char)")
            #endif
            // Special handling for diacritical marks if needed
        }
        
        if char == String(Character(UnicodeScalar(0x7F)!)) ||
           char == "\u{8}" ||
           char.utf16.contains(0x7F) ||
           char.utf16.contains(0x8) {
            
            #if DEBUG
            print("[TextReplacementService] 🔍 Detected backspace key")
            #endif
            
            if !currentInputBuffer.isEmpty {
                let deletedChar = String(currentInputBuffer.last!)
                currentInputBuffer.removeLast()
                
                #if DEBUG
                print("[TextReplacementService] 🔙 Backspace - Deleted '\(deletedChar)', Buffer now: '\(currentInputBuffer)'")
                #endif
                
                if currentInputBuffer.count >= 2 {
                    checkForCommands()
                }
            }
            return
        }
        
        if char.rangeOfCharacter(from: .whitespaces.union(.alphanumerics).union(.punctuationCharacters)) != nil {
            if currentInputBuffer.count >= maxBufferSize {
                currentInputBuffer.removeFirst(currentInputBuffer.count - maxBufferSize + 1)
            }
            
            currentInputBuffer += char
            
            #if DEBUG
            print("[TextReplacementService] 📝 Current buffer: '\(currentInputBuffer)'")
            #endif
            
            checkForCommands()
        } else {
            #if DEBUG
            print("[TextReplacementService] ⚠️ Ignored non-printable character: \(char.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))")
            #endif
        }
    }
    
    private func resetBufferClearTimer() {
        // Cancel any existing timer
        bufferClearTimer?.invalidate()
        
        // Create a new timer that will clear the buffer after the inactivity timeout
        bufferClearTimer = Timer.scheduledTimer(withTimeInterval: bufferInactivityTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            #if DEBUG
            if !self.currentInputBuffer.isEmpty {
                print("[TextReplacementService] 🧹 Clearing buffer due to inactivity: '\(self.currentInputBuffer)'")
            }
            #endif
            
            self.currentInputBuffer = ""
        }
    }
    
    private func checkForCommands() {
        let sortedSnippets = snippets.sorted { $0.command.count > $1.command.count }
        
        for snippet in sortedSnippets {
            if currentInputBuffer.count < snippet.command.count {
                continue
            }
            
            // Only check if the buffer ends with the snippet command
            // This prevents false matches where any character typed gets replaced
            if currentInputBuffer.hasSuffix(snippet.command) {
                let charsToDelete = snippet.command.count
                
                currentInputBuffer = String(currentInputBuffer.dropLast(charsToDelete))
                
                #if DEBUG
                print("[TextReplacementService] ✅ Found matching suffix command: '\(snippet.command)'")
                
                if snippet.content.contains("{") && snippet.content.contains("}") {
                    print("[TextReplacementService] 🔍 Content contains special keywords that will be processed")
                }
                #endif
                
                deleteLastCharacters(count: charsToDelete)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.insertText(snippet.content)
                    // Track usage when replacement happens
                    UsageTracker.shared.recordUsage(for: snippet.id)
                    print("[TextReplacementService] 📊 Recorded usage for snippet: \(snippet.command)")
                }
                return
            }
        }
    }
    
    private func deleteLastCharacters(count: Int) {
        guard count > 0 else { return }
        
        let source = cachedEventSource ?? CGEventSource(stateID: .hidSystemState)
        
        guard let deleteEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true) else {
            return
        }
        deleteEvent.flags = .maskNonCoalesced
        
        if count <= 3 {
            for _ in 0..<count {
                deleteEvent.post(tap: .cghidEventTap)
                usleep(700)
            }
        } else if count <= 10 {
            let batchSize = 2
            let batches = count / batchSize
            let remainder = count % batchSize
            
            for _ in 0..<batches {
                for _ in 0..<batchSize {
                    deleteEvent.post(tap: .cghidEventTap)
                    usleep(700)
                }
                usleep(200)
            }
            
            for _ in 0..<remainder {
                deleteEvent.post(tap: .cghidEventTap)
                usleep(700)
            }
        } else {
            let batchSize = 4
            let batches = count / batchSize
            let remainder = count % batchSize
            
            for _ in 0..<batches {
                for _ in 0..<batchSize {
                    deleteEvent.post(tap: .cghidEventTap)
                    usleep(700)
                }
                usleep(300)
            }
            
            for _ in 0..<remainder {
                deleteEvent.post(tap: .cghidEventTap)
                usleep(700)
            }
        }
        
        if let deleteUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
            deleteUpEvent.flags = .maskNonCoalesced
            deleteUpEvent.post(tap: .cghidEventTap)
        }
    }
    
    private func insertText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // First find cursor position marker in the original text
        var processedText = text
        var cursorPosition: Int? = nil
        
        // Process special keywords while tracking cursor position
        processedText = processSpecialKeywordsWithCursor(processedText, cursorPosition: &cursorPosition)
        
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)
        
        // Clear and set new content
        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)
        
        // Perform paste
        if let source = CGEventSource(stateID: .hidSystemState) {
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
               let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
               let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
               let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
                
                cmdDown.flags = [.maskCommand, .maskNonCoalesced]
                vDown.flags = [.maskCommand, .maskNonCoalesced]
                vUp.flags = [.maskCommand, .maskNonCoalesced]
                cmdUp.flags = .maskNonCoalesced
                
                // Execute paste command with minimal delays
                cmdDown.post(tap: .cghidEventTap)
                usleep(800)
                vDown.post(tap: .cghidEventTap)
                usleep(800)
                vUp.post(tap: .cghidEventTap)
                usleep(800)
                cmdUp.post(tap: .cghidEventTap)
                
                // If cursor position is specified, move cursor to that position after paste is complete
                if let position = cursorPosition {
                    #if DEBUG
                    print("[TextReplacementService] 📍 Will move cursor to position: \(position)")
                    #endif
                    
                    // Wait for paste to complete before moving cursor
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Use a more reliable approach for cursor positioning that works in most applications
                        self.universalCursorPositioning(source: source, position: position, textLength: processedText.count)
                        
                        // Restore clipboard after cursor positioning
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            pasteboard.clearContents()
                            if let previous = previousContent {
                                pasteboard.setString(previous, forType: .string)
                            }
                        }
                    }
                } else {
                    // No cursor position specified, just restore clipboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pasteboard.clearContents()
                        if let previous = previousContent {
                            pasteboard.setString(previous, forType: .string)
                        }
                    }
                }
            }
        }
    }
    
    // Universal cursor positioning method that works in most applications
    private func universalCursorPositioning(source: CGEventSource, position: Int, textLength: Int) {
        guard position > 0 && position <= textLength else { return }
        
        #if DEBUG
        print("[TextReplacementService] 🎯 Using universal cursor positioning to position \(position) in text of length \(textLength)")
        #endif
        
        // First, try to position using left arrow from the end (default paste position)
        // This works better when text is inserted in the middle of existing content
        // as it doesn't disrupt the surrounding text
        
        // Most applications will place cursor at the end of pasted text
        // So we need to move left by (length - position) characters
        let leftMovements = textLength - position
        
        if leftMovements > 0 {
            // For reliability, do this in small batches with pauses
            let batchSize = 10
            let batches = leftMovements / batchSize
            let remainder = leftMovements % batchSize
            
            if let leftDown = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: true),
               let leftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: false) {
                
                leftDown.flags = .maskNonCoalesced
                leftUp.flags = .maskNonCoalesced
                
                // Move in batches for better reliability
                for _ in 0..<batches {
                    for _ in 0..<batchSize {
                        leftDown.post(tap: .cghidEventTap)
                        usleep(400)
                        leftUp.post(tap: .cghidEventTap)
                        usleep(400)
                    }
                    // Small pause between batches
                    usleep(1000)
                }
                
                // Handle remaining movements
                for _ in 0..<remainder {
                    leftDown.post(tap: .cghidEventTap)
                    usleep(400)
                    leftUp.post(tap: .cghidEventTap)
                    usleep(400)
                }
            }
        }
    }
    
    // New method to process keywords while tracking cursor position
    private func processSpecialKeywordsWithCursor(_ text: String, cursorPosition: inout Int?) -> String {
        var processedText = text
        
        // Check if text contains any special keywords
        if !text.contains("{") || !text.contains("}") {
            return text
        }
        
        #if DEBUG
        print("[TextReplacementService] 🔄 Processing special keywords in text with cursor tracking")
        if let pos = cursorPosition {
            print("[TextReplacementService] 📍 Initial cursor position: \(pos)")
        }
        #endif
        
        // Regular expression to find keywords in curly braces
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            #if DEBUG
            print("[TextReplacementService] ⚠️ Failed to create regex for special keywords")
            #endif
            return text
        }
        
        // Find all matches
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // Process matches in reverse order to avoid range issues
        for match in matches.reversed() {
            guard let range = Range(match.range, in: processedText) else { continue }
            let keyword = String(processedText[range])
            let keywordStartPos = processedText.distance(from: processedText.startIndex, to: range.lowerBound)
            let keywordLength = keyword.count
            
            // Get the keyword without braces
            let cleanKeyword = String(keyword.dropFirst().dropLast())
            
            #if DEBUG
            print("[TextReplacementService] 🔑 Processing keyword: \(cleanKeyword) at position \(keywordStartPos)")
            #endif
            
            // Skip cursor keyword as it's handled separately
            if cleanKeyword == "cursor" {
                // Store cursor position and remove the {cursor} marker
                cursorPosition = keywordStartPos
                processedText = processedText.replacingOccurrences(of: keyword, with: "", range: range)
                
                #if DEBUG
                print("[TextReplacementService] 📍 Setting cursor position to: \(keywordStartPos)")
                #endif
                continue
            }
            
            // Replace with appropriate value based on keyword
            let replacement = processKeyword(cleanKeyword)
            
            // Check if this replacement affects cursor position
            if let currentCursorPos = cursorPosition {
                if keywordStartPos <= currentCursorPos {
                    // Calculate cursor position adjustment
                    let lengthDifference = replacement.count - keywordLength
                    cursorPosition = currentCursorPos + lengthDifference
                    
                    #if DEBUG
                    print("[TextReplacementService] 📏 Adjusting cursor position: \(currentCursorPos) → \(cursorPosition!)")
                    print("[TextReplacementService] 📊 Keyword length: \(keywordLength), Replacement length: \(replacement.count), Difference: \(lengthDifference)")
                    #endif
                }
            }
            
            // Replace in the text
            processedText = processedText.replacingOccurrences(of: keyword, with: replacement, range: range)
        }
        
        #if DEBUG
        if let finalPos = cursorPosition {
            print("[TextReplacementService] 📍 Final cursor position: \(finalPos)")
        }
        #endif
        
        return processedText
    }
    
    // Helper function to process individual keywords
    private func processKeyword(_ keyword: String) -> String {
        switch keyword.lowercased() {
        case "clipboard":
            return NSPasteboard.general.string(forType: .string) ?? ""
        case "random-number":
            return "\(Int.random(in: 1...1000))"
        case "dd/mm":
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: Date())
        case "dd/mm/yyyy":
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: Date())
        case "time":
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: Date())
        case "uuid":
            return UUID().uuidString
        case "timestamp":
            return "\(Int(Date().timeIntervalSince1970))"
        default:
            return "{\(keyword)}"
        }
    }
    
    private func processSpecialKeywords(_ text: String) -> String {
        var dummyCursorPos: Int? = nil
        return processSpecialKeywordsWithCursor(text, cursorPosition: &dummyCursorPos)
    }
    
    func startMonitoring() {
        guard !isMonitoring else {
            print("[TextReplacementService] Already monitoring")
            return
        }
        
        isMonitoring = true
        lastCharHandled = ""
        lastKeyCode = 0
        lastKeyTime = 0
        currentInputBuffer = ""
        resetBufferClearTimer()
        setupKeyMonitor()
        print("[TextReplacementService] Started monitoring")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        
        // Clear the buffer timer
        bufferClearTimer?.invalidate()
        bufferClearTimer = nil
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        selfReference?.release()
        selfReference = nil
        
        eventTap = nil
        runLoopSource = nil
        currentInputBuffer = ""
        lastCharHandled = ""
        lastKeyCode = 0
        lastKeyTime = 0
        print("[TextReplacementService] Stopped monitoring")
    }
    
    func updateSnippets(_ snippets: [Snippet]) {
        var snippetDict = [String: String]()
        for snippet in snippets {
            snippetDict[snippet.command] = snippet.content
        }
        
        self.snippets = snippets
        self.snippetLookup = snippetDict
        
        self.sortedSnippetsCache = []
        self.snippetsLastUpdated = Date()
        
        print("[TextReplacementService] Updated snippets: \(snippets.count) items")
        if snippets.count < 10 {
            print("[TextReplacementService] Available commands: \(snippets.map { $0.command }.joined(separator: ", "))")
        } else {
            print("[TextReplacementService] Updated \(snippets.count) commands")
        }
    }
    
    func replaceText(in text: String) -> String {
        var result = text
        
        let sortedSnippets: [Snippet]
        if Date().timeIntervalSince(snippetsLastUpdated) < 1.0 && !sortedSnippetsCache.isEmpty {
            sortedSnippets = sortedSnippetsCache
        } else {
            sortedSnippets = snippets.sorted { $0.command.count > $1.command.count }
            sortedSnippetsCache = sortedSnippets
            snippetsLastUpdated = Date()
        }
        
        for snippet in sortedSnippets {
            if result.contains(snippet.command) {
                // Process special keywords in the snippet content before replacing
                let processedContent = processSpecialKeywords(snippet.content)
                result = result.replacingOccurrences(of: snippet.command, with: processedContent)
                
                // Track usage
                UsageTracker.shared.recordUsage(for: snippet.id)
                
                #if DEBUG
                print("[TextReplacementService] Replaced command: \(snippet.command) with processed content")
                #endif
            }
        }
        
        return result
    }
    
    func containsCommand(_ text: String) -> Bool {
        if text.isEmpty || snippets.isEmpty {
            return false
        }
        
        // Only check if the text ends with a snippet command
        // This prevents false positives where any character that happens to be
        // part of a snippet command gets incorrectly flagged
        for (command, _) in snippetLookup {
            if text.count < command.count {
                continue
            }
            
            if text.hasSuffix(command) {
                #if DEBUG
                print("[TextReplacementService] Found command suffix: \(command) in text")
                #endif
                return true
            }
        }
        
        return false
    }
    
    func getContentForCommand(_ command: String) -> String? {
        if let content = snippetLookup[command] {
            // Process special keywords in the content before returning
            let processedContent = processSpecialKeywords(content)
            #if DEBUG
            print("[TextReplacementService] Found processed content for command: \(command)")
            #endif
            return processedContent
        }
        
        #if DEBUG
        print("[TextReplacementService] No content found for command: \(command)")
        #endif
        return nil
    }
    
    func processTextInput(_ text: String) -> String? {
        #if DEBUG
        print("[TextReplacementService] Processing text input: \(text)")
        #endif
        
        for (command, content) in snippetLookup {
            if text.hasSuffix(command) {
                let prefixText = text.dropLast(command.count)
                // Process special keywords in the content
                let processedContent = processSpecialKeywords(content)
                let result = String(prefixText) + processedContent
                #if DEBUG
                print("[TextReplacementService] Replaced command: \(command) with processed content")
                #endif
                return result
            }
        }
        return nil
    }
    
    func debugSnippets() {
        print("[TextReplacementService] Current snippets:")
        for snippet in snippets {
            print("  - Command: '\(snippet.command)' -> Content: '\(snippet.content)'")
        }
    }
    
    // Direct snippet insertion for SearchView selection
    func insertSnippetDirectly(_ snippet: Snippet) {
        print("[TextReplacementService] 🎯 Inserting snippet directly: \(snippet.command)")
        
        // Process the snippet content with placeholder handling
        let processedContent = processSnippetWithPlaceholders(snippet.content)
        
        // Track usage
        UsageTracker.shared.recordUsage(for: snippet.id)
        print("[TextReplacementService] 📊 Recorded usage for snippet: \(snippet.command)")
        
        // Insert the processed text
        insertText(processedContent)
    }
    
    // Process snippet content with interactive placeholder handling
    private func processSnippetWithPlaceholders(_ content: String) -> String {
        // Check if content has placeholders in the format [[placeholder:default]]
        let placeholderPattern = "\\[\\[([^:]+):([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern, options: []) else {
            // No placeholders, process normal keywords
            return processSpecialKeywords(content)
        }
        
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
        
        if matches.isEmpty {
            // No placeholders, process normal keywords
            return processSpecialKeywords(content)
        }
        
        // Collect all placeholders
        var placeholders: [(name: String, defaultValue: String, range: NSRange)] = []
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: content),
               let defaultRange = Range(match.range(at: 2), in: content) {
                let name = String(content[nameRange])
                let defaultValue = String(content[defaultRange])
                placeholders.append((name: name, defaultValue: defaultValue, range: match.range))
            }
        }
        
        // For now, replace with default values
        // In future, we can show a dialog to get user input
        var result = content
        for placeholder in placeholders.reversed() {
            if let range = Range(placeholder.range, in: result) {
                result = result.replacingCharacters(in: range, with: placeholder.defaultValue)
            }
        }
        
        // Process any remaining special keywords
        return processSpecialKeywords(result)
    }
} 