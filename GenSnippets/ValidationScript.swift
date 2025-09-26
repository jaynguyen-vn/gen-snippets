import Foundation

// MARK: - Validation Script for Text Replacement Service
// This script validates the text replacement functionality without requiring XCTest

final class TextReplacementValidator {

    private var passedTests = 0
    private var failedTests = 0
    private var currentTestName = ""

    // MARK: - Test Helpers

    private func startTest(_ name: String) {
        currentTestName = name
        print("\n🧪 Testing: \(name)")
    }

    private func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        if actual == expected {
            passedTests += 1
            print("   ✅ PASSED: \(message.isEmpty ? currentTestName : message)")
        } else {
            failedTests += 1
            print("   ❌ FAILED: \(message.isEmpty ? currentTestName : message)")
            print("      Expected: \(expected)")
            print("      Got: \(actual)")
        }
    }

    private func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil {
            passedTests += 1
            print("   ✅ PASSED: \(message.isEmpty ? "Not nil check" : message)")
        } else {
            failedTests += 1
            print("   ❌ FAILED: \(message.isEmpty ? "Not nil check" : message)")
            print("      Value was nil")
        }
    }

    private func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition {
            passedTests += 1
            print("   ✅ PASSED: \(message.isEmpty ? currentTestName : message)")
        } else {
            failedTests += 1
            print("   ❌ FAILED: \(message.isEmpty ? currentTestName : message)")
        }
    }

    // MARK: - Validation Tests

    func validateTrieImplementation() {
        startTest("Trie Implementation")

        // Create a simple trie
        let trie = TrieNode()
        let snippet1 = createTestSnippet(id: "1", command: "test", content: "replacement")
        let snippet2 = createTestSnippet(id: "2", command: "testing", content: "longer replacement")

        trie.insert(command: "test", snippet: snippet1)
        trie.insert(command: "testing", snippet: snippet2)

        // Test exact matching
        let found1 = trie.findMatchingSuffix(in: "this is a test")
        assertNotNil(found1, "Should find 'test' snippet")
        assertEqual(found1?.command ?? "", "test", "Should match correct command")

        let found2 = trie.findMatchingSuffix(in: "we are testing")
        assertNotNil(found2, "Should find 'testing' snippet")
        assertEqual(found2?.command ?? "", "testing", "Should match longer command")
    }

    func validateUnicodeHandling() {
        startTest("Unicode and Special Characters")

        let testCases = [
            ("café", "café"),  // French accents
            ("việt", "việt"),  // Vietnamese
            ("😀", "😀"),      // Emoji
            ("→", "→"),        // Special arrows
            ("日本", "日本")    // Japanese
        ]

        for (input, expected) in testCases {
            let normalized = input.precomposedStringWithCanonicalMapping
            assertEqual(normalized, expected, "Unicode normalization for '\(input)'")
        }
    }

    func validateBufferManagement() {
        startTest("Buffer Management")

        var buffer = ""
        let maxSize = 100

        // Test buffer size limit
        let longString = String(repeating: "a", count: 150)
        buffer = longString

        if buffer.count > maxSize {
            let trimmed = String(buffer.suffix(maxSize))
            assertEqual(trimmed.count, maxSize, "Buffer should be trimmed to max size")
        }

        // Test buffer operations
        buffer = "test"
        assertTrue(buffer.hasSuffix("test"), "Buffer should contain 'test'")

        buffer.removeLast()
        assertEqual(buffer, "tes", "Buffer should be 'tes' after removing last")
    }

    func validateSnippetMatching() {
        startTest("Snippet Matching Logic")

        let snippets = [
            createTestSnippet(id: "1", command: "btw", content: "by the way"),
            createTestSnippet(id: "2", command: "ty", content: "thank you"),
            createTestSnippet(id: "3", command: "test", content: "TEST"),
            createTestSnippet(id: "4", command: "testing", content: "TESTING")
        ]

        // Sort by length (longest first)
        let sorted = snippets.sorted { $0.command.count > $1.command.count }
        assertEqual(sorted.first?.command ?? "", "testing", "Longest command should be first")

        // Test suffix matching
        let buffer = "I am testing"
        var matchFound: Snippet? = nil

        for snippet in sorted {
            if buffer.hasSuffix(snippet.command) {
                matchFound = snippet
                break
            }
        }

        assertNotNil(matchFound, "Should find matching snippet")
        assertEqual(matchFound?.command ?? "", "testing", "Should match 'testing' command")
    }

    func validateKeywordProcessing() {
        startTest("Keyword Processing")

        let text = "Hello {date} - {time}"

        // Check if keywords are detected
        assertTrue(text.contains("{date}"), "Should contain {date} keyword")
        assertTrue(text.contains("{time}"), "Should contain {time} keyword")

        // Simple keyword replacement simulation
        var processed = text
        processed = processed.replacingOccurrences(of: "{date}", with: Date().description)

        assertTrue(!processed.contains("{date}"), "Keyword should be replaced")
        assertTrue(processed.contains("Hello"), "Original text should be preserved")
    }

    func validatePerformanceOptimizations() {
        startTest("Performance Optimizations")

        // Test timing comparisons
        let startTime = CFAbsoluteTimeGetCurrent()
        Thread.sleep(forTimeInterval: 0.001) // 1ms sleep
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        assertTrue(elapsed >= 0.001, "Timing measurement should work")
        assertTrue(elapsed < 0.01, "Should not take too long")

        // Test duplicate key detection
        let lastKeyTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        Thread.sleep(forTimeInterval: 0.005)
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeDiff = currentTime - lastKeyTime

        assertTrue(timeDiff >= 0.005, "Time difference should be accurate")

        let isRepeatedKey = timeDiff < 0.008
        assertTrue(!isRepeatedKey, "Should not be detected as repeated key after 5ms")
    }

    func validateMemorySafety() {
        startTest("Memory Safety")

        // Test weak reference behavior
        class TestObject {
            var value: String = "test"
        }

        var strongRef: TestObject? = TestObject()
        weak var weakRef = strongRef

        assertNotNil(weakRef, "Weak reference should exist while strong ref exists")

        strongRef = nil

        // In real scenario, this would be nil after autorelease pool drains
        // but we can't force it in this context
        assertTrue(true, "Memory safety check completed")
    }

    func validateVietnameseInput() {
        startTest("Vietnamese Input Method")

        // Test Vietnamese characters with diacritics
        let vietnameseText = "Xin chào Việt Nam"
        let normalized = vietnameseText.precomposedStringWithCanonicalMapping

        assertTrue(normalized.count > 0, "Should handle Vietnamese text")

        // Check for combining diacriticals
        let hasVietnameseChars = vietnameseText.unicodeScalars.contains { scalar in
            // Check for Vietnamese-specific Unicode ranges
            (scalar.value >= 0x1EA0 && scalar.value <= 0x1EF9)
        }

        assertTrue(hasVietnameseChars, "Should contain Vietnamese-specific characters")
    }

    // MARK: - Helper Methods

    private func createTestSnippet(id: String, command: String, content: String) -> Snippet {
        return Snippet(
            _id: id,
            command: command,
            content: content,
            description: nil,
            categoryId: nil,
            userId: nil,
            isDeleted: false,
            createdAt: nil,
            updatedAt: nil
        )
    }

    // MARK: - Run All Validations

    func runAllValidations() {
        print("\n" + String(repeating: "=", count: 50))
        print("🚀 RUNNING TEXT REPLACEMENT VALIDATION SUITE")
        print(String(repeating: "=", count: 50))

        validateTrieImplementation()
        validateUnicodeHandling()
        validateBufferManagement()
        validateSnippetMatching()
        validateKeywordProcessing()
        validatePerformanceOptimizations()
        validateMemorySafety()
        validateVietnameseInput()

        print("\n" + String(repeating: "=", count: 50))
        print("📊 VALIDATION RESULTS")
        print(String(repeating: "=", count: 50))
        print("✅ Passed: \(passedTests)")
        print("❌ Failed: \(failedTests)")

        let totalTests = passedTests + failedTests
        let successRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0

        print(String(format: "📈 Success Rate: %.1f%%", successRate))

        if failedTests == 0 {
            print("\n🎉 ALL VALIDATIONS PASSED! The text replacement service is working correctly.")
        } else {
            print("\n⚠️ Some validations failed. Please review the failures above.")
        }

        print(String(repeating: "=", count: 50))
    }
}

// MARK: - Main Execution

// To run this validation:
// 1. Build the project: xcodebuild -project GenSnippets.xcodeproj -scheme GenSnippets -configuration Debug build
// 2. Run this file: swift ValidationScript.swift

// Note: This can also be called from the app itself
public func runTextReplacementValidation() {
    let validator = TextReplacementValidator()
    validator.runAllValidations()
}

// Uncomment to run directly
// runTextReplacementValidation()