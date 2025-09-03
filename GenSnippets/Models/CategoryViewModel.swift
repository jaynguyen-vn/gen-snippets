import Foundation
import Combine

class CategoryViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var selectedCategory: Category?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let localStorageService = LocalStorageService.shared
    
    init() {
        loadCategories()
    }
    
    private func setupUncategory() {
        let uncategory = Category(
            _id: "uncategory",
            name: "Uncategory",
            description: "Default category for uncategorized snippets",
            userId: nil,
            isDeleted: false,
            createdAt: nil,
            updatedAt: nil
        )
        categories = [uncategory]
        selectedCategory = uncategory
    }
    
    func fetchCategories() {
        loadCategories()
    }
    
    private func loadCategories() {
        isLoading = true
        errorMessage = nil
        
        var allCategories = localStorageService.loadCategories()
        
        // Always add "All" category at the beginning
        let allCategory = Category(
            _id: "all-snippets",
            name: "All",
            description: "View all snippets from all categories",
            userId: nil,
            isDeleted: false,
            createdAt: nil,
            updatedAt: nil
        )
        
        // Always add uncategory after "All"
        let uncategory = Category(
            _id: "uncategory",
            name: "Uncategory",
            description: "Default category for uncategorized snippets",
            userId: nil,
            isDeleted: false,
            createdAt: nil,
            updatedAt: nil
        )
        
        // Remove existing special categories if exists
        allCategories.removeAll { $0.id == "uncategory" || $0.id == "all-snippets" }
        
        // Insert special categories at the beginning
        allCategories.insert(uncategory, at: 0)
        allCategories.insert(allCategory, at: 0)
        
        self.categories = allCategories
        
        if self.selectedCategory == nil {
            self.selectedCategory = allCategory
        }
        
        isLoading = false
        print("[CategoryViewModel] Loaded \(allCategories.count) categories")
    }
    
    func createCategory(name: String, description: String?) {
        let newCategory = Category(
            _id: localStorageService.generateId(),
            name: name,
            description: description,
            userId: nil,
            isDeleted: false,
            createdAt: Date().description,
            updatedAt: Date().description
        )
        
        _ = localStorageService.createCategory(newCategory)
        loadCategories()
        print("[CategoryViewModel] Created category: \(name)")
    }
    
    func updateCategory(_ categoryId: String, name: String, description: String?) {
        if let existingCategory = categories.first(where: { $0.id == categoryId }) {
            let updatedCategory = Category(
                _id: existingCategory.id,
                name: name,
                description: description,
                userId: existingCategory.userId,
                isDeleted: existingCategory.isDeleted,
                createdAt: existingCategory.createdAt,
                updatedAt: Date().description
            )
            
            _ = localStorageService.updateCategory(categoryId, updatedCategory)
            loadCategories()
            print("[CategoryViewModel] Updated category: \(name)")
        }
    }
    
    func deleteCategory(_ categoryId: String) {
        print("[CategoryViewModel] Attempting to delete category with ID: \(categoryId)")
        let categoryName = categories.first(where: { $0.id == categoryId })?.name ?? "unknown"
        print("[CategoryViewModel] Category name to delete: \(categoryName)")
        
        if localStorageService.deleteCategory(categoryId) {
            print("[CategoryViewModel] LocalStorageService.deleteCategory returned true")
            if selectedCategory?.id == categoryId {
                selectedCategory = categories.first
            }
            loadCategories()
            print("[CategoryViewModel] Successfully deleted category: \(categoryName) (ID: \(categoryId))")
            print("[CategoryViewModel] Categories after deletion: \(categories.map { $0.name })")
        } else {
            print("[CategoryViewModel] Failed to delete category: \(categoryName)")
        }
    }
    
    func clearAllData() {
        categories = []
        selectedCategory = nil
        print("[CategoryViewModel] Cleared all categories")
    }
    
    func selectCategory(_ category: Category?) {
        selectedCategory = category
    }
}