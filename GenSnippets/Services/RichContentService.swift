import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Rich Content Service
final class RichContentService {

    static let shared = RichContentService()

    private init() {
        createRichContentDirectoryIfNeeded()
    }

    // MARK: - Storage Directory

    private var richContentDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("GenSnippets/RichContent", isDirectory: true)
    }

    private func createRichContentDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: richContentDirectory.path) {
            try? fm.createDirectory(at: richContentDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Image Storage (file-based)

    func storeImage(_ image: NSImage, for snippetId: String) -> (path: String, mimeType: String)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let fileName = "\(snippetId)_\(UUID().uuidString).png"
        let destURL = richContentDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: destURL)
            return (destURL.path, "image/png")
        } catch {
            print("[RichContentService] Failed to store image: \(error)")
            return nil
        }
    }

    func storeImageFromPath(_ path: String, for snippetId: String) -> (path: String, mimeType: String)? {
        let sourceURL = URL(fileURLWithPath: path)
        let ext = sourceURL.pathExtension
        let fileName = "\(snippetId)_\(UUID().uuidString).\(ext)"
        let destURL = richContentDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let mimeType = mimeTypeForPath(path)
            return (destURL.path, mimeType)
        } catch {
            print("[RichContentService] Failed to store image from path: \(error)")
            return nil
        }
    }

    func loadImage(from base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }

    /// Smart loader: tries file path first (new format), falls back to Base64 (legacy)
    func loadImageSmart(from data: String) -> NSImage? {
        // Try file path first (new format)
        if FileManager.default.fileExists(atPath: data),
           let imageData = try? Data(contentsOf: URL(fileURLWithPath: data)) {
            return NSImage(data: imageData)
        }
        // Fallback: Base64 (legacy)
        return loadImage(from: data)
    }

    /// Check if data looks like a file path (vs Base64)
    func isFilePath(_ data: String) -> Bool {
        return data.hasPrefix("/") && FileManager.default.fileExists(atPath: data)
    }

    // MARK: - File Storage

    func storeFile(_ sourceURL: URL, for snippetId: String) -> (path: String, mimeType: String)? {
        let fileName = "\(snippetId)_\(sourceURL.lastPathComponent)"
        let destURL = richContentDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let mimeType = mimeTypeForPath(sourceURL.path)
            return (destURL.path, mimeType)
        } catch {
            print("[RichContentService] Failed to store file: \(error)")
            return nil
        }
    }

    func loadFileURL(from path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return url
    }

    // MARK: - Insert Rich Content

    func insertRichContent(for snippet: Snippet, previousClipboard: String?) {
        let items = snippet.allRichContentItems

        if items.isEmpty {
            print("[RichContentService] No rich content items for snippet: \(snippet.command)")
            return
        }

        // A lone inline rich-text document pastes as ONE Cmd+V (seamless text + inline images).
        if items.count == 1, items[0].type == .inlineRichText {
            insertInlineRichText(items[0], previousClipboard: previousClipboard)
            return
        }

        // Otherwise paste each item sequentially with a small delay between each.
        insertMultipleItems(items, at: 0, previousClipboard: previousClipboard)
    }

    /// Paste a single inline rich-text (RTFD) document in one Cmd+V. Rich-text apps receive
    /// text + inline images; plain-text targets get the plain-text fallback (images dropped).
    private func insertInlineRichText(_ item: RichContentItem, previousClipboard: String?) {
        guard let data = loadRTFD(from: item.data),
              let attr = try? NSAttributedString(
                  data: data,
                  options: [.documentType: NSAttributedString.DocumentType.rtfd],
                  documentAttributes: nil) else {
            print("[RichContentService] Failed to load inline RTFD for paste")
            return
        }

        // Resolve dynamic keywords in the text runs while preserving image attachments.
        let resolved = resolveKeywords(in: attr, previousClipboard: previousClipboard)

        // App-aware paste. RTFD-aware apps (Notes/TextEdit/Mail/Word) get the seamless single paste.
        // Chat/web apps (Slack/Discord/browsers/Electron) only accept ONE content kind per paste —
        // they drop an inline image when text is present — so paste text and images SEPARATELY.
        // Terminals/password fields get plain text only (images would garble).
        let category = EdgeCaseHandler.detectAppCategory()
        switch category {
        case .standard, .ide, .unknown:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            writeAttributedString(resolved, to: pasteboard)
            simulatePaste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previous, forType: .string)
                }
            }
        default:
            let allowsImages: Bool
            switch category {
            case .terminal, .sshSession, .passwordField: allowsImages = false
            default: allowsImages = true
            }
            let units = pasteUnits(from: resolved, includeImages: allowsImages)
            pasteSequentialUnits(units, at: 0, previousClipboard: previousClipboard)
        }
    }

    private enum InlinePasteUnit {
        case text(String)
        case image(NSImage)
    }

    /// Decompose an inline document into ordered text / image units for sequential pasting into apps
    /// that can't take an inline image alongside text in a single paste.
    private func pasteUnits(from attr: NSAttributedString, includeImages: Bool) -> [InlinePasteUnit] {
        var units: [InlinePasteUnit] = []
        let ns = attr.string as NSString
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                if includeImages, let image = self.image(from: attachment) {
                    units.append(.image(image))
                }
            } else {
                let text = ns.substring(with: range).replacingOccurrences(of: "\u{FFFC}", with: "")
                if !text.isEmpty { units.append(.text(text)) }
            }
        }
        return units
    }

    private func pasteSequentialUnits(_ units: [InlinePasteUnit], at index: Int, previousClipboard: String?) {
        guard index < units.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previous, forType: .string)
                }
            }
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch units[index] {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            pasteboard.writeObjects([image])
        }
        simulatePaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.pasteSequentialUnits(units, at: index + 1, previousClipboard: previousClipboard)
        }
    }

    private func image(from attachment: NSTextAttachment) -> NSImage? {
        if let data = attachment.fileWrapper?.regularFileContents, let image = NSImage(data: data) {
            return image
        }
        return attachment.image
    }

    /// Resolve dynamic keywords ({time}, {uuid}, {clipboard}, {dd/mm/yyyy}, …) in the text runs of an
    /// inline document, preserving image attachments and per-run formatting.
    ///
    /// Built by SEGMENTS into a fresh string — never mutated in place during enumeration (length-changing
    /// edits would shift later ranges) and never applies one run's attributes to a multi-run span.
    /// Limitations (inline mode): {cursor} is left as literal text — a single rich paste can't position the
    /// caret; {{metafield}} interactive dialogs run only on the pure plain-text expansion path. Both still
    /// work fully on plain-text snippets. A keyword split across two style runs won't resolve (rare).
    ///
    /// Side effect: writes `previousClipboard` to the general pasteboard so {clipboard} resolves
    /// correctly. Callers MUST overwrite/restore the pasteboard afterward (the paste paths here do).
    func resolveKeywords(in attr: NSAttributedString, previousClipboard: String?) -> NSAttributedString {
        // Fast exit when there are no keyword braces at all.
        guard attr.string.contains("{") else { return attr }

        // {clipboard}/{upper}/{lower} read the live pasteboard, which the engine has overwritten —
        // seed it with the user's original clipboard so they resolve to the right value.
        if let original = previousClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(original, forType: .string)
        }

        let result = NSMutableAttributedString()
        let fullRange = NSRange(location: 0, length: attr.length)
        attr.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value != nil {
                // image/file attachment run → copy verbatim, never process
                result.append(attr.attributedSubstring(from: range))
                return
            }
            // plain (non-attachment) span may contain multiple style runs; resolve each run
            // independently so it keeps ITS OWN attributes (no flattening)
            attr.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
                let original = attr.attributedSubstring(from: runRange).string
                let processed = TextReplacementService.shared.processSpecialKeywords(original)
                result.append(NSAttributedString(string: processed, attributes: attrs))
            }
        }
        return result
    }

    private func insertMultipleItems(_ items: [RichContentItem], at index: Int, previousClipboard: String?) {
        guard index < items.count else {
            // All items inserted, restore pasteboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previous, forType: .string)
                }
            }
            return
        }

        let item = items[index]
        insertSingleItem(item, previousClipboard: previousClipboard) {
            // After inserting this item, wait and insert the next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.insertMultipleItems(items, at: index + 1, previousClipboard: previousClipboard)
            }
        }
    }

    private func insertSingleItem(_ item: RichContentItem, previousClipboard: String?, completion: @escaping () -> Void) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .plainText:
            // Resolve dynamic keywords ({time}, {uuid}, {clipboard}, …) for text blocks.
            // {clipboard}/{upper}/{lower} read the live pasteboard, which the engine has
            // overwritten by now — so seed it with the user's original clipboard first.
            // Limitations (mixed snippets only): {cursor} is left as-is — the engine pastes
            // each block separately and cannot position the caret across multiple pastes;
            // {{metafield}} interactive dialogs are not run here (only on the pure plainText path).
            if let original = previousClipboard {
                pasteboard.setString(original, forType: .string)
            }
            let processed = TextReplacementService.shared.processSpecialKeywords(item.data)
            pasteboard.clearContents()
            pasteboard.setString(processed, forType: .string)

        case .image:
            if let image = loadImageSmart(from: item.data) {
                pasteboard.writeObjects([image])
            }

        case .url:
            if let url = URL(string: item.data) {
                pasteboard.setString(item.data, forType: .URL)
                pasteboard.setString(item.data, forType: .string)
                pasteboard.writeObjects([url as NSURL])
            }

        case .file:
            if let fileURL = loadFileURL(from: item.data) {
                pasteboard.writeObjects([fileURL as NSURL])
            }

        case .inlineRichText:
            // Sequential-paste path (inline doc as one item in a mixed list, e.g. inline + file).
            // Resolve dynamic keywords in text runs (attachments preserved) before writing RTFD + RTF
            // + plain-text fallbacks.
            if let data = loadRTFD(from: item.data),
               let attr = try? NSAttributedString(
                   data: data,
                   options: [.documentType: NSAttributedString.DocumentType.rtfd],
                   documentAttributes: nil) {
                let resolved = resolveKeywords(in: attr, previousClipboard: previousClipboard)
                writeAttributedString(resolved, to: pasteboard)
            }
        }

        simulatePaste()

        // Call completion after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }

    /// Write an attributed string to the pasteboard with RTFD + RTF + plain-text fallbacks so
    /// rich-text apps get inline images while plain-text targets still receive the text.
    func writeAttributedString(_ attr: NSAttributedString, to pasteboard: NSPasteboard) {
        let full = NSRange(location: 0, length: attr.length)
        if let rtfd = try? attr.data(from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            pasteboard.setData(rtfd, forType: .rtfd)
        }
        if let rtf = try? attr.data(from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        // Also advertise the (first) image as a standalone image type. Apps that don't parse RTFD
        // attachments (Slack, Discord, web/Electron chat) read this and accept the image as an upload,
        // while RTFD-aware apps (Notes/TextEdit/Mail) still prefer RTFD and keep the inline layout.
        // Note: only the first image is exposed this way (a pasteboard holds one standalone image).
        if let image = firstImage(in: attr),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            if let png = rep.representation(using: .png, properties: [:]) {
                pasteboard.setData(png, forType: .png)
            }
            pasteboard.setData(tiff, forType: .tiff)
        }

        // Plain-text fallback for text-only targets: drop the object-replacement chars that stand
        // in for image attachments so terminals/code editors don't show stray glyphs.
        let plain = attr.string.replacingOccurrences(of: "\u{FFFC}", with: "")
        pasteboard.setString(plain, forType: .string)
    }

    /// First image attachment in an attributed string, if any (from its fileWrapper or `.image`).
    private func firstImage(in attr: NSAttributedString) -> NSImage? {
        var result: NSImage? = nil
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, _, stop in
            guard let attachment = value as? NSTextAttachment, let image = self.image(from: attachment) else { return }
            result = image
            stop.pointee = true
        }
        return result
    }

    // MARK: - Legacy Single Item Insertion (for backward compatibility)

    private func insertImage(snippet: Snippet, previousClipboard: String?) {
        guard let base64 = snippet.richContentData,
              let image = loadImageSmart(from: base64) else {
            print("[RichContentService] Failed to load image for snippet: \(snippet.command)")
            return
        }

        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard()

        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        simulatePaste()

        restorePasteboard(backup, previousClipboard: previousClipboard)
    }

    private func insertURL(snippet: Snippet, previousClipboard: String?) {
        guard let urlString = snippet.richContentData ?? snippet.content.nilIfEmpty,
              let url = URL(string: urlString) else {
            print("[RichContentService] Invalid URL for snippet: \(snippet.command)")
            return
        }

        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard()

        pasteboard.clearContents()

        pasteboard.setString(urlString, forType: .URL)
        pasteboard.setString(urlString, forType: .string)
        pasteboard.writeObjects([url as NSURL])

        simulatePaste()

        restorePasteboard(backup, previousClipboard: previousClipboard)
    }

    private func insertFile(snippet: Snippet, previousClipboard: String?) {
        guard let filePath = snippet.richContentData,
              let fileURL = loadFileURL(from: filePath) else {
            print("[RichContentService] File not found for snippet: \(snippet.command)")
            return
        }

        let pasteboard = NSPasteboard.general
        let backup = backupPasteboard()

        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])

        simulatePaste()

        restorePasteboard(backup, previousClipboard: previousClipboard)
    }

    // MARK: - Create RichContentItem helpers

    func createImageItem(from image: NSImage, snippetId: String, fileName: String? = nil) -> RichContentItem? {
        guard let result = storeImage(image, for: snippetId) else { return nil }
        return RichContentItem(type: .image, data: result.path, mimeType: result.mimeType, fileName: fileName)
    }

    func createFileItem(from url: URL, for snippetId: String) -> RichContentItem? {
        guard let result = storeFile(url, for: snippetId) else { return nil }
        return RichContentItem(type: .file, data: result.path, mimeType: result.mimeType, fileName: url.lastPathComponent)
    }

    func createURLItem(urlString: String) -> RichContentItem {
        return RichContentItem(type: .url, data: urlString, mimeType: "text/uri-list")
    }

    /// Present an open panel and return file items for the chosen files (empty if cancelled).
    func pickFiles(for snippetId: String) -> [RichContentItem] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select file(s)"
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.compactMap { createFileItem(from: $0, for: snippetId) }
    }

    func createTextItem(_ text: String) -> RichContentItem {
        return RichContentItem(type: .plainText, data: text, mimeType: "text/plain")
    }

    // MARK: - Inline Rich Text (RTFD) Storage
    //
    // RTFD is persisted as a single `Data` blob written to a flat `<id>_<uuid>.rtfd` file
    // (NOT a filesystem package). The same `Data` representation is used everywhere —
    // store / load / paste / export(base64) / import — so the round-trip is byte-consistent.

    func storeRTFD(_ data: Data, for snippetId: String) -> (path: String, mimeType: String)? {
        let fileName = "\(snippetId)_\(UUID().uuidString).rtfd"
        let destURL = richContentDirectory.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try data.write(to: destURL)
            return (destURL.path, "text/rtfd")
        } catch {
            print("[RichContentService] Failed to store RTFD: \(error)")
            return nil
        }
    }

    func loadRTFD(from path: String) -> Data? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    func createInlineRichTextItem(rtfdData: Data, snippetId: String) -> RichContentItem? {
        guard let result = storeRTFD(rtfdData, for: snippetId) else { return nil }
        return RichContentItem(type: .inlineRichText, data: result.path, mimeType: result.mimeType)
    }

    // MARK: - Inline editor load / save bridge

    /// Build the inline editor's document for any snippet kind, plus the file/url items that
    /// can't live inside the inline document (kept as separate "extras" under Option A).
    /// - plainText / no items → text-only document, no extras.
    /// - inlineRichText → the stored RTFD document, no extras.
    /// - legacy single / block → text+image runs become one inline document; url/file become extras.
    func inlineComponents(for snippet: Snippet) -> (attributed: NSAttributedString, extras: [RichContentItem]) {
        let items = snippet.allRichContentItems

        if items.count == 1, items[0].type == .inlineRichText {
            if let data = loadRTFD(from: items[0].data),
               let attr = try? NSAttributedString(
                   data: data,
                   options: [.documentType: NSAttributedString.DocumentType.rtfd],
                   documentAttributes: nil) {
                return (attr, [])
            }
            return (NSAttributedString(string: snippet.content), [])
        }

        if items.isEmpty {
            return (NSAttributedString(string: snippet.content), [])
        }

        let doc = NSMutableAttributedString()
        var extras: [RichContentItem] = []
        for item in items {
            switch item.type {
            case .plainText:
                doc.append(NSAttributedString(string: item.data))
            case .image:
                if let image = loadImageSmart(from: item.data) {
                    doc.append(attachmentString(for: image))
                }
            case .url:
                // URLs are typed/kept inline as text (rich apps auto-linkify); no separate item.
                doc.append(NSAttributedString(string: item.data))
            case .file:
                extras.append(item)
            case .inlineRichText:
                if let data = loadRTFD(from: item.data),
                   let a = try? NSAttributedString(
                       data: data,
                       options: [.documentType: NSAttributedString.DocumentType.rtfd],
                       documentAttributes: nil) {
                    doc.append(a)
                }
            }
        }
        return (doc, extras)
    }

    /// Centralized back-compat save rule (used by both create + edit flows — DRY).
    /// Pure text downgrades to `plainText` (preserves the dynamic-keyword + metafield fast path);
    /// a document with inline images becomes a single `.inlineRichText` item; file/url extras are
    /// appended as separate items (paste sequentially after the inline document).
    func makeStoredItems(attributed: NSAttributedString, extraItems: [RichContentItem], snippetId: String) -> (content: String, contentType: RichContentType?, items: [RichContentItem]?) {
        let text = attributed.string
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachment = containsAttachment(attributed)
        let hasInline = !trimmed.isEmpty || hasAttachment

        if !hasInline {
            // No inline document — only extras (or nothing).
            guard !extraItems.isEmpty else { return ("", nil, nil) }
            if extraItems.count == 1 {
                let it = extraItems[0]
                return (singleItemContent(it), it.type, [it])
            }
            return (summarize(extraItems), extraItems[0].type, extraItems)
        }

        // Pure text (no images, no extras) → plainText fast path.
        if !hasAttachment, extraItems.isEmpty {
            return (trimmed, nil, nil)
        }

        // Inline document (with images and/or extras).
        guard let rtfd = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]),
              let inlineItem = createInlineRichTextItem(rtfdData: rtfd, snippetId: snippetId) else {
            return (text, nil, nil) // fallback to plain text if RTFD serialization fails
        }

        if extraItems.isEmpty {
            return (text, .inlineRichText, [inlineItem])
        }
        let items = [inlineItem] + extraItems
        return (summarize(items), .inlineRichText, items)
    }

    /// True if the attributed string contains any attachment (inline image/file).
    func containsAttachment(_ attr: NSAttributedString) -> Bool {
        var found = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    /// Build an inline image attachment that BOTH displays in NSTextView AND serializes into RTFD.
    /// A bare `attachment.image = …` renders on screen but is dropped by RTFD serialization (RTFD
    /// embeds attachments via their fileWrapper), so back the attachment with a PNG fileWrapper.
    func attachmentString(for image: NSImage) -> NSAttributedString {
        let attachment = NSTextAttachment()
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let wrapper = FileWrapper(regularFileWithContents: png)
            wrapper.preferredFilename = "\(UUID().uuidString).png"
            attachment.fileWrapper = wrapper
        } else {
            attachment.image = image
        }
        return NSAttributedString(attachment: attachment)
    }

    private func singleItemContent(_ item: RichContentItem) -> String {
        switch item.type {
        case .url: return item.data
        case .file: return "[File: \(item.fileName ?? "file")]"
        case .image: return "[Image]"
        case .plainText: return item.data
        case .inlineRichText: return "[Rich Text]"
        }
    }

    /// Human-readable summary of a mixed block list, used as `Snippet.content`
    /// when the snippet is stored as rich content (e.g. "[2 text · 1 image · 1 file]").
    func summarize(_ items: [RichContentItem]) -> String {
        guard !items.isEmpty else { return "" }

        // Count per type, preserving a stable order for display
        let order: [RichContentType] = [.inlineRichText, .plainText, .image, .url, .file]
        let labels: [RichContentType: String] = [
            .inlineRichText: "rich text", .plainText: "text", .image: "image", .url: "link", .file: "file"
        ]

        var counts: [RichContentType: Int] = [:]
        for item in items {
            counts[item.type, default: 0] += 1
        }

        let parts = order.compactMap { type -> String? in
            guard let count = counts[type], count > 0 else { return nil }
            return "\(count) \(labels[type] ?? type.rawValue)"
        }

        return "[\(parts.joined(separator: " · "))]"
    }

    // MARK: - Pasteboard Helpers

    private struct PasteboardBackup {
        var items: [[NSPasteboard.PasteboardType: Data]] = []
    }

    private func backupPasteboard() -> PasteboardBackup {
        var backup = PasteboardBackup()
        let pasteboard = NSPasteboard.general

        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            backup.items.append(itemData)
        }

        return backup
    }

    private func restorePasteboard(_ backup: PasteboardBackup, previousClipboard: String?, delay: Double = 0.2) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            if !backup.items.isEmpty {
                for itemData in backup.items {
                    let item = NSPasteboardItem()
                    for (type, data) in itemData {
                        item.setData(data, forType: type)
                    }
                    pasteboard.writeObjects([item])
                }
            } else if let previous = previousClipboard {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    // MARK: - Simulate Paste (Cmd+V)

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // Key codes: Command = 0x37, V = 0x09
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return
        }

        cmdDown.flags = [.maskCommand, .maskNonCoalesced]
        vDown.flags = [.maskCommand, .maskNonCoalesced]
        vUp.flags = [.maskCommand, .maskNonCoalesced]
        cmdUp.flags = .maskNonCoalesced

        // Post events with timing
        cmdDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.002)

        vDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.002)

        vUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.002)

        cmdUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.005)
    }

    // MARK: - MIME Type Detection

    private func mimeTypeForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "html", "htm": return "text/html"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "zip": return "application/zip"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Migration (Base64 → File)

    /// Migrate a snippet's image data from Base64 to file-based storage.
    /// Handles both `richContentItems` (multi-item) and legacy `richContentData` (single-item).
    /// Returns updated snippet if migration was needed, nil otherwise.
    func migrateSnippetImages(_ snippet: Snippet) -> Snippet? {
        // Case 1: Multi-item format (richContentItems)
        if let items = snippet.richContentItems, !items.isEmpty {
            var migrated = false
            var updatedItems: [RichContentItem] = []

            for item in items {
                if item.type == .image && !isFilePath(item.data),
                   let imageData = Data(base64Encoded: item.data) {
                    let fileName = "\(snippet.id)_\(UUID().uuidString).png"
                    let destURL = richContentDirectory.appendingPathComponent(fileName)
                    do {
                        try imageData.write(to: destURL)
                        updatedItems.append(RichContentItem(
                            id: item.id, type: .image, data: destURL.path,
                            mimeType: item.mimeType, fileName: item.fileName
                        ))
                        migrated = true
                        continue
                    } catch {
                        print("[RichContentService] Migration failed for item: \(error)")
                    }
                }
                updatedItems.append(item)
            }

            guard migrated else { return nil }

            return Snippet(
                _id: snippet.id, command: snippet.command, content: snippet.content,
                description: snippet.description, categoryId: snippet.categoryId,
                userId: snippet.userId, isDeleted: snippet.isDeleted,
                createdAt: snippet.createdAt, updatedAt: snippet.updatedAt,
                contentType: snippet.contentType, richContentData: snippet.richContentData,
                richContentMimeType: snippet.richContentMimeType, richContentItems: updatedItems
            )
        }

        // Case 2: Legacy single-item format (richContentData)
        if snippet.contentType == .image,
           let base64 = snippet.richContentData, !isFilePath(base64),
           let imageData = Data(base64Encoded: base64) {
            let fileName = "\(snippet.id)_\(UUID().uuidString).png"
            let destURL = richContentDirectory.appendingPathComponent(fileName)
            do {
                try imageData.write(to: destURL)
                // Convert legacy to multi-item format with file path
                let newItem = RichContentItem(
                    type: .image, data: destURL.path,
                    mimeType: snippet.richContentMimeType ?? "image/png"
                )
                return Snippet(
                    _id: snippet.id, command: snippet.command, content: snippet.content,
                    description: snippet.description, categoryId: snippet.categoryId,
                    userId: snippet.userId, isDeleted: snippet.isDeleted,
                    createdAt: snippet.createdAt, updatedAt: snippet.updatedAt,
                    contentType: snippet.contentType, richContentData: nil,
                    richContentMimeType: nil, richContentItems: [newItem]
                )
            } catch {
                print("[RichContentService] Legacy migration failed: \(error)")
            }
        }

        return nil
    }

    // MARK: - Export/Import Helpers

    /// Convert image item from file path to Base64 for portable export.
    func imageItemToBase64(_ item: RichContentItem) -> RichContentItem {
        guard item.type == .image, isFilePath(item.data),
              let imageData = try? Data(contentsOf: URL(fileURLWithPath: item.data)) else {
            return item
        }
        return RichContentItem(
            id: item.id, type: .image, data: imageData.base64EncodedString(),
            mimeType: item.mimeType, fileName: item.fileName
        )
    }

    /// Convert image item from Base64 to file-based storage after import.
    func imageItemFromBase64(_ item: RichContentItem, snippetId: String) -> RichContentItem {
        guard item.type == .image, !isFilePath(item.data),
              let imageData = Data(base64Encoded: item.data) else {
            return item
        }
        let fileName = "\(snippetId)_\(UUID().uuidString).png"
        let destURL = richContentDirectory.appendingPathComponent(fileName)
        do {
            try imageData.write(to: destURL)
            return RichContentItem(
                id: item.id, type: .image, data: destURL.path,
                mimeType: item.mimeType, fileName: item.fileName
            )
        } catch {
            print("[RichContentService] Failed to save imported image: \(error)")
            return item
        }
    }

    /// Convert inline RTFD item from file path to Base64 for portable export
    /// (same single RTFD `Data` blob used by store/load/paste — one representation end-to-end).
    func rtfdItemToBase64(_ item: RichContentItem) -> RichContentItem {
        guard item.type == .inlineRichText, isFilePath(item.data),
              let data = try? Data(contentsOf: URL(fileURLWithPath: item.data)) else {
            return item
        }
        return RichContentItem(
            id: item.id, type: .inlineRichText, data: data.base64EncodedString(),
            mimeType: item.mimeType, fileName: item.fileName
        )
    }

    /// Convert inline RTFD item from Base64 back to file-based storage after import.
    func rtfdItemFromBase64(_ item: RichContentItem, snippetId: String) -> RichContentItem {
        guard item.type == .inlineRichText, !isFilePath(item.data),
              let data = Data(base64Encoded: item.data),
              let result = storeRTFD(data, for: snippetId) else {
            return item
        }
        return RichContentItem(
            id: item.id, type: .inlineRichText, data: result.path,
            mimeType: item.mimeType, fileName: item.fileName
        )
    }

    // MARK: - Cleanup

    func deleteRichContent(for snippetId: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: richContentDirectory, includingPropertiesForKeys: nil) else { return }

        for file in contents where file.lastPathComponent.hasPrefix(snippetId) {
            try? fm.removeItem(at: file)
        }
    }

    /// Remove on-disk rich files belonging to a snippet that the new save no longer references
    /// (e.g. a superseded inline `.rtfd` blob, or images embedded into a new RTFD, or a removed
    /// file attachment). Keeps everything still referenced so live attachments survive.
    func deleteUnreferencedFiles(for snippetId: String, keeping referencedPaths: Set<String>) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: richContentDirectory, includingPropertiesForKeys: nil) else { return }
        for file in contents {
            // Exact-match the owning snippet id (filename is "<snippetId>_<…>") so one snippet's id
            // being a prefix of another's can't delete the other's files.
            let owner = file.lastPathComponent.components(separatedBy: "_").first ?? ""
            if owner == snippetId, !referencedPaths.contains(file.path) {
                try? fm.removeItem(at: file)
            }
        }
    }

    func cleanupOrphanedContent(validSnippetIds: Set<String>) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: richContentDirectory, includingPropertiesForKeys: nil) else { return }

        for file in contents {
            let fileName = file.lastPathComponent
            let snippetId = fileName.components(separatedBy: "_").first ?? ""
            if !validSnippetIds.contains(snippetId) {
                try? fm.removeItem(at: file)
            }
        }
    }
}

// MARK: - String Extension

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
