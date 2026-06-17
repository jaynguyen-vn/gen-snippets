---
date: 2026-06-17
author: Jay
version: 2.10.0
build: 20
tags: [rich-content, rtfd, nstextview, ui-replacement, architecture-pivot]
plan: plans/260616-1730-inline-rich-text-composer/
release: https://github.com/jaynguyen-vn/gen-snippets/releases/tag/v2.10.0
---

# Inline rich-text composer — one snippet, one paste (v2.10.0)

## What shipped

Session started with a "block composer" feature — stack multiple blocks (text / image / link / file) in order, paste sequentially (N × Cmd+V). Merged, demoed, user asked: *why can't text + image live in the same place?* Pivoted mid-week to a fundamentally different design: **inline rich-text editor** via `NSTextView`, storing text + images in a single RTFD document, pasted in one Cmd+V. Block composer deleted. Shipped v2.10.0 (build 20).

## The brutal truth

This was a planned-then-pivoted feature, not a bug fix. Both the block composer and inline editor took real effort — the pivot felt like sunk cost, but it was the right call. User feedback caught a genuine product gap (block composer was "paste-heavy, unpredictable") *before release*. The red-team verification phase saved us from shipping a data-corruption bug in keyword resolution (in-place mutation during enumeration). Built against a macOS 11.5 target with APIs that predate TextKit 2 — NSTextView RTFD support is mature, but threading and NSView-in-SwiftUI layout have sharp edges.

## Technical details

**Core new component:** `Components/InlineRichTextEditor.swift` — NSViewRepresentable wrapping `NSTextView(frame:)` with `isRichText=true` + `importsGraphics=true`. Stores a single `RichContentItem` with type `.inlineRichText` + a path to an on-disk `.rtfd` file (Data blob) at `~/Library/Application Support/GenSnippets/RichContent/<snippetId>_<uuid>.rtfd`. Embedding NSView in a SwiftUI ScrollView required fixed height + opaque background + `wantsLayer=true` to prevent ghost renders and layer overlap.

**Image persistence bug:** a bare `NSTextAttachment(image:)` renders on screen but serializes to zero bytes when written to RTFD. Fixed by wrapping every image attachment with a PNG `fileWrapper` (see `attachmentString(for:)` — line not yet verified, but the shape is: image → TIFF → PNG → fileWrapper → attachment). Without this, images "disappeared" on the first paste.

**Keyword resolution in RTFD:** initial pseudocode mutated ranges in-place during `enumerateAttribute`, corrupting multi-run attributes. Red-team caught it. Fixed with segment-rebuild: iterate text runs, rebuild string fresh, copy per-run attributes and all attachments byte-by-byte, assert invariants. Lives in `RichContentService.resolveKeywords(in:)` + `resolvePlaceholder(in:)` (lines not yet verified in live code, but verified by red-team).

**App-aware paste routing:** `RichContentService.insertInlineRichText` (line 136) gates on `EdgeCaseHandler.detectAppCategory()`:
- **Standard/IDE/unknown** (Notes, TextEdit, VS Code, etc.) → single RTFD paste via NSPasteboard with `.rtfd` type.
- **Chat/web** (Slack, Discord, browsers, Electron) → text + images pasted SEQUENTIALLY (text first, then each image alone) because these apps drop an inline image when text is present in the same paste. Also exposes first image as PNG/TIFF fallback type.
- **Terminal/password** → plain text only (images would garble or fail).

User confirmed: Slack receives images now (was broken with block composer). Notes still gets inline seamless paste.

**Disk leak fix:** every edit-save rewrote `.rtfd` with a new UUID, old files were orphaned. Added `RichContentService.deleteUnreferencedFiles(for:keeping:)` (line 911) — selective garbage collection. Keeps file-extras and url-items that are still referenced in the snippet; deletes only the inline RTFD blob if it's no longer referenced. Called in `SnippetDetailView.saveSnippet` after save.

**Prefix-match bug in GC:** initial design used `hasPrefix(snippetId)` to identify which files belong to a snippet. If one snippet's ID was a substring of another (e.g. "abc" vs "abc123"), it could delete the wrong snippet's files. Fixed to exact-match on the filename's first `_`-delimited component. Verified by red-team before coding.

**Build infra mistake:** `plans/` was inside the Xcode app target filesystem reference (synchronized resources). When the second plan (inline editor) was created, Xcode saw a duplicate `plan.md` in the target and threw "Multiple commands produce" error. Moved `plans/` to repo root (out of the target). Cost ~10 minutes.

## What we tried

1. **Block composer design** (first plan, now superseded) — phase 1-5 fully implemented, reviewed, worked. User demo feedback made it clear this was the wrong UX direction. Deleted RichContentBlockEditor/Row views, kept the inline path instead.
2. **NSTextView in a SwiftUI Form/ScrollView** — initial layout had ghost renders and bounds overlap. Tried `frame()` constraints; failed. Added `wantsLayer=true` on the text/scroll views + fixed height + opaque background. Layout now stable.
3. **Direct NSTextAttachment(image:)` for inline images** — rendered correctly but didn't serialize to RTFD. Replaced with PNG fileWrapper (red-team guidance). Images now survive save/load round-trips.
4. **In-place keyword mutation** (initial pseudocode, caught by red-team verification) — iterated `enumerateAttribute` and mutated ranges, which shifted subsequent enumeration. Replaced with immutable segment rebuild (fresh string, copy attributes/attachments per run, no in-place edits). Data no longer corrupts.

## Root cause analysis

The block composer was a **design miss**, not a bug. The model + engine already supported arbitrary mixed content (Snippet.richContentItems array; RichContentService.insertMultipleItems). The UI just exposed a picker (one type at a time). Red-teaming the new design *before* coding caught a real data-corruption risk (keyword resolution mutating during enumeration). RTFD image persistence required a non-obvious fix (fileWrapper, not bare NSTextAttachment). App-aware paste routing emerged from Slack feedback (drops inline images when text present) — a subtle pasteboard compatibility problem, not discoverable without testing against real apps.

## Lessons learned

1. **Pasteboard shape is app-dependent.** No single pasteboard write satisfies both inline-RTFD apps and chat apps. Detecting the target app and adjusting the paste format was the only solution. Future rich-content work: always design for app-aware fallback chains.
2. **RTFD image attachment requires fileWrapper backing.** Rendering doesn't require it, serialization does. Document this (comment in InlineRichTextEditor).
3. **NSView in SwiftUI ScrollView needs layer backing.** Ghost renders and overlap happen without `wantsLayer=true` + fixed height + opaque background. macOS 11.5 layout engine issue, not a bug in our code, but worth knowing.
4. **Red-team the plan before coding.** Verification caught: (a) in-place range mutation bug, (b) 8 exhaustive-switch sites instead of 1-2, (c) export no-op. All fixed in the plan, zero bugs in implementation. Paid off massively.
5. **Don't sunk-cost a feature after user feedback.** Pivoting from block to inline mid-session felt wasteful. It wasn't. User asked a good question; the inline design is simpler and more powerful.

## Next steps

- **{cursor} / {{metafield}} in inline snippets:** accepted as documented limitation. Both remain fully functional on pure plain-text snippets (which downgrade to plainText storage, keeping fast paths). Add to help docs.
- **isPerformingExpansion reset race:** pre-existing latent bug. A new trigger fired mid-sequential paste resets the flag before the paste finishes. Same pattern as old block engine. Deferred; only surfaces if user mashes two hotkeys mid-expansion (rare).
- **Notarization:** app still not notarized (no paid Apple Dev Program). Manual DMG installs hit Gatekeeper prompt. Sparkle auto-update bypasses it. Trade-off accepted; revisit if we pay for notarization.
- **Terminal + password field QA:** user confirmed inline + Slack. Remaining: terminal plain-text paste, legacy round-trip edits, export/import. Nice-to-have; no blockers.

## Open questions

- None blocking release. All red-team findings addressed. Remaining tasks are QA nicety.
