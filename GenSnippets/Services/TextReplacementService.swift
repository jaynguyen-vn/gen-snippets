import Foundation
import Combine
import AppKit
import Carbon
import CoreGraphics

// Trie node for efficient snippet lookup
class TrieNode {
    var children: [Character: TrieNode] = [:]
    var snippet: Snippet?
    
    func insert(command: String, snippet: Snippet) {
        var currentNode = self
        for char in command {
            if currentNode.children[char] == nil {
                currentNode.children[char] = TrieNode()
            }
            currentNode = currentNode.children[char]!
        }
        currentNode.snippet = snippet
    }
    
    func findMatchingSuffix(in text: String) -> Snippet? {
        // Check all possible suffixes of the text
        for startIndex in text.indices {
            let suffix = String(text[startIndex...])
            if let snippet = search(command: suffix) {
                // Verify it's actually a suffix match
                if text.hasSuffix(snippet.command) {
                    return snippet
                }
            }
        }
        return nil
    }
    
    private func search(command: String) -> Snippet? {
        var currentNode = self
        for char in command {
            guard let nextNode = currentNode.children[char] else {
                return nil
            }
            currentNode = nextNode
        }
        return currentNode.snippet
    }
}

class TextReplacementService {
    static let shared = TextReplacementService()
    
    private var snippets: [Snippet] = []
    private var snippetLookup: [String: String] = [:]
    private var sortedSnippetsCache: [Snippet] = []
    private var snippetsLastUpdated: Date = Date()
    private var snippetsCacheVersion = 0
    
    // Thread safety
    private let snippetQueue = DispatchQueue(label: "com.gensnippets.snippets", attributes: .concurrent)
    private let bufferLock = NSLock() // Lock for buffer and callback state

    // Trie for efficient snippet lookup
    private var snippetTrie = TrieNode()

    // Cache compiled regex
    private static let keywordRegex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}", options: [])

    // Cached DateFormatters for performance (creating DateFormatter is expensive)
    private static let dateFormatterDDMM: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
    private static let dateFormatterDDMMYYYY: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    private var currentInputBuffer = ""
    private let maxBufferSize = 50 // Reduced to prevent memory accumulation
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var deadKeyState: UInt32 = 0
    private weak var weakSelf: TextReplacementService?
    private var selfReference: Unmanaged<TextReplacementService>? // Keep for callback compatibility
    private var lastKeyTime: TimeInterval = 0
    private var lastKeyCode: CGKeyCode = 0
    private var lastCharHandled: String = ""
    private var bufferClearTimer: Timer?
    private let bufferInactivityTimeout: TimeInterval = 15.0 // Clear buffer after 15 seconds of inactivity
    private var eventTapCheckTimer: Timer?
    private var eventTapDisabledCount = 0
    private var lastDisabledTime: Date?
    private var callbackExecutionTimes: [TimeInterval] = []
    private let maxExecutionTimesCount = 50 // Limit array size to prevent memory growth
    
    private var cachedEventSource: CGEventSource?
    
    private init() {
        cachedEventSource = CGEventSource(stateID: .hidSystemState)

        // Use weak self in publisher to avoid retain cycles
        NotificationCenter.default.publisher(for: NSNotification.Name("SnippetsUpdated"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let snippets = notification.object as? [Snippet] {
                    self.updateSnippets(snippets)
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Capture timer references before cleanup to avoid sync deadlock
        let bufferTimer = bufferClearTimer
        let eventTapTimer = eventTapCheckTimer

        // Clear our references first
        bufferClearTimer = nil
        eventTapCheckTimer = nil

        // Invalidate timers on main thread without blocking
        // This is safe because Timer retains itself until invalidated
        if Thread.isMainThread {
            bufferTimer?.invalidate()
            eventTapTimer?.invalidate()
        } else {
            DispatchQueue.main.async {
                bufferTimer?.invalidate()
                eventTapTimer?.invalidate()
            }
        }

        stopMonitoring()

        // Clean up retain cycle - already handled in stopMonitoring
        weakSelf = nil

        // Cancel all Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Clear all cached data
        cachedEventSource = nil
        sortedSnippetsCache.removeAll()
        snippets.removeAll()
        snippetLookup.removeAll()
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

        weakSelf = self
        selfReference = Unmanaged.passRetained(self)
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                
                let service = Unmanaged<TextReplacementService>.fromOpaque(refcon).takeUnretainedValue()
                
                // Handle event tap being disabled by system
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    service.eventTapDisabledCount += 1
                    service.lastDisabledTime = Date()
                    let disabledType = type == .tapDisabledByTimeout ? "TIMEOUT" : "USER_INPUT"
                    print("[TextReplacementService] 🔴 Event tap disabled by \(disabledType)! Count: \(service.eventTapDisabledCount), Time: \(Date())")
                    
                    // Log average callback execution time
                    if !service.callbackExecutionTimes.isEmpty {
                        let avgTime = service.callbackExecutionTimes.reduce(0, +) / Double(service.callbackExecutionTimes.count)
                        print("[TextReplacementService] ⏱️ Avg callback time: \(String(format: "%.3f", avgTime * 1000))ms")
                        service.callbackExecutionTimes.removeAll()
                    }
                    
                    CGEvent.tapEnable(tap: service.eventTap!, enable: true)
                    print("[TextReplacementService] ✅ Event tap re-enabled")
                    return Unmanaged.passUnretained(event)
                }
                
                if type == .keyDown {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    defer {
                        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                        service.callbackExecutionTimes.append(executionTime)
                        if service.callbackExecutionTimes.count > service.maxExecutionTimesCount {
                            service.callbackExecutionTimes.removeFirst(service.callbackExecutionTimes.count - service.maxExecutionTimesCount)
                        }
                        if executionTime > 0.01 { // Log if takes more than 10ms
                            print("[TextReplacementService] ⚠️ Slow callback: \(String(format: "%.3f", executionTime * 1000))ms")
                        }
                    }
                    
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    if flags.contains(.maskCommand) || flags.contains(.maskControl) {
                        return Unmanaged.passUnretained(event)
                    }
                    
                    if keyCode == 0x33 {
                        if !service.currentInputBuffer.isEmpty {
                            service.currentInputBuffer.removeLast()
                            if service.currentInputBuffer.count >= 2 {
                                service.checkForCommands()
                            }
                        }
                        return Unmanaged.passUnretained(event)
                    }
                    
                    // Prevent duplicate key processing by checking time and key code
                    let currentTime = CFAbsoluteTimeGetCurrent()
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
                                return Unmanaged.passUnretained(event)
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
                
                return Unmanaged.passUnretained(event)
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
        
        // Start timer to check if event tap is still enabled
        startEventTapCheckTimer()
    }
    
    private func startEventTapCheckTimer() {
        // Ensure timer operations happen on main thread
        let setupTimer = { [weak self] in
            self?.eventTapCheckTimer?.invalidate()
            self?.eventTapCheckTimer = nil

            // Increased interval to reduce overhead (from 5s to 10s)
            self?.eventTapCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.checkAndReenableEventTap()

                // Periodically clear accumulated monitoring data
                if let self = self, self.callbackExecutionTimes.count > self.maxExecutionTimesCount / 2 {
                    self.callbackExecutionTimes.removeAll(keepingCapacity: true)
                    #if DEBUG
                    print("[TextReplacementService] 🧹 Cleared callback execution times")
                    #endif
                }
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
    
    private func checkAndReenableEventTap() {
        guard let eventTap = eventTap else { return }

        let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)

        // Only log if there's an issue
        if !isEnabled || eventTapDisabledCount > 0 {
            print("[TextReplacementService] 🔍 Periodic check - Tap enabled: \(isEnabled), Disabled count: \(eventTapDisabledCount)")

            if let lastDisabled = lastDisabledTime {
                print("[TextReplacementService] 📊 Last disabled: \(lastDisabled.timeIntervalSinceNow * -1)s ago")
            }
        }

        if !isEnabled {
            print("[TextReplacementService] 🔴 Event tap found disabled in periodic check!")
            CGEvent.tapEnable(tap: eventTap, enable: true)

            // If re-enabling fails multiple times, recreate the event tap with exponential backoff
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                eventTapDisabledCount += 1

                if eventTapDisabledCount > 3 {
                    print("[TextReplacementService] ❌ Event tap failed \(eventTapDisabledCount) times, recreating with backoff...")
                    let backoffDelay = min(Double(eventTapDisabledCount) * 0.5, 5.0) // Max 5 second delay

                    stopMonitoring()
                    DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) { [weak self] in
                        self?.eventTapDisabledCount = 0 // Reset counter after recreation
                        self?.startMonitoring()
                    }
                } else {
                    print("[TextReplacementService] ⚠️ Failed to re-enable tap (attempt \(eventTapDisabledCount))")
                }
            } else {
                print("[TextReplacementService] ✅ Event tap re-enabled successfully")
                // Reset counter on successful re-enable
                if eventTapDisabledCount > 0 {
                    eventTapDisabledCount = 0
                }
            }
        } else {
            // Reset counter if tap is working fine
            if eventTapDisabledCount > 0 {
                eventTapDisabledCount = 0
            }
        }
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
                // Keep only recent characters to prevent memory accumulation
                let keepCount = maxBufferSize / 2
                currentInputBuffer = String(currentInputBuffer.suffix(keepCount))
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
        // Create timer setup closure
        let createTimer = { [weak self] in
            guard let self = self else { return }

            // Invalidate existing timer
            self.bufferClearTimer?.invalidate()
            self.bufferClearTimer = nil

            self.bufferClearTimer = Timer.scheduledTimer(withTimeInterval: self.bufferInactivityTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                #if DEBUG
                if !self.currentInputBuffer.isEmpty {
                    print("[TextReplacementService] 🧹 Clearing buffer due to inactivity: '\(self.currentInputBuffer)'")
                }
                #endif

                self.currentInputBuffer = ""
            }
        }

        // Always use async to avoid potential deadlocks
        if Thread.isMainThread {
            createTimer()
        } else {
            DispatchQueue.main.async {
                createTimer()
            }
        }
    }
    
    private func checkForCommands() {
        // Early exit if buffer is too small to contain any commands
        guard currentInputBuffer.count >= 2 else { return }

        // Use cached sorted snippets if available
        let sortedSnippets = snippetQueue.sync {
            return sortedSnippetsCache.isEmpty ? snippets.sorted { $0.command.count > $1.command.count } : sortedSnippetsCache
        }

        // Early exit if no snippets
        guard !sortedSnippets.isEmpty else { return }

        // Only check snippets that could possibly match based on buffer size
        for snippet in sortedSnippets {
            // Skip if buffer is too small for this command
            if currentInputBuffer.count < snippet.command.count {
                continue
            }

            // Optimize: only check suffix if last character matches
            if let lastChar = snippet.command.last,
               let bufferLastChar = currentInputBuffer.last,
               lastChar != bufferLastChar {
                continue
            }

            // Check if buffer ends with the snippet command
            if currentInputBuffer.hasSuffix(snippet.command) {
                let charsToDelete = snippet.command.count

                currentInputBuffer = String(currentInputBuffer.dropLast(charsToDelete))

                #if DEBUG
                print("[TextReplacementService] ✅ Found matching suffix command: '\(snippet.command)'")
                #endif

                deleteLastCharacters(count: charsToDelete)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.insertText(snippet.content)
                    // Track usage when replacement happens (by command, not ID)
                    UsageTracker.shared.recordUsage(for: snippet.command)
                    #if DEBUG
                    print("[TextReplacementService] 📊 Recorded usage for snippet: \(snippet.command)")
                    #endif
                }
                return // Exit early once a match is found
            }
        }
    }
    
    private func deleteLastCharacters(count: Int) {
        guard count > 0 else { return }

        let source = cachedEventSource ?? CGEventSource(stateID: .hidSystemState)

        guard let deleteDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
              let deleteUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) else {
            return
        }

        deleteDown.flags = .maskNonCoalesced
        deleteUp.flags = .maskNonCoalesced

        // Get timing configuration for current app
        let timingConfig = getTimingForCurrentApp()

        #if DEBUG
        print("[TextReplacementService] ⏱️ Using deletion delay: \(timingConfig.deletion * 1000)ms, simple: \(timingConfig.useSimple)")
        #endif

        // Apps that need simple, individual deletes (no selection)
        if timingConfig.useSimple {
            // Always use individual deletes with proper timing
            for _ in 0..<count {
                deleteDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion)
                deleteUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion)
            }
            return
        }

        // Non-app specific: use optimized deletion with configured timing
        if count <= 3 {
            // Small count: individual deletes with configured delay
            for _ in 0..<count {
                deleteDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion)
                deleteUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion)
            }
        } else if count <= 10 {
            // Medium count: batch deletes
            for _ in 0..<count {
                deleteDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion * 0.6) // Slightly faster for batch
                deleteUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: timingConfig.deletion * 0.6)
            }
        } else {
            // Large count: select all and delete
            // First, select the text to delete (Shift + Left Arrow)
            if let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true), // Shift
               let leftArrow = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: true), // Left arrow
               let leftArrowUp = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: false),
               let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) {

                shiftDown.flags = [.maskShift, .maskNonCoalesced]

                // Hold shift and press left arrow multiple times
                shiftDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.001)

                for _ in 0..<count {
                    leftArrow.flags = [.maskShift, .maskNonCoalesced]
                    leftArrowUp.flags = [.maskShift, .maskNonCoalesced]

                    leftArrow.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.0002)
                    leftArrowUp.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.0002)
                }

                shiftUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.001)

                // Now delete the selected text
                deleteDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.001)
                deleteUp.post(tap: .cghidEventTap)
            } else {
                // Fallback to individual deletes
                for _ in 0..<count {
                    deleteDown.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.0005)
                    deleteUp.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.0005)
                }
            }
        }
    }
    
    private func isWebBrowser() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        let browserBundleIDs = [
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "com.opera.Opera",
            "com.vivaldi.Vivaldi",
            "com.coccoc.Coccoc"  // Cốc Cốc browser
        ]

        #if DEBUG
        print("[TextReplacementService] Current app: \(bundleID)")
        #endif

        return browserBundleIDs.contains(bundleID)
    }

    private func isTerminalApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        let terminalBundleIDs = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "com.github.wez.wezterm",
            "io.alacritty",
            "dev.warp.Warp-Stable",
            "com.microsoft.VSCode"  // VSCode's integrated terminal
        ]

        return terminalBundleIDs.contains(bundleID)
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

        // Get timing configuration for current app
        let timingConfig = getTimingForCurrentApp()

        #if DEBUG
        print("[TextReplacementService] ⏱️ Using paste delay: \(timingConfig.paste * 1000)ms for current app")
        #endif

        // Clear and set new content
        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)

        // Perform paste with appropriate timing
        if let source = CGEventSource(stateID: .hidSystemState) {
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
               let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
               let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
               let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {

                cmdDown.flags = [.maskCommand, .maskNonCoalesced]
                vDown.flags = [.maskCommand, .maskNonCoalesced]
                vUp.flags = [.maskCommand, .maskNonCoalesced]
                cmdUp.flags = .maskNonCoalesced

                // Convert TimeInterval to useconds_t
                let delay = useconds_t(timingConfig.paste * 1_000_000)

                // Execute paste command with appropriate delays
                cmdDown.post(tap: .cghidEventTap)
                usleep(delay)
                vDown.post(tap: .cghidEventTap)
                usleep(delay)
                vUp.post(tap: .cghidEventTap)
                usleep(delay)
                cmdUp.post(tap: .cghidEventTap)

                // Extra delay for Discord and similar apps to ensure paste completes
                let extraDelay = EdgeCaseHandler.detectAppCategory() == .discord ? 5000 : 0  // 5ms extra for Discord
                if extraDelay > 0 {
                    usleep(useconds_t(extraDelay))
                }
                
                // If cursor position is specified, move cursor to that position after paste is complete
                if let position = cursorPosition {
                    #if DEBUG
                    print("[TextReplacementService] 📍 Will move cursor to position: \(position)")
                    #endif

                    // Wait for paste to complete before moving cursor (extra time for Discord)
                    let cursorDelay = EdgeCaseHandler.detectAppCategory() == .discord ? 0.3 : 0.15
                    DispatchQueue.main.asyncAfter(deadline: .now() + cursorDelay) {
                        // Use a more reliable approach for cursor positioning that works in most applications
                        self.universalCursorPositioning(source: source, position: position, textLength: processedText.count)

                        // Restore clipboard after cursor positioning (extra time for Discord)
                        let restoreDelay = EdgeCaseHandler.detectAppCategory() == .discord ? 0.25 : 0.1
                        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                            pasteboard.clearContents()
                            if let previous = previousContent {
                                pasteboard.setString(previous, forType: .string)
                            }
                        }
                    }
                } else {
                    // No cursor position specified, just restore clipboard (extra time for Discord)
                    let restoreDelay = EdgeCaseHandler.detectAppCategory() == .discord ? 0.25 : 0.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
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
        
        // Use cached regex
        guard let regex = TextReplacementService.keywordRegex else {
            #if DEBUG
            print("[TextReplacementService] ⚠️ Failed to use cached regex for special keywords")
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
            // Use cached formatter for performance
            return TextReplacementService.dateFormatterDDMM.string(from: Date())
        case "dd/mm/yyyy":
            // Use cached formatter for performance
            return TextReplacementService.dateFormatterDDMMYYYY.string(from: Date())
        case "time":
            // Use cached formatter for performance
            return TextReplacementService.timeFormatter.string(from: Date())
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

        // Capture timer references
        let bufferTimer = bufferClearTimer
        let eventTapTimer = eventTapCheckTimer

        // Clear our references
        bufferClearTimer = nil
        eventTapCheckTimer = nil

        // Invalidate timers on main thread without blocking
        let invalidateTimers = {
            bufferTimer?.invalidate()
            eventTapTimer?.invalidate()
        }

        if Thread.isMainThread {
            invalidateTimers()
        } else {
            DispatchQueue.main.async {
                invalidateTimers()
            }
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        // Properly release the retain cycle
        if let selfRef = selfReference {
            selfRef.release()
            selfReference = nil
        }

        eventTap = nil
        runLoopSource = nil
        currentInputBuffer = ""
        lastCharHandled = ""
        lastKeyCode = 0
        lastKeyTime = 0

        // Clear accumulated monitoring data
        callbackExecutionTimes.removeAll()
        eventTapDisabledCount = 0
        lastDisabledTime = nil

        print("[TextReplacementService] Stopped monitoring and cleaned up resources")
    }
    
    func updateSnippets(_ snippets: [Snippet]) {
        snippetQueue.async(flags: .barrier) {
            var snippetDict = [String: String]()
            let newTrie = TrieNode()
            
            for snippet in snippets {
                snippetDict[snippet.command] = snippet.content
                newTrie.insert(command: snippet.command, snippet: snippet)
            }
            
            self.snippets = snippets
            self.snippetLookup = snippetDict
            self.snippetTrie = newTrie
            
            // Update cache with proper versioning
            self.sortedSnippetsCache = snippets.sorted { $0.command.count > $1.command.count }
            self.snippetsLastUpdated = Date()
            self.snippetsCacheVersion += 1
        }
        
        print("[TextReplacementService] Updated snippets: \(snippets.count) items")
        if snippets.count < 10 {
            print("[TextReplacementService] Available commands: \(snippets.map { $0.command }.joined(separator: ", "))")
        } else {
            print("[TextReplacementService] Updated \(snippets.count) commands")
        }
    }
    
    func replaceText(in text: String) -> String {
        var result = text
        
        let sortedSnippets = snippetQueue.sync {
            return sortedSnippetsCache.isEmpty ? snippets.sorted { $0.command.count > $1.command.count } : sortedSnippetsCache
        }
        
        for snippet in sortedSnippets {
            if result.contains(snippet.command) {
                // Process special keywords in the snippet content before replacing
                let processedContent = processSpecialKeywords(snippet.content)
                result = result.replacingOccurrences(of: snippet.command, with: processedContent)

                // Track usage (by command, not ID)
                UsageTracker.shared.recordUsage(for: snippet.command)
                
                #if DEBUG
                print("[TextReplacementService] Replaced command: \(snippet.command) with processed content")
                #endif
            }
        }
        
        return result
    }
    
    func containsCommand(_ text: String) -> Bool {
        return snippetQueue.sync {
            if text.isEmpty || snippets.isEmpty {
                return false
            }
            
            // Use Trie for more efficient suffix checking
            return snippetTrie.findMatchingSuffix(in: text) != nil
        }
    }
    
    func getContentForCommand(_ command: String) -> String? {
        return snippetQueue.sync {
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
    }
    
    func processTextInput(_ text: String) -> String? {
        #if DEBUG
        print("[TextReplacementService] Processing text input: \(text)")
        #endif
        
        return snippetQueue.sync {
            // Use Trie for efficient lookup
            if let snippet = snippetTrie.findMatchingSuffix(in: text) {
                let prefixText = text.dropLast(snippet.command.count)
                // Process special keywords in the content
                let processedContent = processSpecialKeywords(snippet.content)
                let result = String(prefixText) + processedContent
                #if DEBUG
                print("[TextReplacementService] Replaced command: \(snippet.command) with processed content")
                #endif
                return result
            }
            return nil
        }
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

        // Track usage (by command, not ID)
        UsageTracker.shared.recordUsage(for: snippet.command)
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