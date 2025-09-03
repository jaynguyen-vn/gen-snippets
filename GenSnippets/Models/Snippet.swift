import Foundation

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
    }
    
    init(_id: String, command: String, content: String, description: String?, categoryId: String?, userId: String?, isDeleted: Bool?, createdAt: String?, updatedAt: String?) {
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
    }
} 