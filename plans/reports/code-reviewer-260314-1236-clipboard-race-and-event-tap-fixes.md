# Code Review: Clipboard Race & Event Tap Fixes

**File:** `GenSnippets/Services/TextReplacementService.swift`
**Scope:** 6 fixes addressing clipboard race conditions, event tap timeout, thread safety
**LOC changed:** ~120 (diff)

## Overall Assessment

The fixes address real bugs and the intent is correct throughout. However, there are **two critical bugs** (stuck `isPerformingExpansion` flag), **one high-priority thread safety gap**, and several medium observations.

---

## Critical Issues

### C1. `isPerformingExpansion` stuck `true` forever -- rich content path

**Location:** Lines 678-695 (non-metafield, rich content branch)

When `snippet.actualContentType != .plainText`, the code calls `RichContentService.shared.insertRichContent()` instead of `self.insertText()`. The `insertText()` method is the only place that sets `isPerformingExpansion = false` (in its clipboard-restore callbacks). `RichContentService.insertRichContent()` does NOT reset this flag -- it has no knowledge of it.

**Result:** After any rich content expansion (image, URL, file), `isPerformingExpansion` stays `true` permanently. All subsequent keystrokes are silently dropped at line 500. The app appears completely dead until `startMonitoring()` is called again (which resets the flag at line 1132).

**Fix:** Set `isPerformingExpansion = false` after the rich content insertion completes. The cleanest approach is to add it in the `DispatchQueue.main.asyncAfter` block after `insertRichContent` returns, estimated at the same delay as clipboard restore (~0.3s after the last item is pasted):

```swift
// Line 683 area
if snippet.actualContentType != .plainText {
    let previousClipboard = NSPasteboard.general.string(forType: .string)
    RichContentService.shared.insertRichContent(for: snippet, previousClipboard: previousClipboard)
    // Rich content handles its own clipboard restore (0.3s after last item)
    // Reset expansion flag after rich content pipeline completes
    let totalItems = snippet.allRichContentItems.count
    let estimatedDuration = Double(totalItems) * 0.25 + 0.5
    DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
        self?.isPerformingExpansion = false
    }
    ...
}
```

### C2. `isPerformingExpansion` stuck `true` forever -- metafield path with successful content

**Location:** Lines 668-673 (metafield branch, processedContent != nil)

When the user fills in the metafield dialog and `processedContent` is non-nil, the code dispatches to `clipboardQueue.async` then `DispatchQueue.main.asyncAfter` and calls `self?.insertText(processedContent)`. The `insertText()` method does set `isPerformingExpansion = false` in its restore callback -- BUT only if `CGEventSource(stateID: .hidSystemState)` succeeds AND the CGEvent creation succeeds (lines 862-866). If either fails, the method returns without ever setting `isPerformingExpansion = false`.

This is the same problem that exists in the non-metafield plain-text path. Two `if let` guards (lines 862, 863-866) can silently exit `insertText()` without resetting the flag.

**Fix:** Add `isPerformingExpansion = false` in a `defer` or at the early-exit points of `insertText()`:

```swift
private func insertText(_ text: String) {
    guard !text.isEmpty else {
        isPerformingExpansion = false  // <-- add
        return
    }
    // ...
    if let source = CGEventSource(stateID: .hidSystemState) {
        if let cmdDown = ... {
            // ... existing code with restore callbacks
        } else {
            isPerformingExpansion = false  // <-- add: CGEvent creation failed
        }
    } else {
        isPerformingExpansion = false  // <-- add: CGEventSource creation failed
    }
}
```

---

## High Priority

### H1. `snippetSnapshot` is not thread-safe -- data race on read

**Location:** Line 68 (declaration), line 617 (read in `checkForCommands`), line 1213 (write in `updateSnippets`)

`snippetSnapshot` is declared as a plain `var`. It is written inside `snippetQueue.async(flags: .barrier)` (line 1194) but read on the event tap callback thread without any synchronization (line 617). Swift arrays are value types with COW, but the COW metadata update during read is not atomic. Two simultaneous accesses (a write from `updateSnippets` and a read from the event tap) constitute a data race.

The comment says "lock-free snapshot" but this is not actually lock-free -- it is simply unprotected. True lock-free would require an atomic reference or similar mechanism.

**Options:**
1. Make `snippetSnapshot` use a lock (NSLock or os_unfair_lock) for both read and write
2. Read it via `snippetQueue.sync` (which defeats the purpose of the change)
3. Use `@Atomic` property wrapper or `OSAllocatedUnfairLock` (iOS 16+/macOS 13+)

Pragmatic fix -- add a dedicated lock:

```swift
private var snippetSnapshotLock = os_unfair_lock()
private var _snippetSnapshot: [Snippet] = []
private var snippetSnapshot: [Snippet] {
    get {
        os_unfair_lock_lock(&snippetSnapshotLock)
        defer { os_unfair_lock_unlock(&snippetSnapshotLock) }
        return _snippetSnapshot
    }
    set {
        os_unfair_lock_lock(&snippetSnapshotLock)
        _snippetSnapshot = newValue
        os_unfair_lock_unlock(&snippetSnapshotLock)
    }
}
```

This still avoids the `snippetQueue.sync` contention that was the original problem, while being safe.

### H2. `currentInputBuffer` accessed without lock in event tap callback

**Location:** Lines 285-289 (backspace handling in CGEvent tap callback)

The buffer clear timer now correctly uses `bufferLock` (lines 591-598). However, the event tap callback at lines 285-289 accesses `currentInputBuffer` directly without any lock:

```swift
if !service.currentInputBuffer.isEmpty {
    service.currentInputBuffer.removeLast()
```

And `handleKeyPress` (called from the same callback at lines 315, 369) also accesses `currentInputBuffer` without a lock (lines 542-564, 614-640).

The timer fires on the main thread. The event tap callback runs on whichever thread the run loop is on. If these differ, there is a data race. If they are both the main run loop, it is safe but fragile.

**Recommendation:** Either document that the event tap run loop source is always on the main run loop (making the lock only needed for the timer, which is already protected), or wrap all `currentInputBuffer` accesses in the lock for safety.

---

## Verification of Specific Questions

### Q1. Is `isPerformingExpansion = false` set in ALL code paths?

**NO.** Two missing paths identified:

| Path | Resets to false? | Bug? |
|------|-----------------|------|
| Plain text, no metafields, `insertText` succeeds | YES (lines 909, 920) | OK |
| Plain text, no metafields, `insertText` guard fails | NO | **BUG (C2)** |
| Metafield dialog cancelled (nil content) | YES (line 664) | OK |
| Metafield dialog confirmed, `insertText` succeeds | YES (via insertText) | OK |
| Metafield dialog confirmed, `insertText` guard fails | NO | **BUG (C2)** |
| Rich content path | NO | **BUG (C1)** |
| `startMonitoring()` | YES (line 1132) | Recovery only |
| `stopMonitoring()` | Not set | OK (monitoring stops) |

### Q2. Does `clipboardQueue.async` actually serialize? Could it deadlock?

**Serialization:** Yes, it is a serial queue (no `.concurrent` attribute), so blocks dispatched with `.async` execute one at a time. This correctly prevents overlapping clipboard operations.

**Deadlock risk:** No deadlock. `.async` never blocks the caller. The blocks themselves dispatch to `DispatchQueue.main.asyncAfter` which is also non-blocking from the clipboard queue's perspective. No lock is held while dispatching.

**However**, the serialization is somewhat illusory for the metafield path. At line 668, `clipboardQueue.async` wraps only the `DispatchQueue.main.asyncAfter` dispatch -- the actual clipboard work happens later on the main queue, outside the clipboard queue's serial guarantee. If two metafield expansions could race (unlikely but theoretically possible if `isPerformingExpansion` has the C1/C2 bug), the clipboard queue would not prevent interleaving.

### Q3. Is `snippetSnapshot` updated correctly in `updateSnippets()`?

**Logically yes** -- it is assigned from `sortedSnippetsCache` which was just computed (line 1213). **Thread-safety: no** -- see H1 above.

### Q4. Is `os_unfair_lock` safe in a computed property on a class?

**Mostly yes, with a caveat.** `os_unfair_lock` must not be moved in memory. Class instances are heap-allocated and do not move, so `&expansionLock` produces a stable pointer for the lifetime of the object. This is safe.

However, `os_unfair_lock` is a value type (`struct os_unfair_lock_s`). Taking `&` of a struct property on a class is technically an implicit inout access, which Swift may handle via a temporary in some edge cases. In practice, with stored properties on a class, the compiler passes the address directly. This is the standard pattern used in Apple's own code and is safe.

**One concern:** If `TextReplacementService` were ever made into a struct or the lock were moved to a different container, this would break silently. Consider using `OSAllocatedUnfairLock` (macOS 13+) which is a class-based wrapper that eliminates this concern entirely.

### Q5. Does `bufferLock` in the timer callback risk deadlock?

**No.** `bufferLock` is an `NSLock` used in exactly one place (the timer callback, lines 591-598). The event tap callback does NOT use `bufferLock` (see H2). No other code path acquires `bufferLock`, so there is no possibility of lock ordering violation or deadlock.

However, because the event tap callback does NOT use this lock, the protection is one-sided. The timer clears the buffer safely with respect to itself, but the event tap can still race with the timer.

### Q6. Are restore delays reasonable (0.3s standard, 0.4s Discord)?

**Reasonable but aggressive.** The previous values (0.1s, 0.25s) were causing race conditions, so increasing them is correct. 0.3s standard should be fine for most apps. 0.4s for Discord is reasonable given Discord's known Electron sluggishness.

**Risk:** On fast machines with responsive apps, 0.3s may feel slightly laggy if the user immediately Cmd+V after a snippet expansion (they'd get the snippet text instead of their clipboard content). This is a minor UX concern, not a bug.

---

## Medium Priority

### M1. `self` vs `self?` inconsistency in `insertText` callbacks

Lines 900, 909, 920 use strong `self` (no `?`). This is because `insertText` is an instance method called via `self?.insertText()`, so within insertText, `self` is already strongly captured. This is correct but worth noting: it means the TextReplacementService instance cannot be deallocated during an expansion, which is fine since it is a singleton.

### M2. `clipboardQueue` wrapping is inconsistent

The metafield path (line 668) wraps the `DispatchQueue.main.asyncAfter` call inside `clipboardQueue.async`. But the actual clipboard mutation happens inside `insertText`, which is called from the main queue callback -- not from the clipboard queue. The clipboard queue block completes immediately after dispatching the main queue work. This means the serial queue does not actually serialize clipboard access between multiple expansions. It only serializes the *dispatch* of main-queue work.

For the non-metafield path (line 678), the same issue applies: `clipboardQueue.async` wraps a `DispatchQueue.main.asyncAfter`, and the actual clipboard work runs on main.

This is not a practical bug (because `isPerformingExpansion` prevents concurrent expansions), but the `clipboardQueue` is not providing the protection it claims to provide.

### M3. Timer callback should use `try?` pattern for lock

The `bufferLock.lock()` / `bufferLock.unlock()` pattern at lines 591-598 does not use `defer` for unlock. If the code between lock/unlock were to throw or if future modifications add early returns, the lock would stay held. Recommend:

```swift
self.bufferLock.lock()
defer { self.bufferLock.unlock() }
```

---

## Low Priority

### L1. Event tap check timer reduced from 10s to 3s

This is fine. The tradeoff is slightly more CPU wake-ups (every 3s instead of 10s) for faster recovery from disabled taps. On a modern Mac, a 3s timer is negligible.

### L2. Dead code comment cleanup

Line 651 has `// NOTE: Do NOT reset isPerformingExpansion here...` which is helpful documentation for maintainers. Good.

---

## Positive Observations

1. The metafield dialog cancel path correctly resets `isPerformingExpansion = false` (line 664) -- this was a known gap and was properly addressed
2. `os_unfair_lock` is a good choice for the expansion flag -- it is the fastest lock primitive on macOS
3. The `clipboardQueue` concept is sound even if the current implementation does not fully serialize clipboard access
4. The event tap re-enable with exponential backoff (lines 467-475) is well-designed
5. Reducing the timer from 10s to 3s is a good balance for responsiveness

---

## Recommended Actions (Priority Order)

1. **[CRITICAL] Fix C1:** Add `isPerformingExpansion = false` after rich content insertion completes
2. **[CRITICAL] Fix C2:** Add `isPerformingExpansion = false` at all early-exit points in `insertText()`
3. **[HIGH] Fix H1:** Add synchronization for `snippetSnapshot` read/write
4. **[HIGH] Fix H2:** Protect `currentInputBuffer` access in event tap callback with `bufferLock`, or document that both always run on the main run loop
5. **[MEDIUM] Fix M3:** Use `defer` for `bufferLock.unlock()`

---

## Unresolved Questions

1. Is the event tap callback guaranteed to run on the main run loop? If yes, H2 is safe but should be documented. If no, H2 is a live data race.
2. Should `clipboardQueue` be restructured to actually serialize clipboard access (by performing clipboard reads/writes on that queue), or is `isPerformingExpansion` sufficient as the single concurrency guard?
3. What is the target macOS version? If macOS 13+, `OSAllocatedUnfairLock` would be cleaner than raw `os_unfair_lock`.
