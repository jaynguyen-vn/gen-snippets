---
name: Event Tap Timeout Investigation
description: Analysis of CGEvent tap timeout hypothesis causing intermittent snippet failures in terminal apps
type: project
---

# Event Tap Timeout — Findings Report

**File analyzed:** `GenSnippets/Services/TextReplacementService.swift`
**Secondary:** `GenSnippets/Services/EdgeCaseHandler.swift`
**Date:** 2026-03-14

---

## Executive Summary

The CGEvent tap timeout hypothesis is **partially confirmed but incomplete**. The callback itself returns quickly and dispatches heavy work asynchronously, so it's unlikely to exceed macOS's timeout threshold under normal conditions. However, there are **two compounding issues** that together explain the "terminal sometimes doesn't work" symptom:

1. **`isSSHSession()` was a 50–300ms blocking call on every keystroke** (now guarded away but the guard is fragile)
2. **`detectAppCategory()` — called from within the event tap callback path — calls `CGWindowListCopyWindowInfo` and `NSWorkspace.shared.frontmostApplication`**, which are non-trivial system calls executed synchronously in the callback

The 10s check timer gap means once the tap is disabled, snippets stay dead for up to 10 seconds before auto-recovery. Opening a new terminal triggers a focus-change app-switch, likely coinciding with the 10s timer cycle or causing macOS to re-evaluate tap state.

---

## Evidence FOR Timeout Hypothesis

### 1. `isGame()` calls `CGWindowListCopyWindowInfo` on every expansion (EdgeCaseHandler.swift:166–183)

`detectAppCategory()` is called inside `getTimingForCurrentApp()`, which is called from:
- `deleteLastCharacters()` — line 686
- `insertText()` — line 820

Both are dispatched off the tap thread via `DispatchQueue.global(qos: .userInteractive).async` (line 624), so they do NOT run synchronously in the callback. This is **correctly handled**.

### 2. The callback does do synchronous work before dispatching

Within the tap callback (lines 241–368), before the async dispatch:
- Creates `NSEvent(cgEvent: event)` — line 281 (allocates ObjC object, calls into AppKit)
- Reads `nsEvent.characters` — may involve input method processing
- Falls back to `TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()` — line 316 (Carbon API, can block for IME queries)
- Calls `UCKeyTranslate()` — line 323 (fast, but Carbon)
- Calls `service.checkForCommands()` — synchronously in the callback (line 265, 292, 347, 528, 547)

### 3. `checkForCommands()` runs synchronously in the callback

`checkForCommands()` is called from `handleKeyPress()` (lines 528, 547), which is called directly from the event tap callback (lines 292, 346). Inside `checkForCommands()`:
- `snippetQueue.sync { ... }` — **blocking synchronous lock** (line 592)
- Iterates all snippets to find a suffix match

If the snippet list is large AND `snippetQueue` is contended (e.g., `updateSnippets` is running a barrier write), this `sync` blocks the callback thread until the barrier completes.

### 4. 10-second recovery gap (line 400)

```swift
self?.eventTapCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { ... }
```

Once disabled, snippets are dead for up to 10s. If the tap re-enables in the callback's `tapDisabledByTimeout` handler (line 236), that's immediate — but only fires when the NEXT key event arrives. If the user stops typing, the tap never self-heals.

### 5. `isSSHSession()` is a 50–300ms blocking bomb (EdgeCaseHandler.swift:195–219)

```swift
private static func isSSHSession() -> Bool {
    let task = Process()
    task.launchPath = "/bin/ps"
    task.arguments = ["aux"]
    // ... task.waitUntilExit() ...
}
```

This runs `/bin/ps aux` and waits for it. **On a loaded system, this can take 50–300ms.** The comment in `detectAppCategory()` (line 16–17) says `isTerminal()` must come BEFORE `isSSHSession()` to avoid this. The guard works: `isSSHSession()` is never called from `detectAppCategory()` — it's a dead path (the method exists but is not called). However, if someone adds it back, it would fire on every expansion in a terminal.

### 6. Re-enable in `tapDisabledByTimeout` handler only fires on next keypress

```swift
// line 236
CGEvent.tapEnable(tap: service.eventTap!, enable: true)
```

This is correct, but it means the tap self-heals only when the NEXT keystroke arrives. In a server/SSH session where you're reading output and not typing, there's a window where the tap is dead and nothing triggers recovery.

---

## Evidence AGAINST / Alternative Explanations

### 1. The callback returns fast in the normal path

In the fast path (NSEvent character extraction, lines 281–310):
- `NSEvent(cgEvent:)` + `.characters` — typically < 1ms
- `handleKeyPress()` → `checkForCommands()` → `snippetQueue.sync` → O(n) suffix scan
- On match, dispatches to `DispatchQueue.global` immediately and returns

The tap callback itself does not do heavy I/O or blocking system calls in the common path. macOS's timeout is ~1 second; a few milliseconds of synchronous work won't trigger it.

### 2. The `tapDisabledByTimeout` self-heal is present

Line 236 re-enables the tap when it fires. This means the tap CAN survive timeout events without waiting for the 10s timer. The issue is only if the user stops typing before the recovery keystroke arrives.

### 3. Thread-safety could explain terminal issues better

`isPerformingExpansion` (line 133) is read/written from multiple contexts:
- Written in `DispatchQueue.global` async block (lines 625–627)
- Read in `handleKeyPress()` (line 477), which is called from the event tap callback (running on the tap's thread)

No atomic/lock protection. If `isPerformingExpansion = true` is set on `global` queue and the tap fires on its own thread simultaneously, the callback reads a stale value → silently drops keystrokes → snippets appear broken.

### 4. Focus change explanation for "new terminal fixes it"

Opening a new terminal causes:
- App activation → `NSWorkspace` notifies frontmost app change
- The new terminal window gets focus, which may trigger a new run-loop iteration on the tap's thread
- This coincides probabilistically with the 10s timer firing

This is timing coincidence, not a direct fix mechanism — **unless** the focus change itself causes the tap's run loop to service a pending re-enable.

---

## Root Cause Analysis

**Primary cause: The event tap can be disabled by macOS (`tapDisabledByTimeout`) when the callback is slow under load, AND the self-heal mechanism requires a subsequent keypress to trigger.**

In practice, for the terminal/SSH scenario:
1. User types in terminal; callback is slightly slower due to `snippetQueue.sync` contention or `NSEvent(cgEvent:)` under load
2. macOS disables the tap (logs `tapDisabledByTimeout`)
3. The tap re-enables itself immediately on the NEXT keypress (line 236) — so this is transient
4. BUT: if the user pauses typing (reading server output), no keypress arrives, tap stays dead
5. The 10s timer eventually fires and calls `checkAndReenableEventTap()` → re-enables

**Secondary cause: `snippetQueue.sync` in callback path creates contention risk**

When `updateSnippets()` fires a barrier write (e.g., user saves settings while in terminal), `checkForCommands()` blocks waiting for the barrier. This extends callback time for every keypress during the write.

**Why opening a new terminal fixes it:**
- Typing the new terminal path causes a keypress → line 236 fires → tap re-enables immediately
- User perceives it as "new terminal fixed it" but it's actually the next keystroke after opening it

---

## Recommended Fixes (Priority Order)

### Fix 1 (HIGH): Remove `snippetQueue.sync` from callback path

`checkForCommands()` currently does `snippetQueue.sync` on line 592, blocking the tap callback. This is unnecessary since `sortedSnippetsCache` is only mutated by `updateSnippets()` (which posts on a background queue and isn't called frequently). Replace with a separate `@volatile`-equivalent or atomic snapshot:

```swift
// Instead of snippetQueue.sync inside checkForCommands(),
// maintain a separate copy updated atomically
private var _snippetsCacheCopy: [Snippet] = []  // updated after barrier write completes
```

Or at minimum, use `snippetQueue.sync` only when cache is stale (add a dirty flag).

### Fix 2 (MEDIUM): Reduce check timer to 2–3s instead of 10s

```swift
// line 400: change 10.0 → 2.0
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true)
```

Reduces the dead window from up to 10s to up to 2s when the user stops typing.

### Fix 3 (MEDIUM): Fix `isPerformingExpansion` thread-safety

Change `private var isPerformingExpansion = false` to use atomic access:
```swift
private let _isPerformingExpansion = OSAllocatedUnfairLock(initialState: false)
```
Or protect with `bufferLock` that already exists.

### Fix 4 (LOW): Cache `TISCopyCurrentKeyboardLayoutInputSource()` result

Line 316 calls `TISCopyCurrentKeyboardLayoutInputSource()` on every keypress in the fallback path. This is a Carbon API that queries the input source system. Cache it and invalidate on `kTISNotifySelectedKeyboardInputSourceChanged`.

### Fix 5 (LOW): Add proactive re-enable on `NSWorkspace` app-switch notification

Instead of relying on keypress or 10s timer, subscribe to `NSWorkspace.didActivateApplicationNotification` and immediately verify + re-enable the tap. This would handle the "stopped typing while reading server output" case.

---

## Unresolved Questions

1. **Has `tapDisabledByTimeout` actually been observed in logs?** The logging is present (line 227) but we have no log samples. If it never fires, the root cause is elsewhere (thread-safety or clipboard race).
2. **How large is the user's snippet list?** The O(n) scan in `checkForCommands()` with `snippetQueue.sync` is O(n) — with 500+ snippets and a contended barrier write, this could measurably extend callback time.
3. **Is `NSEvent(cgEvent: event)` documented to be safe inside a CGEvent tap callback?** Creating AppKit objects from a CGEvent tap's Mach port thread is undocumented. If AppKit does synchronous IPC here, this could be a hidden source of delay.
4. **Terminal app specifics:** Ghostty/iTerm2 may have their own event tap or input method hooks that interact with GenSnippets' tap. No investigation done here.
