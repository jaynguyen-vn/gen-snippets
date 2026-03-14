# Final Review: TextReplacementService.swift (Second Pass)

**File:** `GenSnippets/Services/TextReplacementService.swift` (1,390 lines)
**Reviewer:** code-reviewer
**Date:** 2026-03-14
**Scope:** Verify all fixes from first review (C1, C2, H1, H2) and exhaustive trace of all code paths

---

## Overall Assessment

The fixes from the first review are correctly applied. The `isPerformingExpansion` flag lifecycle is now complete across all paths, `snippetSnapshot` eliminates the `snippetQueue.sync` contention in the callback, and `clipboardQueue` adds serialization to clipboard operations. However, this second pass reveals **1 HIGH**, **3 MEDIUM**, and **3 LOW** remaining issues. No new CRITICALs found.

---

## A. `isPerformingExpansion` Lifecycle -- Full Path Trace

### Path 1: Normal plain text expansion (checkForCommands -> insertText -> restore callback)
- **Set true:** Line 661, `DispatchQueue.global` block in `checkForCommands`
- **Set false:** Line 930 or 941 in `insertText`'s `DispatchQueue.main.asyncAfter` restore callback (depending on cursor path)
- **Verdict: CORRECT**

### Path 2: Rich content expansion (checkForCommands -> insertRichContent)
- **Set true:** Line 661
- **Set false:** Line 700, immediately after `insertRichContent` call
- **Verdict: CORRECT** -- but see Medium issue M1 below regarding timing

### Path 3: Metafield expansion with user input (checkForCommands -> dialog -> insertText)
- **Set true:** Line 661
- **Set false:** Via `insertText`'s restore callback (line 930/941)
- **Verdict: CORRECT**

### Path 4: Metafield expansion with dialog cancel
- **Set true:** Line 661
- **Set false:** Line 676, `guard let processedContent` fails -> `self?.isPerformingExpansion = false`
- **Verdict: CORRECT**

### Path 5: insertText with empty text
- **Set false:** Line 854, guard clause
- **Verdict: CORRECT**

### Path 6: insertText with nil CGEventSource
- **Set false:** Line 881, guard clause
- **Verdict: CORRECT**

### Path 7: insertText with failed CGEvent creation
- **Set false:** Line 946, else block
- **Verdict: CORRECT**

### Path 8: insertSnippetDirectly()
- **Does NOT set `isPerformingExpansion = true`** before calling `insertText` (line 1348)
- **Does NOT set `isPerformingExpansion = true`** before calling `insertRichContent` (line 1340)
- `insertText` will set `isPerformingExpansion = false` in its restore callback, but it was never set to `true`
- **Verdict:** See HIGH issue H1 below

### Summary: All 7 paths from `checkForCommands` are correct. Path 8 (`insertSnippetDirectly`) has a gap.

---

## B. Bracket/Brace Matching in `insertText`

Lines 852-948: Structure verified.

```
func insertText {                    // L852
    guard !text.isEmpty              // L853 - early return
    guard let source                 // L880 - early return
    if let cmdDown... {              // L884
        if let position {            // L913
            asyncAfter {             // L920
                asyncAfter {         // L925
                    false            // L930
                }                    // L931
            }                        // L932
        } else {                     // L933
            asyncAfter {             // L936
                false                // L941
            }                        // L942
        }                            // L943
    } else {                         // L944
        false                        // L946
    }                                // L947
}                                    // L948
```

**Indentation concern:** The `if let cmdDown` block (line 884) and its contents are indented with extra leading whitespace compared to the `guard` statements above. This is cosmetic but inconsistent -- the `if` body is indented at 16 spaces while the `guard` statements use 8 spaces. Functionally correct.

**Verdict: CORRECT** -- no mismatched braces. The `else` on line 944 correctly pairs with the `if let` on line 884.

---

## C. Thread Safety Completeness

### C1. `os_unfair_lock` usage -- CORRECT with caveat

Both `expansionLock` and `snippetSnapshotLock` are declared as stored properties on a `class` (heap-allocated, stable address). The `&` operator yields a valid pointer. This is safe because:
- `TextReplacementService` is a class (reference type), so its properties have stable memory addresses
- Neither lock is ever moved or copied
- No recursive locking occurs -- each lock protects only its own property
- No deadlock risk -- `expansionLock` and `snippetSnapshotLock` are never held simultaneously

**Caveat (LOW):** Swift does not formally guarantee that `&property` on a class yields a stable pointer across all calls. Apple's own `OSAllocatedUnfairLock` (iOS 16+ / macOS 13+) was introduced precisely to address this. In practice, class stored properties are stable on current Swift runtimes. See L1.

### C2. `currentInputBuffer` protection -- INCOMPLETE

`bufferLock` is used **only** in the timer callback (lines 603-610). All other access sites are unprotected:
- Line 297-299: Event tap callback -- direct access (backspace handling)
- Line 554-576: `handleKeyPress` -- direct access
- Line 605-609: Timer callback -- protected by `bufferLock`
- Line 626, 637, 643, 649, 652: `checkForCommands` -- direct access
- Line 1156: `startMonitoring` -- direct access
- Line 1203: `stopMonitoring` -- direct access

The event tap callback and `handleKeyPress`/`checkForCommands` run on the same thread (the run loop thread where the event tap is registered). The timer callback (line 599) runs on main thread. So there IS a cross-thread race between the timer clearing the buffer (main thread) and the event tap callback reading/writing it (run loop thread).

The `bufferLock` in the timer callback only protects ONE side of the race. The event tap callback side does NOT acquire the lock.

**Verdict:** The timer-vs-callback race is partially mitigated. If the timer fires and clears the buffer while the callback is mid-read, the callback could read a partially mutated string. See M2.

### C3. `callbackExecutionTimes` -- UNPROTECTED

Accessed from:
- Event tap callback thread (lines 265-268, 280-282)
- Main thread timer (lines 439-440)
- `stopMonitoring` (line 1209, could be any thread)

No synchronization. Array mutations from different threads can cause crashes.

**Verdict:** See M3.

---

## D. `clipboardQueue` Effectiveness

### Analysis

`clipboardQueue` wraps the dispatch in `checkForCommands`:
```swift
self?.clipboardQueue.async {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self?.insertText(processedContent)
    }
}
```

The `clipboardQueue.async` block immediately dispatches to `main.asyncAfter` and returns. This means the serial queue's block completes almost instantly, and the actual clipboard work happens later on the main queue. Two rapid snippet triggers would both enqueue their `main.asyncAfter` blocks in quick succession, and both would execute on the main queue -- NOT serialized by `clipboardQueue`.

**However**, in practice this is mitigated by:
1. `isPerformingExpansion` is set to `true` before any clipboard work starts (line 661)
2. The `handleKeyPress` function checks `isPerformingExpansion` (line 512) and returns early
3. So a second snippet trigger would be dropped at the `handleKeyPress` level before reaching `checkForCommands`

**Verdict:** `clipboardQueue` provides NO actual serialization of clipboard operations due to the `main.asyncAfter` escape. The real protection comes from `isPerformingExpansion`. The `clipboardQueue` is effectively dead code for its intended purpose. See M1.

### Can two pastes still race?

Only if `insertSnippetDirectly` is called during an in-progress expansion. `insertSnippetDirectly` does NOT check `isPerformingExpansion` and does NOT use `clipboardQueue`. See H1.

---

## E. Functional Correctness

### E1. Restore delay 0.3s -- UX impact

The user cannot paste their own content for ~0.3s (0.4s for Discord) after a snippet expansion. This is a reasonable tradeoff -- the previous 0.1s was too aggressive and caused clipboard loss. 0.3s is imperceptible in normal typing flow. Users rarely Cmd+V within 300ms of a snippet trigger.

**Verdict: ACCEPTABLE**

### E2. `isPerformingExpansion` held for 0.3s+ -- dropped keystrokes?

When `isPerformingExpansion` is true, `handleKeyPress` returns early (line 512). This means keystrokes typed during the 0.3s window are NOT added to the buffer. They ARE still delivered to the foreground app (the event tap returns the event, not nil), so the user sees their characters. They just won't trigger snippet matching.

If a user types a full snippet command within 300ms of a previous expansion completing, the command would be partially in the buffer. This is extremely unlikely in practice.

**Verdict: ACCEPTABLE** -- keystrokes appear in the app, just not buffered. Snippet matching resumes after restore.

### E3. Metafield and rich content paths -- functional equivalence

- Metafield path: Unchanged behavior. Dialog shows, user inputs, `insertText` called. Only change is `isPerformingExpansion` lifecycle wrapping.
- Rich content path: `insertRichContent` behavior unchanged. Only addition is `isPerformingExpansion = false` after the call (line 700).
- **Note:** `insertRichContent` internally uses `DispatchQueue.main.asyncAfter` chains for multi-item insertion. The `isPerformingExpansion = false` on line 700 fires BEFORE all items are actually inserted if there are multiple items. See M1.

---

## F. Edge Cases

### F1. App quit during expansion
`TextReplacementService` is a singleton (`static let shared`). It lives for the app's lifetime. On quit, the event tap is destroyed and all pending `asyncAfter` blocks are abandoned. No issue -- the flag state is irrelevant after quit.

### F2. Snippets updated during expansion
`updateSnippets` writes to `snippetSnapshot` via barrier block on `snippetQueue`. `checkForCommands` reads `snippetSnapshot` via `os_unfair_lock`. These are independent lock domains. No conflict. The expansion in progress uses the snippet content it already captured -- the update will apply to the next keystroke.

**Verdict: SAFE**

### F3. `insertSnippetDirectly` during in-progress expansion
This is the H1 issue. Both paths would manipulate `NSPasteboard.general` concurrently and issue `Cmd+V` events. The user's original clipboard content would be corrupted.

---

## Issues Found

### HIGH

#### H1. `insertSnippetDirectly` does not guard `isPerformingExpansion`

**Location:** Lines 1330-1350
**Impact:** If a user triggers a snippet via the search view (Cmd+Ctrl+S) while an event-tap expansion is in progress, both code paths will concurrently manipulate `NSPasteboard.general` and issue `Cmd+V` synthetic events. This causes clipboard corruption and garbled output.

**Likelihood:** Low but non-zero. User types a snippet command, it starts expanding, user quickly opens search and selects another snippet.

**Fix:**
```swift
func insertSnippetDirectly(_ snippet: Snippet) {
    // Prevent concurrent clipboard manipulation
    guard !isPerformingExpansion else {
        print("[TextReplacementService] Skipping direct insert -- expansion in progress")
        return
    }
    isPerformingExpansion = true

    // ... existing code ...

    if snippet.actualContentType != .plainText {
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        RichContentService.shared.insertRichContent(for: snippet, previousClipboard: previousClipboard)
        // Reset after rich content (same timing concern as M1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isPerformingExpansion = false
        }
    } else {
        let processedContent = processSnippetWithPlaceholders(snippet.content)
        insertText(processedContent) // insertText handles flag reset
    }
}
```

---

### MEDIUM

#### M1. `isPerformingExpansion = false` fires too early on rich content path (multi-item)

**Location:** Line 700
**Impact:** For snippets with multiple rich content items (e.g., image + text), `RichContentService.insertMultipleItems` uses recursive `asyncAfter` chains (lines 128-146 in RichContentService.swift). The `isPerformingExpansion = false` on line 700 executes immediately after calling `insertRichContent`, while items are still being pasted. During this window, the user's keystrokes would be buffered and could trigger a second expansion, corrupting the clipboard mid-paste.

**Fix:** `insertRichContent` should accept a completion handler, and `isPerformingExpansion = false` should be set in that completion:
```swift
// In RichContentService:
func insertRichContent(for snippet: Snippet, previousClipboard: String?, completion: (() -> Void)? = nil) {
    // ... pass completion to insertMultipleItems terminal case ...
}
```

#### M2. `bufferLock` is one-sided -- timer callback is protected but event tap callback is not

**Location:** Lines 297-300, 554-576, 626-652 (unprotected) vs lines 603-610 (protected)
**Impact:** The timer fires on main thread and clears `currentInputBuffer`. The event tap callback reads/writes `currentInputBuffer` on the run loop thread. String is a value type in Swift and copy-on-write, so concurrent read+write on the same storage can cause a crash if the buffer is being mutated when the timer clears it.

**Practical likelihood:** Low. The timer fires every 15s and the clear operation is fast. But it is technically a data race.

**Fix:** Either:
- Wrap ALL buffer accesses in the event tap callback with `bufferLock` (adds ~microsecond latency per keystroke), or
- Move the timer's buffer clear to the run loop thread instead of main thread, so both access the buffer on the same thread

#### M3. `callbackExecutionTimes` is unprotected across threads

**Location:** Lines 174, 265-268, 280-282, 439-440, 1209
**Impact:** Array is mutated from event tap callback thread (append, removeFirst) and main thread timer (removeAll). Concurrent mutations can crash.

**Fix:** Either protect with `bufferLock` (it's already in scope) or use an atomic counter instead of an array:
```swift
// Simpler: just track count and sum
private var callbackTimeSum: TimeInterval = 0
private var callbackTimeCount: Int = 0
```

---

### LOW

#### L1. `os_unfair_lock` on class stored property is technically undefined behavior in Swift

**Location:** Lines 68, 71, 76, 152, 155, 160
**Impact:** Swift does not formally guarantee pointer stability for `&classProperty`. Apple introduced `OSAllocatedUnfairLock` in macOS 13 to solve this. In practice, class stored properties are heap-allocated with stable addresses on current runtimes.

**Fix (when min deployment target allows):** Replace with `OSAllocatedUnfairLock<Bool>` / `OSAllocatedUnfairLock<[Snippet]>`.

#### L2. `clipboardQueue` provides no actual serialization

**Location:** Lines 167, 680, 690
**Impact:** The serial queue's block immediately escapes to `main.asyncAfter`, defeating serialization. The code works correctly because `isPerformingExpansion` is the real guard, but `clipboardQueue` is misleading dead code.

**Fix:** Either remove `clipboardQueue` (since `isPerformingExpansion` is sufficient) or restructure to keep clipboard work inside the serial queue. Removing is simpler and reduces cognitive overhead.

#### L3. `insertText` indentation inconsistency

**Location:** Lines 884-947
**Impact:** Pure cosmetic. The `if let cmdDown` block body uses 16-space indentation while the preceding `guard` statements use 8-space. This suggests the `if` was originally inside another block and wasn't re-indented when restructured.

**Fix:** Re-indent lines 884-947 to use consistent 8-space indentation for the body.

---

## Positive Observations

1. **isPerformingExpansion lifecycle is now complete** -- all 7 paths from `checkForCommands` correctly reset the flag, including early exits
2. **snippetSnapshot eliminates lock contention** -- the callback path no longer needs `snippetQueue.sync`, which was the root cause of event tap timeouts
3. **Event tap check timer at 3s** is a good balance between responsiveness and CPU usage
4. **Empty text guard** in `insertText` prevents wasted clipboard operations
5. **Guard let source** pattern ensures no clipboard mutation occurs before a viable CGEventSource exists
6. **Weak self** is consistently used in closures dispatched from the event tap callback

---

## Metrics

| Metric | Value |
|--------|-------|
| Lines of code | 1,390 |
| Critical issues (this pass) | 0 |
| High issues (this pass) | 1 |
| Medium issues (this pass) | 3 |
| Low issues (this pass) | 3 |
| Previous critical fixes verified | 2/2 (C1: rich content flag, C2: snippetQueue.sync) |
| Previous high fixes verified | 2/2 (H1: metafield cancel path, H2: insertText guards) |

---

## Recommended Actions (Priority Order)

1. **[HIGH] H1:** Add `isPerformingExpansion` guard to `insertSnippetDirectly` -- prevents clipboard corruption from concurrent Search View insertion
2. **[MEDIUM] M1:** Add completion handler to `insertRichContent` so flag resets after all items are pasted, not immediately
3. **[MEDIUM] M2:** Protect all `currentInputBuffer` access sites with `bufferLock`, or move timer clear to run loop thread
4. **[MEDIUM] M3:** Protect `callbackExecutionTimes` or replace with atomic counters
5. **[LOW] L2:** Remove `clipboardQueue` (dead code) or restructure to actually serialize
6. **[LOW] L1:** Plan migration to `OSAllocatedUnfairLock` when min deployment target allows
7. **[LOW] L3:** Fix indentation in `insertText`

---

## Unresolved Questions

1. Does `RichContentService.simulatePaste()` interact with `isPerformingExpansion` at all? Currently it does not. If the event tap sees the synthetic Cmd+V from `simulatePaste`, would it try to process it? (Likely no -- Cmd modifier is filtered at line 292, but worth confirming.)
2. Should `insertSnippetDirectly` route through `clipboardQueue` if the queue is kept, or is the `isPerformingExpansion` guard sufficient?
3. The file is 1,390 lines. The CLAUDE.md notes it should be under 200 lines per file. Is a refactoring pass planned to extract components (e.g., `KeyboardEventHandler`, `ClipboardManager`, `BufferManager`)?
