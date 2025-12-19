import Foundation

// MARK: - Share Export Data

/// Minimal export format for sharing snippets/categories
/// Different from ExportData (backup) - excludes internal IDs and usage stats
struct ShareExportData: Codable {
    let version: String
    let exportDate: Date
    let categoryName: String?  // Original category name (hint only)
    let snippets: [ShareSnippet]

    init(version: String = "1.0", exportDate: Date = Date(), categoryName: String? = nil, snippets: [ShareSnippet]) {
        self.version = version
        self.exportDate = exportDate
        self.categoryName = categoryName
        self.snippets = snippets
    }
}

// MARK: - Share Snippet

/// Shareable snippet format - excludes userId, internal IDs
struct ShareSnippet: Codable {
    let command: String
    let content: String
    let description: String?
    let categoryName: String?  // Category name hint (not ID)

    // Rich content support
    let contentType: RichContentType?
    let richContentItems: [RichContentItem]?

    init(command: String, content: String, description: String? = nil, categoryName: String? = nil, contentType: RichContentType? = nil, richContentItems: [RichContentItem]? = nil) {
        self.command = command
        self.content = content
        self.description = description
        self.categoryName = categoryName
        self.contentType = contentType
        self.richContentItems = richContentItems
    }

    /// Convert from full Snippet model
    init(from snippet: Snippet, categoryName: String?) {
        self.command = snippet.command
        self.content = snippet.content
        self.description = snippet.description
        self.categoryName = categoryName
        self.contentType = snippet.contentType
        self.richContentItems = snippet.richContentItems
    }
}

// MARK: - Conflict Resolution

/// Conflict resolution action chosen by user
enum ConflictResolution {
    case skip
    case overwrite
    case rename(newCommand: String)
}

// MARK: - Import Result

/// Import result for tracking what was imported
struct ShareImportResult {
    var snippetsImported: Int = 0
    var snippetsSkipped: Int = 0
    var snippetsOverwritten: Int = 0
    var snippetsRenamed: Int = 0

    var totalProcessed: Int {
        snippetsImported + snippetsSkipped + snippetsOverwritten + snippetsRenamed
    }

    var hasChanges: Bool {
        snippetsImported > 0 || snippetsOverwritten > 0 || snippetsRenamed > 0
    }
}

// MARK: - Snippet Conflict Info

/// Information about a conflicting snippet during import
struct SnippetConflictInfo: Identifiable {
    let id = UUID()
    let command: String
    let existingSnippet: Snippet
    let incomingSnippet: ShareSnippet
    let suggestedRename: String
}
