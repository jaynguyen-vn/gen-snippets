# Project Changelog

All notable user-facing changes to GenSnippets. Each entry maps 1:1 to a released `MARKETING_VERSION` / Sparkle appcast item.

Format: `### <version> (build <n>) — <YYYY-MM-DD>` followed by short bullets. Internal-only chores (CI tweaks, lint passes) are not listed.

---

## v2.10.7 (build 27) — 2026-08-20

### Fixed
- **Cmd+V right after a snippet expansion no longer pastes the snippet.** Expansion temporarily puts the snippet on the system clipboard and posts a synthetic Cmd+V; a real Cmd+V pressed inside that window could read the temporary value. Physical Cmd+V is now held from clipboard capture through restore, then replayed once the user's own clipboard is back.
- **Rapid consecutive expansions no longer leak into each other.** Clipboard ownership is serialized per expansion, so each one snapshots the user's real clipboard instead of the previous snippet's temporary value. `{clipboard}`, `{upper}` and `{lower}` resolve from that snapshot.
- **Non-text clipboards survive expansion.** Restore replays the full set of pasteboard items (image, file, URL, rich text), not just the plain string, and still yields to a newer external Copy via the `changeCount` guard.

### Changed
- Added a hosted `GenSnippetsTests` XCTest target with regression coverage for clipboard lease state and the synthetic-event marker.

### Compatibility
- Paste settle (25/45 ms) and clipboard restore (500/600 ms) timings are deliberately unchanged — they are what keeps long-running and idle iTerm2 sessions from expanding stale content.

### Affected files
- New `GenSnippets/Services/ClipboardPasteCoordinator.swift`; `Services/TextReplacementService.swift`, `Services/RichContentService.swift`, new `GenSnippetsTests/ClipboardLeaseStateTests.swift`

---

## v2.10.0 (build 20) — 2026-06-17

### Added
- **Inline rich-text snippets.** A snippet can now combine text and images in a single rich-text document edited in one box (NSTextView/RTFD), replacing the old single-content-type picker. Trigger once to paste the whole formatted block.
- **Add Image / Add File toolbar** attached to the snippet editor; paste or drop images inline at the cursor.
- **App-aware paste.** Rich-text apps (Notes, TextEdit, Mail, Word) receive text + inline images in one paste; chat/web apps (Slack, Discord, browsers) receive the text and images pasted sequentially (each image alone, since they drop inline images when text is present); terminals receive plain text only.
- Dynamic placeholders (`{time}`, `{uuid}`, `{clipboard}`, `{dd/mm/yyyy}`, `{random}`) resolve inside rich snippets while preserving images and formatting.

### Changed
- Removed the manual "Add Link" control — type URLs directly in the editor (rich apps auto-linkify).

### Compatibility
- Pure plain-text snippets are unchanged and still save as plain text, preserving the `{cursor}` and `{{field}}` interactive prompts. Legacy plain-text / image / URL / file snippets load into the new editor without data loss; export/import round-trips the rich content.

### Affected files
- `Models/Snippet.swift`, `Services/RichContentService.swift`, `Services/TextReplacementService.swift`, `Models/ShareExportData.swift`, `Services/ShareService.swift`, `Views/AddSnippetSheet.swift`, `Views/SnippetDetailView.swift`, and new `Components/InlineRichTextEditor.swift` + `Components/SnippetFileAttachments.swift`

---

## v2.9.17 (build 19) — 2026-05-28

### Fixed
- Snippet expansion in **cmux** terminal (`com.cmuxterm.app`) no longer leaves the typed command on screen with stray garbage characters before the replacement. cmux was previously unregistered, so it fell through to the default 0.5ms deletion cadence — its Rust input pipeline couldn't keep up with fast-coalesced synthesized Backspace events in long-lived sessions and rendered them as printable characters. Now classified the same as iTerm2 / Terminal.app / Warp: 1ms per-event cadence, individual key pacing, and the 50ms pasteboard write-settle spin-wait.

### Affected files
- `GenSnippets/Services/EdgeCaseHandler.swift` — added `com.cmuxterm.app` to `isTerminal()`

---

## v2.9.16 (build 18) — 2026-04-25

### Performance
- Snippet expansion feels snappier: cursor positioning latency reduced ~75% on native macOS apps (Notes, Mail, Xcode, IDEs).
- Adaptive timing per app category — Discord, VMs, and Remote Desktop keep conservative delays for reliability.
- Cached app-category detection per expansion — eliminates 5–6 redundant system probes per snippet, lowering CPU usage during fast typing.

---

## v2.9.15 (build 17) — 2026-04-25

### Fixed
- Dropped keystrokes during fast consecutive snippet expansions (e.g. typing `;ggp;ggp` quickly). The internal expansion flag was held through the 300ms clipboard-restore window and swallowed user keystrokes between expansions; now released ~30ms after paste posts.
- Tightened duplicate-character dedup window from 100ms → 30ms to allow rapid typing of repeated characters.

---

## v2.9.14 (build 16) — 2026-04-24

### Fixed
- Blank title bar after long background time or login-item relaunch.

---

## v2.9.13 (build 15) — 2026-04-24

### Fixed
- Stale clipboard paste in long-lived terminal sessions (notably aged iTerm2 with heavy scrollback / selection auto-copy). Added a bounded spin-wait on pasteboard write propagation + content verify before posting Cmd+V, plus raised terminal paste delay to 5ms.

---

## v2.9.12 (build 14) — 2026-03-23

### Fixed
- Usage analytics data loss on app restart and version updates.

---

## v2.9.11 (build 13) — 2026-03-22

### Fixed
- Snippets list now refreshes on category delete.
- Toasts auto-dismiss.

---

*Older versions: see `git log` and the Sparkle `appcast.xml` for the full history.*
