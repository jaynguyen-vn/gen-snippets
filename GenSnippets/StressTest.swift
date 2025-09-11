import Foundation
import AppKit

class StressTest {
    static func runEventTapStressTest() {
        print("🚀 Starting Event Tap Stress Test")
        print("====================================")
        print("This test will:")
        print("1. Type rapidly to stress the event tap")
        print("2. Create CPU load to slow down callbacks")
        print("3. Monitor for event tap failures")
        print("====================================\n")
        
        // Test 1: Rapid typing simulation
        DispatchQueue.global(qos: .userInitiated).async {
            print("📝 Test 1: Simulating rapid typing for 30 seconds...")
            let testString = "The quick brown fox jumps over the lazy dog. "
            
            for i in 1...300 {
                Thread.sleep(forTimeInterval: 0.1)
                
                // Simulate typing
                if let eventSource = CGEventSource(stateID: .hidSystemState) {
                    for char in testString {
                        if let keyCode = char.keyCode {
                            let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
                            let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
                            
                            keyDown?.post(tap: .cghidEventTap)
                            Thread.sleep(forTimeInterval: 0.001)
                            keyUp?.post(tap: .cghidEventTap)
                        }
                    }
                }
                
                if i % 10 == 0 {
                    print("   Progress: \(i)/300 iterations")
                }
            }
            print("✅ Test 1 completed\n")
        }
        
        // Test 2: CPU stress during typing
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 35) {
            print("🔥 Test 2: Creating CPU load while typing...")
            
            // Create CPU load
            for _ in 1...10 {
                DispatchQueue.global(qos: .userInitiated).async {
                    var result = 0.0
                    for i in 1...1000000 {
                        result += Double(i).squareRoot()
                    }
                }
            }
            
            // Type while CPU is loaded
            if let eventSource = CGEventSource(stateID: .hidSystemState) {
                for i in 1...100 {
                    let keyCode: CGKeyCode = 0x00 // 'a' key
                    let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
                    let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
                    
                    keyDown?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.01)
                    keyUp?.post(tap: .cghidEventTap)
                    
                    if i % 20 == 0 {
                        print("   CPU stress typing: \(i)/100")
                    }
                }
            }
            print("✅ Test 2 completed\n")
        }
        
        // Test 3: Long callback simulation
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 70) {
            print("⏰ Test 3: Simulating slow callback processing...")
            
            // This will cause the TextReplacementService callback to take longer
            NotificationCenter.default.post(name: NSNotification.Name("SimulateSlowProcessing"), object: nil)
            
            // Type during slow processing
            if let eventSource = CGEventSource(stateID: .hidSystemState) {
                for i in 1...50 {
                    let keyCode: CGKeyCode = 0x0B // 'b' key
                    let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
                    let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
                    
                    keyDown?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.02)
                    keyUp?.post(tap: .cghidEventTap)
                    
                    if i % 10 == 0 {
                        print("   Slow processing typing: \(i)/50")
                    }
                }
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("StopSlowProcessing"), object: nil)
            print("✅ Test 3 completed\n")
        }
        
        // Final report after all tests
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 100) {
            print("====================================")
            print("📊 STRESS TEST COMPLETED")
            print("Check the logs above for:")
            print("- 🔴 Event tap disabled messages")
            print("- ⚠️ Slow callback warnings")
            print("- 🔍 Periodic check results")
            print("====================================")
        }
    }
}

// Helper extension for character to keycode conversion
extension Character {
    var keyCode: CGKeyCode? {
        let keyMap: [Character: CGKeyCode] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
            "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
            "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22,
            "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
            "n": 0x2D, "m": 0x2E, " ": 0x31, ".": 0x2F
        ]
        return keyMap[self]
    }
}