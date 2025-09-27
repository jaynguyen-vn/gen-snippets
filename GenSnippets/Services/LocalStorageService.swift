import Foundation
import Combine

class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let categoriesKey = "localCategories"
    private let snippetsKey = "localSnippets"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // Batch save timer
    private var saveTimer: Timer?
    private let saveQueue = DispatchQueue(label: "com.gensnippets.storage", attributes: .concurrent)
    
    // Cached data with size limits
    private var cachedCategories: [Category]?
    private var cachedSnippets: [Snippet]?
    private var pendingCategorySave = false
    private var pendingSnippetSave = false
    private let maxCacheSize = 1000 // Limit cache size to prevent unbounded growth
    
    private init() {
        // Load initial data into cache
        _ = loadCategories()
        _ = loadSnippets()
    }
    
    deinit {
        // Perform any pending saves
        performPendingSaves()

        // Invalidate timer on main thread
        if Thread.isMainThread {
            saveTimer?.invalidate()
            saveTimer = nil
        } else {
            DispatchQueue.main.sync {
                saveTimer?.invalidate()
                saveTimer = nil
            }
        }
    }
    
    // MARK: - Categories
    func saveCategories(_ categories: [Category]) {
        saveQueue.async(flags: .barrier) {
            self.cachedCategories = categories
            self.pendingCategorySave = true
            self.scheduleSave()
        }
    }
    
    private func performCategorySave(_ categories: [Category]) {
        do {
            let encoded = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            print("[LocalStorage] Saved \(categories.count) categories")
        } catch {
            print("[LocalStorage] Failed to save categories: \(error)")
        }
    }
    
    func loadCategories() -> [Category] {
        return saveQueue.sync {
            if let cached = cachedCategories {
                return cached
            }
            
            if let data = UserDefaults.standard.data(forKey: categoriesKey) {
                do {
                    let decoded = try JSONDecoder().decode([Category].self, from: data)
                    // Validate decoded data
                    let validCategories = decoded.filter { !$0.id.isEmpty && !$0.name.isEmpty }
                    cachedCategories = validCategories
                    print("[LocalStorage] Loaded \(validCategories.count) categories")
                    return validCategories
                } catch {
                    print("[LocalStorage] Failed to decode categories: \(error)")
                }
            }
            cachedCategories = []
            return []
        }
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
        saveQueue.async(flags: .barrier) {
            self.cachedSnippets = snippets
            self.pendingSnippetSave = true
            self.scheduleSave()
        }
    }
    
    private func performSnippetSave(_ snippets: [Snippet]) {
        do {
            let encoded = try JSONEncoder().encode(snippets)
            UserDefaults.standard.set(encoded, forKey: snippetsKey)
            print("[LocalStorage] Saved \(snippets.count) snippets")
        } catch {
            print("[LocalStorage] Failed to save snippets: \(error)")
        }
    }
    
    func loadSnippets() -> [Snippet] {
        return saveQueue.sync {
            if let cached = cachedSnippets {
                return cached
            }
            
            if let data = UserDefaults.standard.data(forKey: snippetsKey) {
                do {
                    let decoded = try JSONDecoder().decode([Snippet].self, from: data)
                    // Validate decoded data
                    var validSnippets = decoded.filter { !$0.id.isEmpty && !$0.command.isEmpty }
                    // Limit cache size to prevent memory issues
                    if validSnippets.count > maxCacheSize {
                        print("[LocalStorage] ⚠️ Truncating snippets from \(validSnippets.count) to \(maxCacheSize)")
                        validSnippets = Array(validSnippets.prefix(maxCacheSize))
                    }
                    cachedSnippets = validSnippets
                    print("[LocalStorage] Loaded \(validSnippets.count) snippets")
                    return validSnippets
                } catch {
                    print("[LocalStorage] Failed to decode snippets: \(error)")
                }
            }
            cachedSnippets = []
            return []
        }
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
        saveQueue.async(flags: .barrier) {
            // Clear cached data
            self.cachedCategories = []
            self.cachedSnippets = []
            
            // Clear from UserDefaults
            UserDefaults.standard.removeObject(forKey: self.categoriesKey)
            UserDefaults.standard.removeObject(forKey: self.snippetsKey)
            
            print("[LocalStorage] Cleared all data")
        }
    }
    
    // MARK: - Batch Save Management
    private func scheduleSave() {
        // Ensure timer operations happen on main thread
        let setupTimer = { [weak self] in
            // IMPORTANT: Always invalidate existing timer before creating new one
            self?.saveTimer?.invalidate()
            self?.saveTimer = nil

            // Schedule new save after 0.5 seconds
            self?.saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.performPendingSaves()
                self?.saveTimer = nil // Clear reference after execution
            }
        }

        if Thread.isMainThread {
            setupTimer()
        } else {
            DispatchQueue.main.async {
                setupTimer()
            }
        }
    }
    
    private func performPendingSaves() {
        saveQueue.async(flags: .barrier) {
            if self.pendingCategorySave, let categories = self.cachedCategories {
                self.performCategorySave(categories)
                self.pendingCategorySave = false
            }
            
            if self.pendingSnippetSave, let snippets = self.cachedSnippets {
                self.performSnippetSave(snippets)
                self.pendingSnippetSave = false
            }
        }
    }
    
    // Force save immediately without waiting for timer
    func forceSave() {
        // Invalidate timer on main thread
        if Thread.isMainThread {
            saveTimer?.invalidate()
            saveTimer = nil
        } else {
            DispatchQueue.main.sync {
                saveTimer?.invalidate()
                saveTimer = nil
            }
        }

        saveQueue.sync(flags: .barrier) {
            if self.pendingCategorySave, let categories = self.cachedCategories {
                self.performCategorySave(categories)
                self.pendingCategorySave = false
            }

            if self.pendingSnippetSave, let snippets = self.cachedSnippets {
                self.performSnippetSave(snippets)
                self.pendingSnippetSave = false
            }
        }
    }
    
    // Helper to generate unique IDs
    func generateId() -> String {
        return UUID().uuidString
    }
}