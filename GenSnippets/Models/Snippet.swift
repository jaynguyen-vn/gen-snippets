import Foundation

// MARK: - Rich Content Type
enum RichContentType: String, Codable, CaseIterable {
    case plainText = "plainText"
    case image = "image"
    case url = "url"
    case file = "file"

    var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .image: return "Image"
        case .url: return "URL"
        case .file: return "File"
        }
    }

    var systemImage: String {
        switch self {
        case .plainText: return "text.alignleft"
        case .image: return "photo"
        case .url: return "link"
        case .file: return "doc"
        }
    }
}

// MARK: - Rich Content Item (for multi-file support)
struct RichContentItem: Codable, Equatable, Identifiable {
    var id: String
    let type: RichContentType
    let data: String // Base64 for images, path for files, raw for HTML/URL
    let mimeType: String
    let fileName: String? // Original filename for files/images

    init(id: String = UUID().uuidString, type: RichContentType, data: String, mimeType: String, fileName: String? = nil) {
        self.id = id
        self.type = type
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }
}

struct Snippet: Identifiable, Codable, Equatable {
    var id: String {
        // Try _id first, then fall back to idField
        return _id ?? idField ?? ""
    }
    let _id: String?
    let idField: String?
    let command: String
    let content: String
    let description: String?
    let categoryId: String?
    let userId: String?
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?

    // Rich content support (legacy single-item fields for backward compatibility)
    let contentType: RichContentType?
    let richContentData: String?
    let richContentMimeType: String?

    // Multi-file support
    let richContentItems: [RichContentItem]?

    // Computed property for actual content type (defaults to plainText for backwards compatibility)
    var actualContentType: RichContentType {
        // If we have multiple items, return the type of the first item
        if let items = richContentItems, !items.isEmpty {
            return items[0].type
        }
        return contentType ?? .plainText
    }

    // Get all rich content items (converts legacy single-item to array if needed)
    var allRichContentItems: [RichContentItem] {
        if let items = richContentItems, !items.isEmpty {
            return items
        }
        // Convert legacy single-item format to array
        if let type = contentType, type != .plainText,
           let data = richContentData,
           let mimeType = richContentMimeType {
            return [RichContentItem(type: type, data: data, mimeType: mimeType)]
        }
        return []
    }

    // Check if snippet has rich content
    var hasRichContent: Bool {
        return !allRichContentItems.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case _id
        case idField = "id"
        case command
        case content
        case description
        case categoryId
        case userId
        case isDeleted
        case createdAt
        case updatedAt
        case contentType
        case richContentData
        case richContentMimeType
        case richContentItems
    }

    // Full initializer with multi-file rich content support
    init(_id: String, command: String, content: String, description: String?, categoryId: String?, userId: String?, isDeleted: Bool?, createdAt: String?, updatedAt: String?, contentType: RichContentType? = nil, richContentData: String? = nil, richContentMimeType: String? = nil, richContentItems: [RichContentItem]? = nil) {
        self._id = _id
        self.idField = nil
        self.command = command
        self.content = content
        self.description = description
        self.categoryId = categoryId
        self.userId = userId
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contentType = contentType
        self.richContentData = richContentData
        self.richContentMimeType = richContentMimeType
        self.richContentItems = richContentItems
    }

    // Backwards compatible initializer (defaults to plainText)
    init(_id: String, command: String, content: String, description: String?, categoryId: String?, userId: String?, isDeleted: Bool?, createdAt: String?, updatedAt: String?) {
        self.init(_id: _id, command: command, content: content, description: description, categoryId: categoryId, userId: userId, isDeleted: isDeleted, createdAt: createdAt, updatedAt: updatedAt, contentType: nil, richContentData: nil, richContentMimeType: nil, richContentItems: nil)
    }
} 