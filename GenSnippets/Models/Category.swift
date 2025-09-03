import Foundation

struct Category: Identifiable, Codable, Hashable {
    var id: String { 
        // Try _id first, then fall back to idField
        return _id ?? idField ?? ""
    }
    let _id: String?
    let idField: String?
    let name: String
    let description: String?
    let userId: String?
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case _id
        case idField = "id"
        case name
        case description
        case userId
        case isDeleted
        case createdAt
        case updatedAt
    }
    
    init(_id: String, name: String, description: String?, userId: String?, isDeleted: Bool?, createdAt: String?, updatedAt: String?) {
        self._id = _id
        self.idField = nil
        self.name = name
        self.description = description
        self.userId = userId
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs._id == rhs._id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
}

struct CategoriesResponse: Codable {
    let data: [Category]
    let error: String?
    let metadata: String?
}

struct CategoryRequest: Codable {
    let name: String
    let description: String?
}

struct CategoryCreateResponse: Codable {
    let data: Category
}

struct CategoryUpdateResponse: Codable {
    let data: Category
}

struct CategoryDeleteResponse: Codable {
    let data: Category
}