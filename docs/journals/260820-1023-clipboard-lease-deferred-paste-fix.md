---
date: 2026-08-20
tags: [clipboard, paste, event-tap, reliability, iterm2]
---

# Clipboard lease and deferred Cmd+V fix

## Context

GenSnippets expands text by temporarily placing snippet content on the system pasteboard, posting a synthetic Cmd+V, then restoring the user's clipboard. A physical Cmd+V during that ownership window could therefore paste the snippet again. Reducing the restore delay was rejected because the existing 0.5/0.6-second timing prevents intermittent stale expansions, especially after iTerm2 has been idle or running for a long time.

## What happened

Added a clipboard coordinator with serialized leases. Each expansion waits for the previous lease to finish, then captures the latest user clipboard. GenSnippets marks its synthetic paste events; the event tap lets those through but defers physical Cmd+V presses until the lease restores the clipboard, then replays them.

The coordinator preserves the full pasteboard, not only plain text. Restoration is guarded by `changeCount`, so a newer external copy wins instead of being overwritten. Plain and rich-content paths now share this ownership lifecycle. The 0.5/0.6 restore timing remains intentionally unchanged.

Added a hosted XCTest target and eight focused tests for lease serialization, idle and deferred paste behavior (including the snapshot-capture phase), repeated paste counting, external clipboard changes, cancellation, and synthetic-event marking. Automated Debug tests and the Release build pass.

## Reflection

The failure was an ownership problem, not primarily a timing problem. Clipboard overwrite was needed for reliable expansion, but physical user paste had no way to distinguish the temporary value from the restored value. Explicit ownership and event provenance fix that conflict while retaining the iTerm2 reliability improvement.

## Decisions

- Keep existing app-specific settle and 0.5/0.6 restore delays.
- Serialize expansion leases so snapshots never inherit another snippet's temporary pasteboard.
- Defer and replay only physical Cmd+V; synthetic GenSnippets paste stays immediate.
- Never restore over a pasteboard generation changed by another app.

## Next

- Run manual acceptance with a signed build in iTerm2 after a long-running/idle session: expand a snippet, immediately press Cmd+V, and confirm the previously copied value appears.
- Repeat the same check for plain text, `{clipboard}`, and rich-content snippets. Live UI behavior has not yet been claimed as verified.
