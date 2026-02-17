# Debugger Report: Snippet Trigger Freeze

**Date:** 2026-02-17
**Slug:** snippet-trigger-freeze

---

## Executive Summary

The app freezes/hangs when a snippet trigger is typed. Root cause is **NOT** the image file I/O itself — it is a **deadlock in `forceSave()`** called from `migrateBase64ImagesToFiles()`, which is called during `loadSnippets()` on the **main thread**. A secondary contributing factor is the CGEvent tap callback performing synchronous blocking I/O (`Thread.sleep`, `usleep`) on the **event tap thread**, which causes macOS to disable the tap with `tapDisabledByTimeout`.

There are **two distinct bugs**. Both must be fixed.

---

## Bug 1 (Critical): Deadlock in `forceSave()` → `saveQueue.sync(flags: .barrier)`

### Call Chain

```
LocalSnippetsViewModel.init()           [main thread]
  → loadSnippets()                      [main thread]
    → migrateBase64ImagesToFiles()      [main thread]
      → localStorageService.saveSnippets()   → saveQueue.async(flags:.barrier)  ← queues work
      → localStorageService.forceSave()
          → saveQueue.sync(flags:.barrier)   ← DEADLOCK
```

### Why it deadlocks

`LocalStorageService.saveQueue` is a **concurrent** queue. `forceSave()` calls `saveQueue.sync(flags: .barrier)` from the **main thread**.

`saveSnippets()` — called just before `forceSave()` — enqueues a `.barrier` block on `saveQueue` asynchronously. That barrier block **cannot start** until the current sync-barrier call acquires exclusive access, but the sync-barrier call itself is **waiting** for the queue to drain before it can acquire access. Result: deadlock.

Relevant code in `LocalStorageService.swift`:

```swift
// saveSnippets() — async barrier write
func saveSnippets(_ snippets: [Snippet]) {
    saveQueue.async(flags: .barrier) {     // <-- enqueues barrier block
        self.cachedSnippets = snippets
        self.pendingSnippetSave = true
        self.scheduleSave()
    }
}

// forceSave() — sync barrier, called immediately after saveSnippets()
func forceSave() {
    ...
    saveQueue.sync(flags: .barrier) {      // <-- DEADLOCKS waiting for async barrier above
        ...
    }
}
```

In `LocalSnippetsViewModel.migrateBase64ImagesToFiles()`:

```swift
if didMigrate {
    localStorageService.saveSnippets(snippets)   // queues async barrier
    localStorageService.forceSave()              // sync barrier on same queue → DEADLOCK
}
```

**Additionally**: `loadSnippets()` in `LocalStorageService` itself uses `saveQueue.sync(flags: .barrier)` (line 168). If `migrateBase64ImagesToFiles()` is called while still on the main thread with a pending barrier, any re-entrant call to `loadSnippets()` would also deadlock.

### Fix for Bug 1

Option A (simplest — remove `forceSave()`): The migration already calls `saveSnippets()` which schedules a 0.5s batched save. `forceSave()` is unnecessary here. Remove it.

```swift
// LocalSnippetsViewModel.swift — migrateBase64ImagesToFiles()
if didMigrate {
    localStorageService.saveSnippets(snippets)
    // REMOVE: localStorageService.forceSave()
    print("[LocalSnippetsViewModel] Migrated Base64 images to file-based storage")
}
```

Option B (if immediate persistence is required): Run migration off the main thread:

```swift
private func migrateBase64ImagesToFiles() {
    DispatchQueue.global(qos: .utility).async { [weak self] in
        guard let self = self else { return }
        let richContentService = RichContentService.shared
        var updatedSnippets = self.snippets
        var didMigrate = false
        for (index, snippet) in updatedSnippets.enumerated() {
            if let migrated = richContentService.migrateSnippetImages(snippet) {
                updatedSnippets[index] = migrated
                didMigrate = true
            }
        }
        if didMigrate {
            self.localStorageService.saveSnippets(updatedSnippets)
            self.localStorageService.forceSave()
            DispatchQueue.main.async {
                self.snippets = updatedSnippets
            }
        }
    }
}
```

**Recommended: Option A** — migration data is written to disk within 0.5s by the batch timer, which is acceptable.

---

## Bug 2 (Significant): CGEvent Tap Disabled by Timeout Due to Blocking I/O

### What happens

The CGEvent tap callback runs on a **dedicated event tap thread** managed by macOS. macOS enforces a strict timeout (~1 second). If the callback does not return within the timeout, macOS **automatically disables** the event tap (`tapDisabledByTimeout`), causing the keyboard to stop responding until the tap is manually re-enabled.

`checkForCommands()` → `deleteLastCharacters()` and `insertText()` both call:

```swift
Thread.sleep(forTimeInterval: timingConfig.deletion)   // blocking
usleep(delay)                                          // blocking
```

These are **synchronous sleeps inside the event tap callback chain**. For snippets with many characters to delete or long paste delays, the callback can exceed the macOS timeout.

The code already has logging for this (`⚠️ Slow callback`) and auto-re-enable logic, but the re-enable has a 10s check timer — that's a 10s freeze from the user's perspective.

Note: `loadImageSmart` (file I/O via `Data(contentsOf:)`) is called from `insertSingleItem()` which is dispatched via `DispatchQueue.main.asyncAfter` **after** the event callback returns — so it does NOT directly block the event tap thread. However, if `loadImageSmart` is ever called synchronously during snippet matching it would be a problem.

### Fix for Bug 2

Move all blocking operations out of the synchronous callback path. `checkForCommands()` should dispatch the deletion+insertion to a background queue and return immediately from the callback.

The existing code already partially does this (lines 625, 638: `DispatchQueue.main.asyncAfter`), but `deleteLastCharacters()` is called **synchronously** before the dispatch. Fix:

```swift
// In checkForCommands(), replace synchronous deleteLastCharacters() call:
// BEFORE:
deleteLastCharacters(count: charsToDelete)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ... }

// AFTER:
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    self?.deleteLastCharacters(count: charsToDelete)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ... }
}
```

This ensures the event tap callback returns immediately and macOS never disables the tap.

---

## Secondary Observations (Non-blocking)

1. **`loadSnippets()` double-load**: `LocalStorageService.init()` calls `loadSnippets()` and `LocalSnippetsViewModel.loadSnippets()` also calls it. The cache prevents double disk reads, but the init-time `saveQueue.sync(flags:.barrier)` in `LocalStorageService.loadSnippets()` is called from `LocalStorageService.init()` which is `private init()` — fine as long as nothing has yet enqueued on `saveQueue`.

2. **`isFilePath()` in `loadImageSmart()`**: Calls `FileManager.default.fileExists(atPath:)` which is a filesystem syscall. For every rich-content snippet insertion this is called on whatever thread `insertSingleItem` runs on. Currently safe (dispatched off event tap thread), but worth noting.

3. **Migration `hasRunMigration` flag**: Instance var on `LocalSnippetsViewModel`. If multiple `LocalSnippetsViewModel` instances are created (e.g. view model recreated by SwiftUI), migration could run multiple times. Consider persisting flag in `UserDefaults`.

---

## Root Cause Summary

| # | Cause | Severity | File | Fix |
|---|-------|----------|------|-----|
| 1 | `forceSave()` calls `saveQueue.sync(flags:.barrier)` immediately after `saveSnippets()` queues an async barrier on the same queue → deadlock on main thread | **Critical** | `LocalSnippetsViewModel.swift:59`, `LocalStorageService.swift:376` | Remove `forceSave()` call from migration |
| 2 | `deleteLastCharacters()` uses `Thread.sleep`/`usleep` synchronously inside CGEvent tap callback → macOS disables event tap → keyboard freeze | **Significant** | `TextReplacementService.swift:685-748` | Dispatch deletion to background queue |

---

## Unresolved Questions

- None. Both root causes identified with high confidence from code analysis.
