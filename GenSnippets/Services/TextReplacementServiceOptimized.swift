import Foundation
import Combine
import AppKit
import Carbon
import CoreGraphics
import os.log

// MARK: - Optimized Trie with Reverse Index for O(m) suffix matching
final class OptimizedTrieNode {
    private var children: [Character: OptimizedTrieNode] = [:]
    private var snippet: Snippet?
    private let lock = NSLock()

    func insert(command: String, snippet: Snippet) {
        lock.lock()
        defer { lock.unlock() }

        var currentNode = self
        for char in command {
            if currentNode.children[char] == nil {
                currentNode.children[char] = OptimizedTrieNode()
            }
            currentNode = currentNode.children[char]!
        }
        currentNode.snippet = snippet
    }

    func search(command: String) -> Snippet? {
        lock.lock()
        defer { lock.unlock() }

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

// MARK: - Thread-Safe Snippet Manager using Actor pattern
actor SnippetManager {
    private var snippets: [Snippet] = []
    private var trie = OptimizedTrieNode()
    private var reverseTrie = OptimizedTrieNode() // For suffix matching
    private var sortedCommands: [String] = []
    private let logger = Logger(subsystem: "com.gensnippets", category: "SnippetManager")

    func updateSnippets(_ newSnippets: [Snippet]) {
        snippets = newSnippets

        // Rebuild tries
        trie = OptimizedTrieNode()
        reverseTrie = OptimizedTrieNode()

        for snippet in snippets {
            trie.insert(command: snippet.command, snippet: snippet)
            // Insert reversed command for suffix matching
            reverseTrie.insert(command: String(snippet.command.reversed()), snippet: snippet)
        }

        // Pre-sort commands by length for efficiency
        sortedCommands = snippets.map { $0.command }.sorted { $0.count > $1.count }

        logger.info("Updated snippets: \(newSnippets.count) items")
    }

    func findMatchingSuffix(in buffer: String) -> Snippet? {
        guard !buffer.isEmpty else { return nil }

        // Check from longest to shortest commands for exact suffix match
        for command in sortedCommands {
            if command.count <= buffer.count && buffer.hasSuffix(command) {
                return snippets.first { $0.command == command }
            }
        }

        return nil
    }

    func getSnippets() -> [Snippet] {
        return snippets
    }
}

// MARK: - Optimized Text Replacement Service
final class TextReplacementServiceOptimized {
    static let shared = TextReplacementServiceOptimized()

    // Actor for thread-safe snippet management
    private let snippetManager = SnippetManager()

    // Logging
    private let logger = Logger(subsystem: "com.gensnippets", category: "TextReplacement")

    // Event handling
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var selfReference: TextReplacementServiceOptimized?

    // Buffer management
    private let bufferQueue = DispatchQueue(label: "com.gensnippets.buffer", qos: .userInteractive)
    private var inputBuffer = ""
    private let maxBufferSize = 100
    private var bufferResetWorkItem: DispatchWorkItem?
    private let bufferTimeout: TimeInterval = 15.0

    // Performance monitoring
    private var lastKeyTime: CFAbsoluteTime = 0
    private var lastKeyCode: CGKeyCode = 0
    private var isProcessingReplacement = false

    // Event tap monitoring
    private var eventTapMonitor: DispatchSourceTimer?
    private var consecutiveFailures = 0
    private let maxFailures = 3

    // Cached event source for performance
    private let eventSource: CGEventSource? = CGEventSource(stateID: .hidSystemState)

    // Unicode normalization
    private let normalizer = StringNormalizer()

    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false

    private init() {
        setupNotifications()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SnippetsUpdated"))
            .compactMap { $0.object as? [Snippet] }
            .sink { [weak self] snippets in
                Task {
                    await self?.snippetManager.updateSnippets(snippets)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else {
            logger.info("Already monitoring")
            return
        }

        guard AXIsProcessTrusted() else {
            logger.error("Missing accessibility permissions")
            requestAccessibilityPermissions()
            return
        }

        isMonitoring = true
        setupEventTap()
        startEventTapMonitor()

        logger.info("Started monitoring")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        // Cancel buffer reset
        bufferResetWorkItem?.cancel()
        bufferResetWorkItem = nil

        // Stop event tap monitor
        eventTapMonitor?.cancel()
        eventTapMonitor = nil

        // Disable and remove event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        // Clear buffer
        bufferQueue.sync {
            inputBuffer = ""
        }

        logger.info("Stopped monitoring")
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        // Store weak reference for callback
        selfReference = self

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: TextReplacementServiceOptimized.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            logger.error("Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)

        logger.info("Event tap setup complete")
    }

    // MARK: - Event Tap Callback

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<TextReplacementServiceOptimized>.fromOpaque(userInfo).takeUnretainedValue()

        // Handle tap being disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            service.handleEventTapDisabled(type: type)
            return Unmanaged.passUnretained(event)
        }

        // Process key down events
        if type == .keyDown {
            return service.processKeyEvent(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func processKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent> {
        // Skip if we're in the middle of a replacement
        guard !isProcessingReplacement else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Skip modifier keys
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            return Unmanaged.passUnretained(event)
        }

        // Get current time for duplicate detection
        let currentTime = CFAbsoluteTimeGetCurrent()

        // Detect and skip duplicate keys (common with IMEs)
        if currentTime - lastKeyTime < 0.005 && CGKeyCode(keyCode) == lastKeyCode {
            return Unmanaged.passUnretained(event)
        }

        lastKeyTime = currentTime
        lastKeyCode = CGKeyCode(keyCode)

        // Handle backspace
        if keyCode == 0x33 {
            handleBackspace()
            return Unmanaged.passUnretained(event)
        }

        // Get character from event
        if let character = extractCharacter(from: event, keyCode: CGKeyCode(keyCode)) {
            handleCharacterInput(character)

            // Check if we should suppress this key (if it completes a snippet)
            if shouldSuppressKey(character) {
                return Unmanaged.passUnretained(event) // Could return nil to suppress
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Character Extraction

    private func extractCharacter(from event: CGEvent, keyCode: CGKeyCode) -> String? {
        // Try NSEvent first (better for IMEs)
        if let nsEvent = NSEvent(cgEvent: event),
           let characters = nsEvent.charactersIgnoringModifiers,
           !characters.isEmpty {
            return normalizer.normalize(characters)
        }

        // Fallback to UCKeyTranslate
        var chars: [UniChar] = [0, 0, 0, 0]
        var length = 0
        var deadKeyState: UInt32 = 0

        let keyboard = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()

        guard let layoutData = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else {
            return nil
        }

        let string = String(utf16CodeUnits: chars, count: length)
        return normalizer.normalize(string)
    }

    // MARK: - Input Handling

    private func handleBackspace() {
        bufferQueue.async { [weak self] in
            guard let self = self, !self.inputBuffer.isEmpty else { return }

            self.inputBuffer.removeLast()
            self.resetBufferTimer()

            Task {
                await self.checkForSnippetMatch()
            }
        }
    }

    private func handleCharacterInput(_ character: String) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }

            // Maintain buffer size limit
            if self.inputBuffer.count >= self.maxBufferSize {
                let dropCount = self.inputBuffer.count - self.maxBufferSize + 1
                self.inputBuffer.removeFirst(dropCount)
            }

            self.inputBuffer.append(character)
            self.resetBufferTimer()

            self.logger.debug("Buffer: '\(self.inputBuffer)'")

            Task {
                await self.checkForSnippetMatch()
            }
        }
    }

    private func shouldSuppressKey(_ character: String) -> Bool {
        // Check if this character completes a snippet command
        return false // For now, don't suppress keys
    }

    // MARK: - Snippet Matching

    private func checkForSnippetMatch() async {
        let buffer = bufferQueue.sync { inputBuffer }

        guard let snippet = await snippetManager.findMatchingSuffix(in: buffer) else {
            return
        }

        logger.info("Found match: \(snippet.command)")

        await performReplacement(snippet: snippet)
    }

    // MARK: - Text Replacement

    private func performReplacement(snippet: Snippet) async {
        isProcessingReplacement = true
        defer { isProcessingReplacement = false }

        // Update buffer
        bufferQueue.sync {
            let removeCount = min(snippet.command.count, inputBuffer.count)
            inputBuffer.removeLast(removeCount)
        }

        // Process keywords
        let processedContent = await processKeywords(in: snippet.content)

        // Perform replacement on main thread
        await MainActor.run {
            self.deleteCharacters(count: snippet.command.count)

            // Small delay for deletion to complete
            Thread.sleep(forTimeInterval: 0.05)

            self.insertText(processedContent)

            // Track usage
            UsageTracker.shared.recordUsage(for: snippet.id)
        }

        logger.info("Completed replacement for: \(snippet.command)")
    }

    private func deleteCharacters(count: Int) {
        guard count > 0, let source = eventSource else { return }

        // Create backspace events
        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {

                keyDown.flags = .maskNonCoalesced
                keyUp.flags = .maskNonCoalesced

                keyDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.001)
                keyUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
    }

    private func insertText(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Paste using Cmd+V
        if let source = eventSource,
           let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
           let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
           let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
           let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {

            cmdDown.flags = [.maskCommand, .maskNonCoalesced]
            vDown.flags = [.maskCommand, .maskNonCoalesced]
            vUp.flags = [.maskCommand, .maskNonCoalesced]
            cmdUp.flags = .maskNonCoalesced

            cmdDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002)
            vDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002)
            vUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.002)
            cmdUp.post(tap: .cghidEventTap)
        }

        // Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let previous = previousContent {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    // MARK: - Keyword Processing

    private func processKeywords(in text: String) async -> String {
        var result = text

        // Process each keyword type
        result = result.replacingOccurrences(of: "{clipboard}", with: NSPasteboard.general.string(forType: .string) ?? "")
        result = result.replacingOccurrences(of: "{timestamp}", with: "\(Int(Date().timeIntervalSince1970))")

        if result.contains("{date}") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            result = result.replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
        }

        if result.contains("{time}") {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            result = result.replacingOccurrences(of: "{time}", with: formatter.string(from: Date()))
        }

        result = result.replacingOccurrences(of: "{uuid}", with: UUID().uuidString)

        // Handle cursor positioning
        if let range = result.range(of: "{cursor}") {
            result.removeSubrange(range)
            // TODO: Implement cursor positioning
        }

        return result
    }

    // MARK: - Buffer Management

    private func resetBufferTimer() {
        bufferResetWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.bufferQueue.async {
                self?.inputBuffer = ""
                self?.logger.debug("Buffer cleared due to timeout")
            }
        }

        bufferResetWorkItem = workItem
        bufferQueue.asyncAfter(deadline: .now() + bufferTimeout, execute: workItem)
    }

    // MARK: - Event Tap Monitoring

    private func startEventTapMonitor() {
        let queue = DispatchQueue(label: "com.gensnippets.monitor", qos: .utility)

        eventTapMonitor = DispatchSource.makeTimerSource(queue: queue)
        eventTapMonitor?.schedule(deadline: .now() + 5, repeating: 5)

        eventTapMonitor?.setEventHandler { [weak self] in
            self?.checkEventTapStatus()
        }

        eventTapMonitor?.resume()
    }

    private func checkEventTapStatus() {
        guard let tap = eventTap else { return }

        if !CGEvent.tapIsEnabled(tap: tap) {
            logger.warning("Event tap disabled, attempting to re-enable")

            consecutiveFailures += 1

            if consecutiveFailures >= maxFailures {
                logger.error("Max failures reached, recreating event tap")

                DispatchQueue.main.async { [weak self] in
                    self?.stopMonitoring()
                    self?.startMonitoring()
                }

                consecutiveFailures = 0
            } else {
                CGEvent.tapEnable(tap: tap, enable: true)

                // Verify it's enabled
                if CGEvent.tapIsEnabled(tap: tap) {
                    logger.info("Event tap re-enabled successfully")
                    consecutiveFailures = 0
                }
            }
        } else {
            consecutiveFailures = 0
        }
    }

    private func handleEventTapDisabled(type: CGEventType) {
        let reason = type == .tapDisabledByTimeout ? "timeout" : "user input"
        logger.warning("Event tap disabled by \(reason)")

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.info("Attempted to re-enable event tap")
        }
    }

    // MARK: - Permissions

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Public API

    func updateSnippets(_ snippets: [Snippet]) {
        Task {
            await snippetManager.updateSnippets(snippets)
        }
    }
}

// MARK: - String Normalizer for Unicode Handling
private final class StringNormalizer {
    func normalize(_ string: String) -> String {
        // Normalize to NFC (Canonical Decomposition, followed by Canonical Composition)
        let normalized = string.precomposedStringWithCanonicalMapping

        // Remove any zero-width characters that might interfere
        let filtered = normalized.unicodeScalars.filter { scalar in
            // Keep normal characters, skip zero-width joiners, etc.
            !isZeroWidth(scalar)
        }

        return String(String.UnicodeScalarView(filtered))
    }

    private func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x200B && value <= 0x200D) || // Zero-width space, non-joiner, joiner
               (value == 0xFEFF) || // Zero-width no-break space
               (value == 0x061C) || // Arabic letter mark
               (value >= 0x202A && value <= 0x202E) || // Directional formatting
               (value >= 0x2060 && value <= 0x2064) // Word joiner, invisible separators
    }
}

// UsageTracker is already defined in SnippetUsage.swift
// This extension is not needed as the class already exists