# Code Review: Base64 Image Storage to File-Based Storage Refactor

**Date:** 2026-02-17
**Reviewer:** code-reviewer
**Build:** PASSED (Debug)

---

## Scope

- **Files reviewed:** 8 core files + 2 supporting files (ThreeColumnView, SandboxMigrationService)
- **LOC changed:** ~392 added, ~137 removed
- **Focus:** Data migration safety, export/import round-trip, thread safety, orphaned file cleanup, API consistency

---

## Overall Assessment

Well-structured refactor. Migration logic is sound, export/import round-trips are correctly handled for both `LocalStorageService` and `ShareService` paths, and the `loadImageSmart` fallback pattern provides good backward compatibility. However, there are two high-priority issues (orphaned file cleanup never called, `moveSnippet` drops rich content) and several medium-priority items.

---

## Critical Issues

None found. No data loss on migration path; fallback to Base64 decoding ensures existing images survive the update.

---

## High Priority

### H1. Orphaned file cleanup never invoked (SEVERITY: HIGH)

`deleteRichContent(for:)` and `cleanupOrphanedContent(validSnippetIds:)` exist in `RichContentService` but are **never called** from anywhere in the codebase. When a user deletes a snippet, the image files remain in `~/Library/Application Support/GenSnippets/RichContent/` forever.

**Impact:** Disk space leak. Power users with many image snippets will accumulate orphaned PNG files indefinitely.

**Affected files:**
- `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Models/LocalSnippetsViewModel.swift` (lines 114-119, `deleteSnippet`)
- `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Services/LocalStorageService.swift` (lines 126-135, `deleteCategory` deletes snippets without cleaning files)
- `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Models/LocalSnippetsViewModel.swift` (lines 157-167, `clearAllData`)

**Fix:** Call `RichContentService.shared.deleteRichContent(for: snippetId)` in `LocalSnippetsViewModel.deleteSnippet` and `deleteMultipleSnippets`. Call the full-directory cleanup in `clearAllData`. Example:

```swift
// In LocalSnippetsViewModel.deleteSnippet:
func deleteSnippet(_ snippetId: String) {
    RichContentService.shared.deleteRichContent(for: snippetId)
    if localStorageService.deleteSnippet(snippetId) { ... }
}
```

### H2. `moveSnippet` drops richContentItems (SEVERITY: HIGH)

`LocalSnippetsViewModel.moveSnippet` (line 131-146) constructs a new `Snippet` using the backwards-compatible initializer that does NOT include `contentType`, `richContentData`, `richContentMimeType`, or `richContentItems`. Moving an image snippet to another category silently strips all rich content.

**Affected file:** `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Models/LocalSnippetsViewModel.swift` (line 133)

**Fix:**

```swift
let updatedSnippet = Snippet(
    _id: existingSnippet.id,
    command: existingSnippet.command,
    content: existingSnippet.content,
    description: existingSnippet.description,
    categoryId: toCategoryId,
    userId: existingSnippet.userId,
    isDeleted: existingSnippet.isDeleted,
    createdAt: existingSnippet.createdAt,
    updatedAt: Date().description,
    contentType: existingSnippet.contentType,
    richContentData: existingSnippet.richContentData,
    richContentMimeType: existingSnippet.richContentMimeType,
    richContentItems: existingSnippet.richContentItems
)
```

---

## Medium Priority

### M1. `isFilePath` depends on file existence -- fragile for deleted/moved files (SEVERITY: MEDIUM)

`isFilePath` (RichContentService line 84-86) checks `data.hasPrefix("/") && FileManager.default.fileExists(atPath: data)`. If a file is deleted or the disk is unavailable, this returns `false`, causing the system to try Base64-decoding the file path string (which will also fail). This is technically safe (returns original item unchanged), but the export path in `imageItemToBase64` will silently skip converting the item, resulting in a broken file path being exported.

**Affected file:** `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Services/RichContentService.swift` (line 84)

**Recommendation:** For export, consider using `data.hasPrefix("/")` alone (without file existence check) so that missing files are detected and logged rather than silently exported as broken paths. For import/migration, the current behavior is fine.

### M2. `storeImageFromPath` has filename collision risk (SEVERITY: MEDIUM)

`storeImageFromPath` uses `"\(snippetId)_\(sourceURL.lastPathComponent)"` as the filename (line 51). If two files from different directories share the same filename, the second overwrites the first. `storeImage` correctly uses UUID to avoid this.

**Affected file:** `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Services/RichContentService.swift` (line 51)

**Fix:** Add UUID: `"\(snippetId)_\(UUID().uuidString)_\(sourceURL.lastPathComponent)"`

### M3. `AddSnippetSheet.removeItem` does not clean up stored file (SEVERITY: MEDIUM)

When a user removes an image from the `richContentItems` list in `AddSnippetSheet` (line 372-374), the PNG file already written to disk by `createImageItem` is not deleted. If the user then cancels the sheet, orphaned files remain.

**Affected file:** `/Users/jay/Documents/Work/code.nosync/bip/gen-snippets/GenSnippets/GenSnippets/Views/AddSnippetSheet.swift` (line 372)

**Recommendation:** Either delete the file immediately on removal, or track pending files and clean up on sheet dismiss/cancel. Same applies to `SnippetDetailView.removeItem` (line 785-788) and the "Clear All" buttons.

### M4. `exportData` comparison `if convertedItems == items` may not short-circuit correctly (SEVERITY: MEDIUM)

In `LocalStorageService.exportData` (line 232), the comparison `if convertedItems == items { return snippet }` relies on `RichContentItem.Equatable`. Since `imageItemToBase64` creates a new `RichContentItem` with a different `data` value (Base64 vs path), this comparison should work correctly when conversion happens. However, when NO conversion happens (non-image items), both arrays are identical by identity, so the short-circuit works. This is fine but worth noting for future maintainers.

### M5. No validation that `pendingSnippetId` matches the created snippet ID (SEVERITY: MEDIUM)

In `AddSnippetSheet`, `pendingSnippetId` is generated at `@State` init time (line 23) and passed to `createSnippet` (line 638). The `createSnippet` function uses `snippetId ?? localStorageService.generateId()` (line 66). This works correctly because `pendingSnippetId` is always non-nil. However, if the sheet is somehow reused without reinitializing `@State`, the same ID would be reused. SwiftUI re-creates `@State` on new sheet presentations, so this is safe in practice.

---

## Low Priority

### L1. `loadImageSmart` does synchronous file I/O on calling thread (SEVERITY: LOW)

`loadImageSmart` reads file data synchronously. In `SnippetDetailView` and `AddSnippetSheet`, this is called from `body` via `ForEach` loops during view rendering. For many large images, this could cause UI jank.

**Recommendation:** Consider async image loading with caching for the grid views, or use `NSImage(contentsOfFile:)` which is slightly more efficient than `Data(contentsOf:)` + `NSImage(data:)`.

### L2. Migration runs every app launch until first migration (SEVERITY: LOW)

`hasRunMigration` is a non-persisted instance variable (line 44). Since `LocalSnippetsViewModel` is recreated on app launch, migration will attempt to run once per app launch. It's idempotent (already-migrated items pass `isFilePath` check and are skipped), but it iterates all snippets unnecessarily.

**Recommendation:** Store a persistent flag in `UserDefaults` (e.g., `"Base64MigrationCompleted"`). Alternatively, this is acceptable given the migration is fast and one-time per session.

### L3. `cleanupOrphanedContent` uses simple prefix matching (SEVERITY: LOW)

`cleanupOrphanedContent` (line 477-483) extracts `snippetId` by splitting on `_` and taking the first component. If a snippet ID itself contains underscores, this would extract a partial ID and potentially match the wrong snippet.

**Recommendation:** Since snippet IDs are UUIDs (format `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`), splitting on `_` is safe because UUIDs use hyphens. No action needed, but document the assumption.

---

## Edge Cases Found

1. **False positive on `isFilePath`:** Could a Base64 string start with "/"? Yes, the Base64 character "/" is valid. However, `isFilePath` also requires `FileManager.fileExists`, making a collision extremely unlikely in practice. The only scenario: a file at that exact Base64-decoded path exists. Probability: negligible.

2. **Empty `data` strings:** If `RichContentItem.data` is empty, `isFilePath("")` returns `false` (empty string doesn't start with "/"), `loadImageSmart("")` returns nil (no file, not valid Base64). Safe.

3. **Mixed item types (image + file + text):** The migration correctly only converts `.image` type items and preserves others unchanged. Export/import also only converts `.image` items. Safe.

4. **Legacy `richContentData` migration:** Correctly handled in `migrateSnippetImages` Case 2 (lines 399-423). After migration, `richContentData` is set to `nil` and the item is moved to `richContentItems`. The `allRichContentItems` computed property handles both formats.

5. **Concurrent migration risk:** Migration runs on main thread in `loadSnippets()`. The `hasRunMigration` flag prevents re-entry within the same VM instance. Since `LocalSnippetsViewModel` init calls `loadSnippets()` synchronously, there's no race condition.

---

## Positive Observations

1. **Smart fallback pattern** in `loadImageSmart` -- tries file path first, falls back to Base64. Graceful degradation for unmigrated data.
2. **Item ID preservation** during migration (`id: item.id`) -- maintains identity across the format change.
3. **Consistent round-trip** in both export paths (LocalStorageService and ShareService) -- export converts to Base64, import converts back to files.
4. **`pendingSnippetId` approach** in AddSnippetSheet correctly ties file storage to the future snippet ID before creation.
5. **Directory auto-creation** in `RichContentService.init()` prevents first-use failures.
6. **ThreeColumnView alert consolidation** (bonus change in same commit) -- cleaner alert management using `DeleteAlertType` enum.

---

## Recommended Actions (Priority Order)

1. **[H1] Wire up `deleteRichContent`** in `deleteSnippet`, `deleteMultipleSnippets`, `deleteCategory`, and `clearAllData` paths
2. **[H2] Fix `moveSnippet`** to preserve all rich content fields
3. **[M3] Clean up files** when images are removed from AddSnippetSheet/SnippetDetailView before save
4. **[M1] Improve export handling** for missing image files (log warning, exclude broken items)
5. **[M2] Add UUID** to `storeImageFromPath` filename to prevent collisions
6. **[L2] Persist migration flag** to avoid unnecessary iteration on subsequent launches

---

## Metrics

- **Type Coverage:** N/A (Swift, statically typed)
- **Test Coverage:** 0% (no tests exist)
- **Linting Issues:** 0 (build succeeds with no warnings in reviewed files)
- **Build Status:** PASSED

---

## Unresolved Questions

1. Should `clearAllData` also wipe the `RichContent/` directory? Currently it only clears UserDefaults.
2. Is there an intended trigger for `cleanupOrphanedContent`? It exists but has no callers. Consider running it periodically or on app launch after migration.
3. The legacy `insertImage`/`insertURL`/`insertFile` private methods in RichContentService appear to be dead code now that `insertRichContent` uses `insertMultipleItems`. Should they be removed?
