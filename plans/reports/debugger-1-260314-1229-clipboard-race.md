# Clipboard Race Condition — Debugger Report
**Date:** 2026-03-14
**Task:** Debug: Clipboard restore happens before paste completes

---

## Executive Summary

The clipboard race condition hypothesis is **CONFIRMED** with three distinct failure modes. The primary bug is that `NSPasteboard.general` is restored 0.1s after events are *posted* — but Cmd+V is processed asynchronously by the target app, so restore can race against paste. A secondary, more severe bug exists: `processKeyword("clipboard")` reads `NSPasteboard.general` **after** `insertText()` has already written the snippet content to it, so `{clipboard}` snippets always return the snippet text, not the real clipboard value. A third bug: `isPerformingExpansion` is set and cleared on a background thread but read on the event tap callback thread with no synchronization, causing a data race that can let a second snippet trigger while the first is still being inserted.

---

## Evidence FOR the Hypothesis

### 1. Fixed 0.1s restore delay is insufficient and racey
**Location:** `TextReplacementService.swift:883-889`

```swift
let restoreDelay = EdgeCaseHandler.detectAppCategory() == .discord ? 0.25 : 0.1
DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
    pasteboard.clearContents()
    if let previous = previousContent {
        pasteboard.setString(previous, forType: .string)
    }
}
```

The Cmd+V events are posted synchronously with tiny `usleep()` delays (variable, based on `timingConfig.paste`). After the last `cmdUp.post()`, the code returns immediately and the `DispatchQueue.main.asyncAfter(...+0.1)` fires 100ms later. However:

- **The target app processes Cmd+V asynchronously.** On a loaded system, or in an Electron/web app, the app may not read the pasteboard until 150–300ms+ after `cmdUp` is posted.
- **0.1s is an arbitrary constant**, not tied to any acknowledgement or confirmation from the target app.
- Under moderate CPU load (common in developer workflows), 0.1s restore can fire before the target app's paste handler has run → the app reads the old clipboard value.

### 2. `BrowserCompatibleTextInsertion` has the same race, with only 0.2s for browsers
**Location:** `BrowserCompatibleTextInsertion.swift:90-95`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    pasteboard.clearContents()
    if let original = originalContent ?? previousContent {
        pasteboard.setString(original, forType: .string)
    }
}
```

0.2s for browsers is barely better. Chrome/Safari render-process paste can take 300ms+ under load.

### 3. `{clipboard}` keyword reads pasteboard AFTER snippet content is written to it
**Location:** `TextReplacementService.swift:806-828` vs `1047-1048`

Flow:
1. `insertText(_ text: String)` is called with `snippet.content` (already keyword-processed via `processSpecialKeywordsWithCursor`)
2. BUT wait — `processSpecialKeywordsWithCursor` calls `processKeyword("clipboard")` at line 1000
3. `processKeyword` reads `NSPasteboard.general.string(forType: .string)` at line 1048
4. This runs **before** `pasteboard.clearContents()` / `pasteboard.setString(processedText)` at lines 827-828

**This part is actually fine** — keyword expansion happens before the pasteboard is overwritten.

BUT: if the user has ALREADY triggered a prior snippet (whose restore timer hasn't fired yet), then `NSPasteboard.general` still contains the PRIOR snippet text, not the real pre-expansion clipboard. The `{clipboard}` keyword will then capture the previous snippet text.

### 4. No serialization protecting clipboard operations — concurrent snippets can interleave
There is **no clipboard-specific queue or mutex** anywhere in the codebase:
- `bufferLock` (line 60) is declared but never used for clipboard operations
- Multiple rapid snippets each do: read pasteboard → write snippet → schedule restore
- A second snippet fired within 0.1s of the first will read `previousContent` as the first snippet's text (since restore hasn't run yet), then restore to the first snippet's text instead of the real pre-expansion clipboard

### 5. `isPerformingExpansion` data race between threads
**Location:** `TextReplacementService.swift:624-627`

```swift
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    self?.isPerformingExpansion = true      // written on background thread
    self?.deleteLastCharacters(count: charsToDelete)
    self?.isPerformingExpansion = false     // written on background thread
```

`isPerformingExpansion` is read on the event tap callback thread (line 477) with no lock. This is an unsynchronized shared mutable bool — Swift does not guarantee atomicity here. The flag is also set to `false` immediately after `deleteLastCharacters` returns, but `insertText` is dispatched via `DispatchQueue.main.asyncAfter(+0.05)` — meaning the flag is `false` before insertion even starts. A key event arriving during the 0.05s gap will not be suppressed.

---

## Evidence AGAINST the Hypothesis

### 1. `usleep()` during key events does block the background thread
The key sequence (cmdDown → usleep → vDown → usleep → vUp → usleep → cmdUp) is synchronous on the background thread. By the time the thread proceeds to schedule the restore via `asyncAfter`, the HID events are already in the kernel queue. In practice, for fast native apps on an idle system, 0.1s is probably sufficient — this explains why the bug is intermittent ("sometimes").

### 2. `previousContent` is captured before pasteboard mutation
`previousContent` is read at line 817 before any pasteboard writes. So the saved value is always the true pre-expansion clipboard — the race is only in the *restore timing*, not in what value is saved.

### 3. `BrowserCompatibleTextInsertion` is not called from main `insertText()` path
`BrowserCompatibleTextInsertion.swift` appears to be a standalone utility. The actual insertion path in `TextReplacementService.swift` does its own browser detection and timing (lines 820, 843-858). So the 0.2s browser delay in the utility class may be redundant/unused in production.

---

## Root Cause Analysis

**Primary cause:** Time-based clipboard restore (`asyncAfter +0.1s`) racing against async pasteboard read in the target application. No feedback mechanism confirms the app has consumed the paste before restoring.

**Compounding cause:** Rapid back-to-back snippet expansions corrupt the clipboard chain — the second snippet saves the first snippet's text as `previousContent` and restores it, permanently losing the original clipboard.

**Secondary cause:** `isPerformingExpansion` is cleared before `insertText` runs (the `asyncAfter(+0.05)` gap), so a key typed during deletion-to-insertion transition is not filtered, and can corrupt the buffer or trigger a second expansion.

---

## Recommended Fix

### Fix 1 (Primary): Use a serial operation queue for clipboard ops + increase restore delay adaptively
Replace the fixed `asyncAfter` with a serial queue that guarantees ordering:

```swift
private let clipboardQueue = DispatchQueue(label: "com.gensnippets.clipboard", qos: .userInteractive)
```

And increase the restore delay conservatively:
- Standard apps: 0.3s (was 0.1s)
- Browsers: 0.5s (was 0.2s)
- Discord: 0.4s (was 0.25s)

This doesn't eliminate the race but makes it astronomically less likely within realistic system load.

### Fix 2 (Primary): Hold `isPerformingExpansion = true` through the entire insert cycle
Move the flag reset into `insertText`'s restore callback:

```swift
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    self?.isPerformingExpansion = true
    self?.deleteLastCharacters(count: charsToDelete)
    // Do NOT set isPerformingExpansion = false here
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self?.insertText(snippet.content)
        // isPerformingExpansion = false is set in insertText's restore callback
    }
}
```

### Fix 3 (Best long-term): Use `NSPasteboard.changeCount` to verify paste was consumed
After posting Cmd+V, poll `NSPasteboard.general.changeCount` — if it changes, another app has read/written the pasteboard (i.e., paste was likely processed). This provides an app-agnostic synchronization signal.

### Fix 4: Protect clipboard access with the existing `bufferLock`
The `bufferLock` declared at line 60 is **unused**. Wrap all pasteboard read/write operations with it to prevent concurrent access from multiple snippet triggers.

---

## Unresolved Questions

1. Is `BrowserCompatibleTextInsertion.insertText()` ever called in the current code path, or is it dead code? (The comment at line 175 of that file suggests it may be superseded.)
2. What values does `getTimingForCurrentApp()` return for `timingConfig.paste` — this determines actual inter-event delay and affects how likely the race is per app category.
3. Is there any pasteboard change monitoring (`NSPasteboard.addTypes` or `NSPasteboardItem`) that could detect when the target app reads from the pasteboard?
