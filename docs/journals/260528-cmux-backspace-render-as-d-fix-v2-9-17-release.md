---
date: 2026-05-28
author: Jay
version: 2.9.17
build: 19
tags: [text-replacement, terminal, cmux, edge-case-handler, debugging]
plan: plans/260528-0915-cmux-backspace-render-as-d-fix/
release: https://github.com/jaynguyen-vn/gen-snippets/releases/tag/v2.9.17
---

# Snippet expansion in cmux — backspaces rendering as "D" chars (v2.9.17)

## The report

User: "thỉnh thoảng khi anh gõ cái snippet ở trong cmux, nó sẽ bị render ra rất nhiều ký tự. Anh new một cái terminal mới thì không bị. Chỉ là gõ trong cái terminal đã chạy rồi ấy thì nó bị thôi."

Screenshot evidence: `;ssh-md-devDDDDDDDDDDDDssh -i /Users/jay/md-dev-jay-vega ubuntu@18.232.190.103 -p 2026`. Command intact, 12 garbage `D`s, snippet text correctly pasted at the end.

## The wrong first guess

Given recent commits `c1d6032` (clipboard spin-wait), `0541b81` (flag-reset decoupling), `8ce56a3` (perf delay reductions for terminal cursorDelay/restoreDelay), my initial confidence-80% hypothesis was a stale-clipboard regression from the perf commit — the `restoreDelay = 0.15s` for terminal racing against slow long-lived terminal clipboard reads, causing a stale-clipboard paste of previously-copied content, which would look like "lots of characters."

Wrong. The screenshot showed snippet text was **correctly** pasted — the wrong characters were **before** the snippet, not the snippet content itself. The bug was deletion, not paste.

Lesson re-learned (from `review-audit-self-decision.md` rule 4): "Scout first, ask second" — but also **let the artifact override the theory**. One image collapsed the confidence-80% hypothesis to 0% in one second.

## The real root cause

`cmux` is `com.cmuxterm.app` — a Rust + native-wrapped TUI terminal (Sentry, PostHog, Sparkle, `libcmux_command_palette_nucleo_ffi.dylib`, `feed-tui` folder — same shape as Warp). It was **not** in `EdgeCaseHandler.isTerminal()`. So `detectAppCategory` returned `.default`, which means:

- `deletionDelay = 0.5ms`
- `pasteDelay = 0.8ms`
- `useSimpleDeletion = false` — uses the batched path in `deleteLastCharacters` for `count > 3`

At 0.5ms per keyDown/keyUp pair in batched mode, cmux's Rust input pipeline can't keep up with the synthesized `CGEvent(virtualKey: 0x33)` (Backspace) burst — events get dropped or mistranslated, rendering as printable garbage. The "in long-lived sessions" qualifier likely means cmux's input handler initializes lazily after the PTY warms up; in fresh sessions the rendering path is still in its startup state and behaves differently.

What I don't know — and didn't need to learn to fix: the exact translation path `keycode 0x33 → "D"`. Could be keystroke coalescing under fast posting, Rust-side ICU translation of `virtualKey` via secondary layout, or an Accessibility-API text-input path that ignores special-key semantics. Phase 1 of the plan was an instrumentation matrix to determine this; we skipped it.

## The fix

```swift
// EdgeCaseHandler.swift, isTerminal()
private static func isTerminal(_ bundleID: String) -> Bool {
    let terminalApps = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        // ... existing entries ...
        "com.microsoft.VSCode",
        // Rust + native-wrapped TUI terminal. Has its own input pipeline that
        // drops fast-coalesced backspace events at the default 0.5ms cadence
        // and renders them as printable garbage in long-lived sessions.
        "com.cmuxterm.app"
    ]
    return terminalApps.contains(bundleID)
}
```

One identifier added. cmux now flows through `.terminal` category: `deletionDelay = 1ms`, `pasteDelay = 5ms`, `useSimpleDeletion = true` (forces individual `down → sleep → up → sleep` per event, bypassing the batched path), plus the existing 50ms pasteboard `changeCount` spin-wait + content verify in `insertText`.

User confirmed clean expansion in cmux long-lived session after Debug-build install.

## Plan structure & what we skipped

| Phase | Designed for | Outcome |
|-------|--------------|---------|
| 1 — Diagnostics & repro | Instrumentation matrix `(stroke × delay)` to identify whether `virtualKey 0x33` was salvageable at all | **Skipped** — not needed |
| 2 — Register cmux as terminal | 1-line bundle ID addition | ✓ Shipped |
| 3 — Robust deletion fallback | Add `isOpaqueInputTerminal()` + alternative stroke (Ctrl+H) for terminals where virtualKey 0x33 is fundamentally unrecognized | **Skipped** — not needed |
| 4 — Verify & ship | DMG, Sparkle sign, GitHub release | ✓ Shipped |

Pragmatic execution order beat the plan's cautious order: try the cheapest fix first (Phase 2 is 1 line) and let the user reproduce. If Phase 2 had failed, instrument; we'd have lost nothing. YAGNI for Phase 1 + 3 in the happy path.

## Pattern worth keeping

**The default `.default` category is too aggressive for non-AppKit input handlers.** Every Rust/Tauri/Electron/TUI-rendered terminal that emerges is going to have the same problem. The current allowlist approach scales linearly with terminal-of-the-week. Two options to consider next time this surfaces:

1. **Detection heuristic:** sniff for Rust/Tauri/Electron framework presence under `app.bundlePath/Contents/Frameworks` and treat as `.electronApp` or a new `.opaqueInput` category. Less precise but auto-handles new apps.
2. **Conservative default:** raise `.default` deletion cadence to 1ms + `useSimpleDeletion = true`. Marginally slower for AppKit-native apps (imperceptible — ~5ms extra on an 11-char delete) but defensive against unknown apps. Probably the right call; needs an audit of who currently depends on the 0.5ms cadence for perceived snappiness.

Option 2 is the more durable architectural fix. Filed mentally; not blocking 2.9.17.

## Time

User report → DMG signed and on GitHub: ~75 minutes. Most of that was planning (correctly retracting wrong hypothesis after image) and the release pipeline. Actual code change: < 30 seconds.

## Open questions

- Cmux's exact `keycode 0x33 → "D"` translation rule. Resolvable via Phase 1 instrumentation if any future cmux-specific regression surfaces. Not blocking.
- Whether Ghostty / Wezterm / Hyper / Tabby suffer the same issue at 0.5ms cadence. Defer until a user report surfaces.
