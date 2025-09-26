import Foundation

// MARK: - Optimized Suffix Tree for O(m) matching
final class SuffixTree {
    private class Node {
        var children: [Character: Node] = [:]
        var snippets: [Snippet] = []
        let lock = NSLock()

        func addSnippet(_ snippet: Snippet) {
            lock.lock()
            defer { lock.unlock() }
            snippets.append(snippet)
        }

        func getSnippets() -> [Snippet] {
            lock.lock()
            defer { lock.unlock() }
            return snippets
        }
    }

    private let root = Node()
    private let lock = NSLock()

    func insert(_ snippet: Snippet) {
        lock.lock()
        defer { lock.unlock() }

        let command = snippet.command
        guard !command.isEmpty else { return }

        // Insert all suffixes of the command
        for i in command.indices {
            let suffix = String(command[i...])
            insertSuffix(suffix, snippet: snippet)
        }
    }

    private func insertSuffix(_ suffix: String, snippet: Snippet) {
        var currentNode = root

        for char in suffix {
            if currentNode.children[char] == nil {
                currentNode.children[char] = Node()
            }
            currentNode = currentNode.children[char]!
        }

        // Add snippet at the end of this suffix path
        currentNode.addSnippet(snippet)
    }

    func findMatchingSuffixes(in text: String) -> [Snippet] {
        lock.lock()
        defer { lock.unlock() }

        var results: [Snippet] = []
        var currentNode = root

        // Traverse the text from the end to find matching suffixes
        for char in text.reversed() {
            guard let nextNode = currentNode.children[char] else {
                break
            }
            currentNode = nextNode

            // Add all snippets found at this node
            results.append(contentsOf: currentNode.getSnippets())
        }

        // Return snippets sorted by command length (longest first)
        return results.sorted { $0.command.count > $1.command.count }
    }
}

// MARK: - Bloom Filter for Quick Negative Lookups
final class BloomFilter {
    private var bitArray: [Bool]
    private let size: Int
    private let hashCount: Int

    init(expectedElements: Int = 1000, falsePositiveRate: Double = 0.01) {
        // Calculate optimal size and hash count
        let m = Double(expectedElements) * abs(log(falsePositiveRate)) / pow(log(2), 2)
        size = Int(ceil(m))

        let k = Double(size) / Double(expectedElements) * log(2)
        hashCount = Int(ceil(k))

        bitArray = Array(repeating: false, count: size)
    }

    func add(_ string: String) {
        for i in 0..<hashCount {
            let hash = getHash(string, seed: i) % size
            bitArray[hash] = true
        }
    }

    func mightContain(_ string: String) -> Bool {
        for i in 0..<hashCount {
            let hash = getHash(string, seed: i) % size
            if !bitArray[hash] {
                return false
            }
        }
        return true
    }

    func clear() {
        bitArray = Array(repeating: false, count: size)
    }

    private func getHash(_ string: String, seed: Int) -> Int {
        var hash = seed
        for char in string.unicodeScalars {
            hash = hash &* 31 &+ Int(char.value)
        }
        return abs(hash)
    }
}

// MARK: - Optimized Snippet Matcher
final class OptimizedSnippetMatcher {
    private var suffixTree = SuffixTree()
    private var bloomFilter = BloomFilter()
    private var snippetsByCommand: [String: Snippet] = [:]
    private let queue = DispatchQueue(label: "com.gensnippets.matcher", attributes: .concurrent)

    func updateSnippets(_ snippets: [Snippet]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Clear existing data
            self.suffixTree = SuffixTree()
            self.bloomFilter.clear()
            self.snippetsByCommand.removeAll()

            // Add all snippets
            for snippet in snippets {
                self.suffixTree.insert(snippet)
                self.bloomFilter.add(snippet.command)
                self.snippetsByCommand[snippet.command] = snippet
            }

            print("[OptimizedSnippetMatcher] Updated with \(snippets.count) snippets")
        }
    }

    func findBestMatch(in buffer: String) -> Snippet? {
        return queue.sync {
            // Quick check: if buffer is shorter than any command, skip
            guard !buffer.isEmpty else { return nil }

            // Check all possible suffixes from longest to shortest
            for length in (1...min(buffer.count, 50)).reversed() {
                let startIndex = buffer.index(buffer.endIndex, offsetBy: -length)
                let suffix = String(buffer[startIndex...])

                // Quick bloom filter check
                if !bloomFilter.mightContain(suffix) {
                    continue
                }

                // Exact match check
                if let snippet = snippetsByCommand[suffix] {
                    return snippet
                }
            }

            return nil
        }
    }

    func containsPartialMatch(_ buffer: String) -> Bool {
        return queue.sync {
            guard !buffer.isEmpty else { return false }

            // Check if any snippet command starts with the current buffer suffix
            for (command, _) in snippetsByCommand {
                if command.hasPrefix(buffer) || buffer.hasSuffix(command) {
                    return true
                }
            }

            return false
        }
    }
}

// MARK: - Intelligent Buffer Manager
final class IntelligentBufferManager {
    private var buffer = ""
    private let maxSize = 100
    private let queue = DispatchQueue(label: "com.gensnippets.buffer", qos: .userInteractive)
    private var resetTimer: DispatchWorkItem?
    private let resetTimeout: TimeInterval = 15.0

    // Character frequency analysis for optimization
    private var characterFrequency: [Character: Int] = [:]

    func append(_ character: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Maintain buffer size
            if self.buffer.count >= self.maxSize {
                let dropCount = self.buffer.count - self.maxSize + character.count
                self.buffer.removeFirst(dropCount)
            }

            self.buffer.append(character)

            // Update character frequency
            for char in character {
                self.characterFrequency[char, default: 0] += 1
            }

            self.resetInactivityTimer()
        }
    }

    func removeLastCharacter() {
        queue.async { [weak self] in
            guard let self = self, !self.buffer.isEmpty else { return }

            let removed = self.buffer.removeLast()
            if let count = self.characterFrequency[removed], count > 1 {
                self.characterFrequency[removed] = count - 1
            } else {
                self.characterFrequency.removeValue(forKey: removed)
            }

            self.resetInactivityTimer()
        }
    }

    func removeSuffix(_ suffix: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if self.buffer.hasSuffix(suffix) {
                self.buffer.removeLast(suffix.count)

                // Update frequency
                for char in suffix {
                    if let count = self.characterFrequency[char], count > 1 {
                        self.characterFrequency[char] = count - 1
                    } else {
                        self.characterFrequency.removeValue(forKey: char)
                    }
                }
            }
        }
    }

    func getBuffer() -> String {
        return queue.sync { buffer }
    }

    func clear() {
        queue.async { [weak self] in
            self?.buffer = ""
            self?.characterFrequency.removeAll()
        }
    }

    private func resetInactivityTimer() {
        resetTimer?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.clear()
            print("[BufferManager] Buffer cleared due to inactivity")
        }

        resetTimer = workItem
        queue.asyncAfter(deadline: .now() + resetTimeout, execute: workItem)
    }

    func getMostFrequentCharacters(count: Int = 10) -> [Character] {
        return queue.sync {
            characterFrequency
                .sorted { $0.value > $1.value }
                .prefix(count)
                .map { $0.key }
        }
    }
}

// MARK: - Event Tap Recovery Manager
final class EventTapRecoveryManager {
    private var consecutiveFailures = 0
    private let maxFailures = 3
    private var lastFailureTime: Date?
    private let failureResetInterval: TimeInterval = 60.0
    private let queue = DispatchQueue(label: "com.gensnippets.recovery")

    enum RecoveryStrategy {
        case reenable
        case recreate
        case fallbackToAlternative
    }

    func recordFailure() -> RecoveryStrategy {
        return queue.sync {
            // Reset failure count if enough time has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > failureResetInterval {
                consecutiveFailures = 0
            }

            consecutiveFailures += 1
            lastFailureTime = Date()

            switch consecutiveFailures {
            case 1:
                return .reenable
            case 2:
                return .recreate
            default:
                consecutiveFailures = 0 // Reset after max attempts
                return .fallbackToAlternative
            }
        }
    }

    func recordSuccess() {
        queue.sync {
            consecutiveFailures = 0
            lastFailureTime = nil
        }
    }
}

// MARK: - Performance Monitor
final class PerformanceMonitor {
    private var callbackTimes: [TimeInterval] = []
    private let maxSamples = 100
    private let queue = DispatchQueue(label: "com.gensnippets.performance")

    func recordCallbackTime(_ time: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.callbackTimes.append(time)
            if self.callbackTimes.count > self.maxSamples {
                self.callbackTimes.removeFirst()
            }

            // Log if callback is slow
            if time > 0.01 {
                print("[Performance] ⚠️ Slow callback: \(String(format: "%.3f", time * 1000))ms")
            }
        }
    }

    func getAverageCallbackTime() -> TimeInterval? {
        return queue.sync {
            guard !callbackTimes.isEmpty else { return nil }
            return callbackTimes.reduce(0, +) / Double(callbackTimes.count)
        }
    }

    func getPercentile(_ percentile: Double) -> TimeInterval? {
        return queue.sync {
            guard !callbackTimes.isEmpty else { return nil }

            let sorted = callbackTimes.sorted()
            let index = Int(Double(sorted.count - 1) * percentile)
            return sorted[index]
        }
    }

    func generateReport() -> String {
        return queue.sync {
            guard !callbackTimes.isEmpty else {
                return "No performance data available"
            }

            let avg = getAverageCallbackTime() ?? 0
            let p50 = getPercentile(0.5) ?? 0
            let p95 = getPercentile(0.95) ?? 0
            let p99 = getPercentile(0.99) ?? 0

            return """
            Performance Report:
            - Average: \(String(format: "%.3f", avg * 1000))ms
            - P50: \(String(format: "%.3f", p50 * 1000))ms
            - P95: \(String(format: "%.3f", p95 * 1000))ms
            - P99: \(String(format: "%.3f", p99 * 1000))ms
            - Samples: \(callbackTimes.count)
            """
        }
    }
}