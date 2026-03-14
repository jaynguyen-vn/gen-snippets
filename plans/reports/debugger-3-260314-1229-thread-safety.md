# Thread-Safety Investigation Report
**Subagent:** debugger-3 | **Date:** 2026-03-14

---

## Executive Summary

The `isPerformingExpansion` flag is **definitively not thread-safe**: it is written on a `DispatchQueue.global` background thread (line 625-627) and read on the event tap callback thread (line 477) with zero synchronization. However, this race has a **secondary, more impactful consequence**: `isPerformingExpansion` is set back to `false` (line 627) BEFORE the actual text insertion (lines 649-664, which are deferred 50ms via `DispatchQueue.main.asyncAfter`). This means the guard that was meant to block new keystrokes during expansion is dropped far too early — 50ms before the paste even starts — making it functionally useless for its primary purpose.

Additionally, the clipboard-restore race (Bug 1) is a distinct, independently-confirmed defect.

---

## Evidence FOR the Thread-Safety Hypothesis

### 1. `isPerformingExpansion` — Unsynchronized Plain Bool (lines 133, 477, 625-627)

```swift
// Line 133 — declaration, no atomic/lock annotation
private var isPerformingExpansion = false

// Line 477 — READ on event tap thread (CGEvent callback, OS-managed thread)
if isPerformingExpansion { return }

// Lines 624-627 — WRITTEN on DispatchQueue.global(qos: .userInteractive)
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    self?.isPerformingExpansion = true   // write #1
    self?.deleteLastCharacters(count: charsToDelete)
    self?.isPerformingExpansion = false  // write #2 ← WRONG TIMING (see below)
```

Swift does not guarantee atomic access to `Bool` properties. On arm64 the store/load is naturally word-aligned, so torn reads are unlikely in practice, but **the CPU memory model provides no happens-before guarantee** between threads without synchronization barriers. The compiler can also reorder reads/writes without a `volatile`-equivalent.

### 2. Flag Reset Happens 50ms BEFORE Actual Text Insertion

The most critical bug: `isPerformingExpansion = false` is set at line 627, synchronously after `deleteLastCharacters` returns. But `insertText` is scheduled via `DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)` (line 649). The timeline is:

```
t=0ms   background queue: isPerformingExpansion = true
t=0ms   background queue: deleteLastCharacters() — blocking, uses Thread.sleep
t=~Xms  background queue: isPerformingExpansion = false  ← FLAG DROPPED HERE
t=X+50ms main queue: insertText() begins  ← paste happens here
```

**Result:** For the ~50ms window between flag drop and paste completion, the event tap will process any incoming keystrokes. If the user is a fast typer or holds a key, those characters slip into the buffer and potentially trigger a second expansion. The guard is worthless for protecting the insertion phase.

### 3. `currentInputBuffer` — Cross-Thread Access Without Lock

- **Written** on event tap thread: `handleKeyPress()` modifies `currentInputBuffer` (lines 519-541, 617)
- **Cleared** on main thread: `bufferClearTimer` callback sets `currentInputBuffer = ""` (line 573)
- **Read** on event tap thread in `checkForCommands()` (line 589)

`bufferLock` (NSLock, line 60) exists but is **never used** to protect `currentInputBuffer`. The comment on line 60 says "Lock for buffer and callback state" but no call sites use it. This is a latent data race.

### 4. `callbackExecutionTimes` — Mutated Inside Callback Without Lock

`callbackExecutionTimes.append(executionTime)` (line 245) runs inside the CGEvent callback. `callbackExecutionTimes.removeAll()` (line 233, 405) runs on the event tap re-enable path (callback thread) and on the timer callback (main thread). Concurrent array mutation = undefined behavior.

### 5. Metafield Path Drops Flag Even Earlier

For metafield snippets (lines 630-645), the sequence is:
1. `isPerformingExpansion = false` at line 627 (before async dialog)
2. Dialog shown at t+100ms
3. `insertText()` at t+150ms

The flag is dropped instantly, long before any UI interaction completes.

### 6. Concurrent `insertText()` Paths

Three independent callers can invoke `insertText()` with no mutual exclusion:
- Line 642: metafield path (main queue, after dialog)
- Line 658: direct expansion (main queue, asyncAfter +50ms)
- Line 1290: `insertSnippetDirectly()` (any thread — called from SearchView selection)

If `insertSnippetDirectly()` is called while an expansion is in progress, both will manipulate `NSPasteboard.general` simultaneously and issue `Cmd+V` events. This is a direct cause of Bug 1.

---

## Evidence AGAINST the Hypothesis (Alternative Explanations)

### A. arm64 Bool Reads Are Effectively Atomic

On Apple Silicon (arm64), a Bool is stored as a byte, and byte loads/stores are single instructions. In practice, reads and writes to `isPerformingExpansion` will not produce torn values. The data race still exists formally and the compiler can cache reads in registers, but the torn-read scenario is unlikely to manifest on current hardware.

### B. The Event Tap Callback Likely Serializes Itself

CGEvent taps run synchronously on a single run loop source. If `handleKeyPress` and its children are all called synchronously on the event tap's thread (without re-entering), then in practice `currentInputBuffer` is only touched by one thread at a time during the synchronous callback path. The timer-based clear (main thread) is the real cross-thread hazard.

### C. Clipboard Timing Better Explains Bug 1

The clipboard race (Bug 1: "previous clipboard value appears instead of snippet text") may be explained entirely by the restore-before-paste timing in `insertText()` (lines 884-889):

```swift
// Restore scheduled at t+100ms (or t+250ms for Discord)
DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
    pasteboard.clearContents()
    if let previous = previousContent {
        pasteboard.setString(previous, forType: .string)  // restore here
    }
}
```

If the actual paste (`Cmd+V`) takes longer than `restoreDelay` (e.g., the app is slow, or there's a second scheduled paste from another expansion), the clipboard gets restored before the first paste commits. The target app then pastes the *old* clipboard content. This is a standalone timing bug independent of thread-safety.

### D. Terminal Issue Has a Separate Root Cause

Bug 2 ("snippets don't work in terminal, opening new terminal fixes it") is best explained by the event tap being disabled by macOS (`tapDisabledByTimeout`) when `deleteLastCharacters` blocks the callback thread with `Thread.sleep`. Terminals handle keystrokes differently and may stall the event tap more readily. The periodic re-enable timer fires at 10s intervals but doesn't immediately recover in-progress work. This is not a thread-safety issue per se.

---

## Root Cause Analysis

### Bug 1: "Previous clipboard appears instead of snippet text"

**Primary cause:** The `isPerformingExpansion` flag is cleared at line 627 before `insertText` runs. During the 50ms gap, if a second expansion triggers (fast typing, or `insertSnippetDirectly` called), two concurrent calls to `insertText` race on `NSPasteboard.general`. The second call captures `previousContent` (line 817) *after* the first call has already overwritten the clipboard with its snippet text. When the second call restores `previousContent` (line 884-889), it restores the *first snippet's text* as the "previous" clipboard. The user sees snippet text where the old clipboard value was expected, or the old clipboard value where snippet text was expected.

**Secondary cause:** Even in single-expansion scenarios, if the app receiving the paste is slow (e.g., a browser), `restoreDelay` of 100ms may be insufficient, and the clipboard is restored before the paste commits.

### Bug 2: "Snippets don't work in terminal"

**Primary cause:** `deleteLastCharacters()` runs on a background thread with `Thread.sleep` delays summing to many milliseconds per deletion. This blocks the background thread but also indirectly blocks the event tap from processing subsequent events in a timely manner, causing macOS to disable it via `tapDisabledByTimeout`. The 10s periodic re-enable timer is too slow to recover in interactive typing sessions. Terminals are particularly sensitive because they do not buffer input the way GUI apps do.

**Thread-safety contribution:** `isPerformingExpansion` being cleared too early means the event tap can receive keystrokes during deletion, which can trigger a re-entrant `checkForCommands()` that schedules a second deletion. Doubling the deletion workload further extends blocking time, making tap disablement more likely.

---

## Recommended Fixes (Priority Order)

### Fix 1 (Critical): Hold `isPerformingExpansion = true` through full expansion lifecycle

```swift
// Lines 624-665 — refactor to keep flag set until paste+restore is complete
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    guard let self = self else { return }
    self.isPerformingExpansion = true
    self.deleteLastCharacters(count: charsToDelete)
    // DO NOT reset flag here

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.insertText(snippet.content)
        UsageTracker.shared.recordUsage(for: snippet.command)
        // Reset flag AFTER insertion is dispatched and clipboard restore is scheduled
        // Add an extra delay matching the restore delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isPerformingExpansion = false
        }
    }
}
```

### Fix 2 (Critical): Use `os_unfair_lock` or `NSLock` for `isPerformingExpansion`

Replace the plain `Bool` with a properly synchronized accessor:

```swift
private let expansionLock = NSLock()
private var _isPerformingExpansion = false
private var isPerformingExpansion: Bool {
    get { expansionLock.lock(); defer { expansionLock.unlock() }; return _isPerformingExpansion }
    set { expansionLock.lock(); defer { expansionLock.unlock() }; _isPerformingExpansion = newValue }
}
```

### Fix 3 (High): Use the existing `bufferLock` to protect `currentInputBuffer`

All reads and writes of `currentInputBuffer` (in `handleKeyPress`, `checkForCommands`, and the timer callback) must acquire `bufferLock`. The lock already exists at line 60 but is never used.

### Fix 4 (High): Serialize `insertText` calls

Add a dedicated serial queue for all clipboard-manipulating operations:

```swift
private let insertionQueue = DispatchQueue(label: "com.gensnippets.insertion")
```

All `insertText()` calls (lines 642, 658, 1290) should be dispatched through this queue to prevent concurrent clipboard access.

### Fix 5 (Medium): Move event-intensive work off the event tap callback

`deleteLastCharacters` already runs off the tap thread. Ensure `handleKeyPress` returns within ~5ms. Consider using `kCGEventTapOptionListenOnly` for events generated during expansion instead of filtering via `isPerformingExpansion`.

### Fix 6 (Medium): Replace `Thread.sleep` in `deleteLastCharacters` with async dispatch

Use `DispatchQueue` with `asyncAfter` chains instead of `Thread.sleep` to avoid blocking background threads and reduce event tap starvation.

---

## Supporting Evidence — Key Line References

| Location | Issue |
|---|---|
| Line 133 | `isPerformingExpansion` declared as plain `Bool`, no synchronization |
| Lines 60 | `bufferLock` declared but never acquired anywhere in the file |
| Lines 477 | Flag read on event tap thread |
| Lines 624-627 | Flag written on background queue; reset before insertText runs |
| Lines 649/658 | `insertText` scheduled +50ms after flag reset |
| Lines 884-889 | Clipboard restore scheduled at fixed offset, races with slow paste |
| Lines 695-760 | `Thread.sleep` in deletion loop — blocks background queue |
| Line 1290 | `insertSnippetDirectly` calls `insertText` on any thread, no lock |

---

## Unresolved Questions

1. Is `MetafieldService.shared.containsMetafields()` thread-safe? It's called on the background queue (line 630) and may access shared state.
2. Does `RichContentService.shared.insertRichContent()` also manipulate `NSPasteboard`? If so, it has the same clipboard race as `insertText`.
3. Is there a way to query whether the event tap was disabled by timeout vs. user input to distinguish the terminal bug from normal operation in logs?
4. What is the typical deletion timing in terminals (iTerm2, Ghostty) that causes tap disablement — is it the `Thread.sleep` alone or does the terminal's input processing add latency?
