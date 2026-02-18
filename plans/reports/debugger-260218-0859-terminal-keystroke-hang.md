# Debugger Report: Terminal Keystroke Hang (iTerm2/Ghostty)

**Date:** 2026-02-18
**Slug:** terminal-keystroke-hang
**Prior report:** `debugger-260217-1705-snippet-trigger-freeze.md`

---

## Executive Summary

When typing a snippet trigger (e.g. `;gs`) in iTerm2 or Ghostty, the final keystroke (`s`) hangs/gets stuck. Typing `s` twice makes it appear but snippet replacement does not fire. This is a **recurring bug** that has been "fixed" twice but keeps coming back because the real root cause has not been fully addressed.

**Root cause: Three distinct, compounding bugs.** Bug 1 is the primary hang. Bugs 2 and 3 explain why snippet replacement then fails.

---

## Bug 1 (Primary — Keystroke Hang): `isSSHSession()` Blocking the CGEvent Tap Callback

### Location
`EdgeCaseHandler.swift`, lines 194–218, called from `getTimingForCurrentApp()` (line 303–315), called from `deleteLastCharacters()` (line 678) and `insertText()` (line 813).

### What happens

Every time a snippet match is found, `checkForCommands()` dispatches work to `DispatchQueue.global(qos: .userInteractive)`. Inside that dispatch, `deleteLastCharacters()` calls `getTimingForCurrentApp()` which calls `EdgeCaseHandler.detectAppCategory()`. That function walks through detection predicates in order — including `isSSHSession()`.

`isSSHSession()` does this:

```swift
// EdgeCaseHandler.swift lines 194–218
private static func isSSHSession() -> Bool {
    if isTerminal(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()               // <--- SYNCHRONOUS BLOCKING WAIT
            let data = pipe.fileHandleForReading.readDataToEndOfFile()  // <--- BLOCKING READ
            ...
        }
    }
    return false
}
```

**Every time a snippet fires in a terminal, this spawns `/bin/ps aux` and blocks the calling thread** until `ps` completes and its output is read. On macOS, `/bin/ps aux` takes 50–300ms depending on system load.

### Why it causes the keystroke hang

The `deleteLastCharacters()` call chain is dispatched to `DispatchQueue.global(qos: .userInteractive)`. However:

1. `deleteLastCharacters()` is called **synchronously** inside that global dispatch block.
2. `deleteLastCharacters()` calls `getTimingForCurrentApp()` → `detectAppCategory()` → `isSSHSession()` → `Process().waitUntilExit()`.
3. The `userInteractive` GCD thread is **blocked for 50–300ms** waiting for `ps aux`.
4. During this entire time, the `deleteLastCharacters()` function then proceeds to **post CGEvents** (backspace keystrokes) back into the system — into the same HID event queue that the terminal is reading from.
5. The terminal receives backspace events while it is still in the middle of processing the triggering keystroke (`s`). The terminal's readline/input handler is in an intermediate state.
6. Result: the final character (`s`) appears visually delayed or doubled, and the deletion+paste sequence is misaligned.

### Why it recurs

The `isSSHSession()` function is called on **every snippet expansion in any terminal**, not just when SSH is actually running. The function runs `/bin/ps aux` as a precondition check — even if the user is just in a local shell with no SSH process at all.

Previous "fixes" (commits `6d5e953`, `786e436`) added Ghostty/Warp to bundle ID lists but did not touch `isSSHSession()`. The detection order in `detectAppCategory()` means `isSSHSession()` is evaluated **before** `isTerminal()` returns `.terminal`, so the `Process()` spawn always runs for terminal apps:

```swift
// EdgeCaseHandler.swift lines 10–28
static func detectAppCategory() -> AppCategory {
    ...
    if isSSHSession() { return .sshSession }   // <-- runs ps aux EVERY TIME for terminals
    if isTerminal(bundleID) { return .terminal }
    ...
}
```

`isSSHSession()` calls `isTerminal()` internally to gate itself, but it still runs for every terminal app, every single time a snippet fires.

---

## Bug 2 (Secondary — Duplicate Character): `lastCharHandled` Deduplication Race Condition

### Location
`TextReplacementService.swift`, lines 287–297 and 344–353 (inside the CGEvent tap callback).

### What happens

After `handleKeyPress(characters)` is called in the tap callback, the code does:

```swift
service.lastCharHandled = characters
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    if service.lastCharHandled == characters {
        service.lastCharHandled = ""   // reset after 100ms
    }
}
```

And the duplicate-skip condition is:

```swift
if characters != service.lastCharHandled || (currentTime - service.lastKeyTime > 0.01) {
```

**The problem:** `service.lastKeyTime` is set to `currentTime` just before this check (line 276). So `(currentTime - service.lastKeyTime)` is always `~0` — effectively always `<= 0.01`. This means the condition collapses to just `characters != service.lastCharHandled`.

When the terminal receives backspace events from the deletion phase and re-echoes characters (as terminals do), the same character `s` can arrive as a second CGEvent keyDown within the 100ms window where `lastCharHandled == "s"`. The tap callback then skips it as a duplicate. User has to type `s` twice for it to register.

---

## Bug 3 (Secondary — Snippet Not Replacing): `containsCommand()` Called with Stale Buffer After `checkForCommands()` Clears It

### Location
`TextReplacementService.swift`, lines 304–309 (inside the tap callback after `handleKeyPress`).

```swift
service.handleKeyPress(characters)    // this calls checkForCommands(), which clears the match from the buffer
service.lastCharHandled = characters

if service.containsCommand(service.currentInputBuffer) {  // buffer already cleared/modified by checkForCommands
    return Unmanaged.passUnretained(event)
}
return Unmanaged.passUnretained(event)
```

`handleKeyPress()` → `checkForCommands()` will find a match, strip the command from `currentInputBuffer`, and dispatch deletion. Then `containsCommand(service.currentInputBuffer)` is called with the now-stripped buffer — it returns `false`. This is harmless (both paths return the event), but it reveals that `checkForCommands()` fires async deletion on a separate queue while the callback still holds the original event. The event is passed through immediately, which means the terminal **does receive the triggering character** (`s`) before deletion has started.

In a terminal, this means:
- User types `;gs` → terminal echoes `;g`
- `s` keyDown arrives → callback fires → async deletion dispatched → `s` event passed through → **terminal echoes `s`**
- 50–300ms later (after `ps aux`): deletion backspaces fire → terminal sees backspaces → result: `;gs` + 3 backspaces → empty
- Then paste fires → snippet content appears

If the timing is off (due to Bug 1 delay), the sequence breaks.

---

## Why Previous Fixes Failed

| Commit | What it did | Why insufficient |
|--------|-------------|-----------------|
| `6d5e953` | Added `com.mitchellh.ghostty` to terminal lists | Only fixed detection — `isSSHSession()` still runs `ps aux` for Ghostty |
| `786e436` | Added Warp/VSCode to `EdgeCaseHandler.isTerminal()` | Same — `isSSHSession()` still called before `.terminal` path |
| `c9ba908` (JetBrains) | Added `.ide` to `useSimpleDeletion` | Correct for IDEs, not relevant to hang cause |
| `2803d59` | Added event tap timeout recovery | Treats symptom not cause; tap was disabled by slow callbacks |
| `dd3a91f` | Moved `deleteLastCharacters` dispatch to async | Correct fix for blocking in callback, but `isSSHSession()` inside `deleteLastCharacters()` still blocks the async thread and corrupts deletion timing |

---

## Code Paths That Cause the Hang (Annotated)

```
[CGEvent tap callback — dedicated thread]
  keyDown event for "s"
  → handleKeyPress("s")
    → checkForCommands()
      → snippet ";gs" matched
      → DispatchQueue.global(qos:.userInteractive).async {
          deleteLastCharacters(count: 3)             ← async thread blocked here
            → getTimingForCurrentApp()
              → EdgeCaseHandler.detectAppCategory()
                → isSSHSession()                     ← SPAWNS /bin/ps aux
                  → Process().waitUntilExit()        ← BLOCKS 50–300ms
                  → pipe.readDataToEndOfFile()       ← BLOCKS until EOF
              ← returns .terminal timing
            → posts 3x backspace CGEvents            ← arrives AFTER 50–300ms delay
            → returns
          DispatchQueue.main.asyncAfter(0.05) {
            insertText(snippet.content)              ← paste fires ~350ms after "s"
              → getTimingForCurrentApp()             ← SPAWNS /bin/ps aux AGAIN
          }
        }
  ← callback returns immediately (event passed through)

[Terminal receives]: s → (50–300ms gap) → ← ← ← (backspaces) → paste content
```

**Note:** `getTimingForCurrentApp()` is called twice per snippet expansion — once in `deleteLastCharacters()` and once in `insertText()`. That means `/bin/ps aux` is spawned **twice per snippet trigger** in terminals.

---

## Recommendations

### Fix 1 (Critical): Cache or eliminate `isSSHSession()` blocking call

**Option A — Cache the result per frontmost app change (recommended):**

```swift
// In EdgeCaseHandler or TextReplacementService
private static var cachedAppCategory: AppCategory?
private static var cachedBundleID: String?

static func detectAppCategory() -> AppCategory {
    let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    if bundleID == cachedBundleID, let cached = cachedAppCategory {
        return cached
    }
    let category = detectAppCategoryUncached(bundleID: bundleID)
    cachedBundleID = bundleID
    cachedAppCategory = category
    return category
}
```

**Option B — Make `isSSHSession()` non-blocking (simpler short-term fix):**

Replace the synchronous `Process().waitUntilExit()` with an async check that caches the result. Or simply remove the SSH auto-detection entirely and treat it as `.terminal` — the timing difference between `.terminal` and `.sshSession` is only 2ms in paste delay (1ms vs 3ms), which is not worth a 50–300ms process spawn.

**Option C — Remove `isSSHSession()` from the synchronous path:**

```swift
static func detectAppCategory() -> AppCategory {
    guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
        return .unknown
    }
    if isPasswordField() { return .passwordField }
    if isDiscord(bundleID) { return .discord }
    if isVMApp(bundleID) { return .virtualMachine }
    if isRemoteDesktop(bundleID) { return .remoteDesktop }
    if isElectronApp(bundleID) { return .electronApp }
    if isIDE(bundleID) { return .ide }
    if isGame(bundleID) { return .game }
    if isTerminal(bundleID) { return .terminal }  // MOVE BEFORE isSSHSession
    // isSSHSession only if needed, as async background check
    if isBrowser(bundleID) { return .browser }
    return .standard
}
```

Moving `isTerminal()` before `isSSHSession()` means `detectAppCategory()` returns `.terminal` immediately for iTerm2/Ghostty without ever calling `isSSHSession()`. SSH inside a terminal gets `.terminal` timing — which is correct anyway since it's the same app.

### Fix 2 (Significant): Fix `lastKeyTime` comparison in dedup logic

Line 288 in `TextReplacementService.swift`:

```swift
// CURRENT (broken — lastKeyTime was just set to currentTime so difference is always ~0):
if characters != service.lastCharHandled || (currentTime - service.lastKeyTime > 0.01) {

// FIXED — track lastCharHandledTime separately:
if characters != service.lastCharHandled || (currentTime - service.lastCharHandledTime > 0.1) {
```

Add `private var lastCharHandledTime: TimeInterval = 0` and set it when `lastCharHandled` is set.

### Fix 3 (Minor): Suppress expansion during terminal delete/paste cycle

When `deleteLastCharacters()` is running (i.e., GenSnippets itself is posting backspace events), the terminal will echo those backspaces back through the HID event stream. The event tap will see them and potentially add `\u{7F}` to the buffer. Add a flag:

```swift
private var isPerformingExpansion = false

// In deleteLastCharacters, set flag before posting events:
isPerformingExpansion = true
defer { isPerformingExpansion = false }

// In handleKeyPress, guard at top:
guard !isPerformingExpansion else { return }
```

---

## Root Cause Summary

| # | Bug | Severity | File/Lines | Fix |
|---|-----|----------|-----------|-----|
| 1 | `isSSHSession()` spawns `/bin/ps aux` synchronously on every snippet trigger in terminals, blocking 50–300ms and corrupting deletion timing | **Critical** | `EdgeCaseHandler.swift:194–218`, called from `getTimingForCurrentApp()` | Move `isTerminal()` check before `isSSHSession()` in `detectAppCategory()`, or cache/remove `isSSHSession()` |
| 2 | `lastCharHandled` dedup comparison uses `lastKeyTime` which is always `currentTime` — dedup window is effectively 0ms, causing terminal echo chars to be misidentified as duplicates | **Significant** | `TextReplacementService.swift:288,344` | Track `lastCharHandledTime` separately |
| 3 | GenSnippets-posted backspace events re-enter the event tap, adding noise to the buffer during expansion | **Minor** | `TextReplacementService.swift:handleKeyPress` | Add `isPerformingExpansion` guard flag |

---

## Why `;gs` Specifically Triggers This

`;gs` is a 3-character command. With `useSimpleDeletion = true` for terminals, `deleteLastCharacters()` posts 3 individual backspace pairs with 1ms delays each = 6ms minimum in deletion events, **but only after `isSSHSession()` unblocks (~50–300ms)**. The terminal sees: press `s` → long pause → 3 backspaces at once → paste. This is jarring and breaks the terminal's readline assumptions.

Typing `s` twice: the second `s` arrives after `lastCharHandled` has been reset (100ms timer), so it passes the dedup check and gets echoed normally — explaining why "typing `s` twice makes it appear." The snippet still doesn't expand because `checkForCommands()` already fired and cleared the match on the first `s`.

---

## Unresolved Questions

- Does Ghostty use a different bundle ID in some versions? (Current: `com.mitchellh.ghostty`) — check if hang reproduces in Ghostty vs iTerm2; if only one, bundle ID might differ.
- Is the `isSSHSession()` feature actually used/tested? The per-app timing difference vs `.terminal` is minimal; worth considering removing it entirely.
- Fix 2 — does the dedup logic exist to solve a specific IME (input method) bug? Need to confirm what scenario `lastCharHandled` was originally introduced to fix before modifying it.
