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

    // MARK: - Image Storage

    func storeImage(_ image: NSImage, for snippetId: String) -> (base64: String, mimeType: String)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let base64 = pngData.base64EncodedString()
        return (base64, "image/png")
    }

    func storeImageFromPath(_ path: String, for snippetId: String) -> (base64: String, mimeType: String)? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return nil }

        let mimeType = mimeTypeForPath(path)
        let base64 = data.base64EncodedString()
        return (base64, mimeType)
    }

    func loadImage(from base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
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

        // Insert all items sequentially with a small delay between each
        insertMultipleItems(items, at: 0, previousClipboard: previousClipboard)
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
        insertSingleItem(item) {
            // After inserting this item, wait and insert the next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.insertMultipleItems(items, at: index + 1, previousClipboard: previousClipboard)
            }
        }
    }

    private func insertSingleItem(_ item: RichContentItem, completion: @escaping () -> Void) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .plainText:
            pasteboard.setString(item.data, forType: .string)

        case .image:
            if let image = loadImage(from: item.data) {
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
        }

        simulatePaste()

        // Call completion after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }

    // MARK: - Legacy Single Item Insertion (for backward compatibility)

    private func insertImage(snippet: Snippet, previousClipboard: String?) {
        guard let base64 = snippet.richContentData,
              let image = loadImage(from: base64) else {
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

    func createImageItem(from image: NSImage, fileName: String? = nil) -> RichContentItem? {
        guard let result = storeImage(image, for: UUID().uuidString) else { return nil }
        return RichContentItem(type: .image, data: result.base64, mimeType: result.mimeType, fileName: fileName)
    }

    func createFileItem(from url: URL, for snippetId: String) -> RichContentItem? {
        guard let result = storeFile(url, for: snippetId) else { return nil }
        return RichContentItem(type: .file, data: result.path, mimeType: result.mimeType, fileName: url.lastPathComponent)
    }

    func createURLItem(urlString: String) -> RichContentItem {
        return RichContentItem(type: .url, data: urlString, mimeType: "text/uri-list")
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

    // MARK: - Cleanup

    func deleteRichContent(for snippetId: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: richContentDirectory, includingPropertiesForKeys: nil) else { return }

        for file in contents where file.lastPathComponent.hasPrefix(snippetId) {
            try? fm.removeItem(at: file)
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
