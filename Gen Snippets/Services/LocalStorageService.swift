import Foundation
import Combine

class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let categoriesKey = "localCategories"
    private let snippetsKey = "localSnippets"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private init() {}
    
    // MARK: - Categories
    func saveCategories(_ categories: [Category]) {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            print("[LocalStorage] Saved \(categories.count) categories")
        }
    }
    
    func loadCategories() -> [Category] {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            print("[LocalStorage] Loaded \(decoded.count) categories")
            return decoded
        }
        return []
    }
    
    func createCategory(_ category: Category) -> Category {
        var categories = loadCategories()
        categories.append(category)
        saveCategories(categories)
        return category
    }
    
    func updateCategory(_ categoryId: String, _ updatedCategory: Category) -> Category? {
        var categories = loadCategories()
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index] = updatedCategory
            saveCategories(categories)
            return updatedCategory
        }
        return nil
    }
    
    func deleteCategory(_ categoryId: String) -> Bool {
        print("[LocalStorageService] deleteCategory called with ID: \(categoryId)")
        var categories = loadCategories()
        let beforeCount = categories.count
        let categoryName = categories.first(where: { $0.id == categoryId })?.name ?? "unknown"
        print("[LocalStorageService] Found category to delete: \(categoryName), current categories count: \(beforeCount)")
        
        categories.removeAll { $0.id == categoryId }
        let afterCount = categories.count
        print("[LocalStorageService] After removal, categories count: \(afterCount) (removed \(beforeCount - afterCount) categories)")
        
        saveCategories(categories)
        
        // Delete all snippets from this category
        var snippets = loadSnippets()
        let snippetsBeforeCount = snippets.count
        snippets.removeAll { $0.categoryId == categoryId }
        let deletedCount = snippetsBeforeCount - snippets.count
        print("[LocalStorageService] Deleted \(deletedCount) snippets from category")
        saveSnippets(snippets)
        
        return true
    }
    
    // MARK: - Snippets
    func saveSnippets(_ snippets: [Snippet]) {
        if let encoded = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(encoded, forKey: snippetsKey)
            print("[LocalStorage] Saved \(snippets.count) snippets")
        }
    }
    
    func loadSnippets() -> [Snippet] {
        if let data = UserDefaults.standard.data(forKey: snippetsKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            print("[LocalStorage] Loaded \(decoded.count) snippets")
            return decoded
        }
        return []
    }
    
    func createSnippet(_ snippet: Snippet) -> Snippet {
        var snippets = loadSnippets()
        snippets.append(snippet)
        saveSnippets(snippets)
        return snippet
    }
    
    func updateSnippet(_ snippetId: String, _ updatedSnippet: Snippet) -> Snippet? {
        var snippets = loadSnippets()
        if let index = snippets.firstIndex(where: { $0.id == snippetId }) {
            snippets[index] = updatedSnippet
            saveSnippets(snippets)
            return updatedSnippet
        }
        return nil
    }
    
    func deleteSnippet(_ snippetId: String) -> Bool {
        var snippets = loadSnippets()
        snippets.removeAll { $0.id == snippetId }
        saveSnippets(snippets)
        return true
    }
    
    // MARK: - Export/Import
    struct ExportData: Codable {
        let categories: [Category]
        let snippets: [Snippet]
        let exportDate: Date
        let version: String
    }
    
    func exportData() -> URL? {
        let categories = loadCategories()
        let snippets = loadSnippets()
        
        let exportData = ExportData(
            categories: categories,
            snippets: snippets,
            exportDate: Date(),
            version: "1.0"
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportData)
            
            let fileName = "GenSnippets_Export_\(Date().timeIntervalSince1970).json"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            print("[LocalStorage] Exported data to: \(fileURL.path)")
            return fileURL
        } catch {
            print("[LocalStorage] Export failed: \(error)")
            return nil
        }
    }
    
    func importData(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exportData = try decoder.decode(ExportData.self, from: data)
            
            // Save imported data
            saveCategories(exportData.categories)
            saveSnippets(exportData.snippets)
            
            print("[LocalStorage] Imported \(exportData.categories.count) categories and \(exportData.snippets.count) snippets")
            return true
        } catch {
            print("[LocalStorage] Import failed: \(error)")
            return false
        }
    }
    
    // MARK: - Clear All Data
    func clearAllData() {
        // Clear categories
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        
        // Clear snippets
        UserDefaults.standard.removeObject(forKey: snippetsKey)
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        print("[LocalStorage] Cleared all data")
    }
    
    // Helper to generate unique IDs
    func generateId() -> String {
        return UUID().uuidString
    }
}