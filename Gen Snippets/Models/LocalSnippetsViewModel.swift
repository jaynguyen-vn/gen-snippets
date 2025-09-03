import Foundation
import Combine

class LocalSnippetsViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String? = nil
    @Published var lastUpdated: Date? = Date()
    
    private let localStorageService = LocalStorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSnippets()
    }
    
    func fetchSnippets(isRefresh: Bool = false) {
        loadSnippets()
    }
    
    func loadSnippets() {
        isLoading = true
        error = nil
        
        snippets = localStorageService.loadSnippets()
        lastUpdated = Date()
        
        // Notify TextReplacementService about the updated snippets
        NotificationCenter.default.post(name: NSNotification.Name("SnippetsUpdated"), object: snippets)
        TextReplacementService.shared.updateSnippets(snippets)
        
        isLoading = false
        print("[LocalSnippetsViewModel] Loaded \(snippets.count) snippets")
    }
    
    func createSnippet(command: String, content: String, description: String?, categoryId: String?) {
        let newSnippet = Snippet(
            _id: localStorageService.generateId(),
            command: command,
            content: content,
            description: description,
            categoryId: categoryId,
            userId: nil,
            isDeleted: false,
            createdAt: Date().description,
            updatedAt: Date().description
        )
        
        _ = localStorageService.createSnippet(newSnippet)
        loadSnippets()
        lastUpdated = Date()
        print("[LocalSnippetsViewModel] Created snippet: \(command)")
    }
    
    func updateSnippet(_ snippetId: String, command: String, content: String, description: String?, categoryId: String?) {
        if let existingSnippet = snippets.first(where: { $0.id == snippetId }) {
            let updatedSnippet = Snippet(
                _id: existingSnippet.id,
                command: command,
                content: content,
                description: description,
                categoryId: categoryId,
                userId: existingSnippet.userId,
                isDeleted: existingSnippet.isDeleted,
                createdAt: existingSnippet.createdAt,
                updatedAt: Date().description
            )
            
            _ = localStorageService.updateSnippet(snippetId, updatedSnippet)
            loadSnippets()
            lastUpdated = Date()
            print("[LocalSnippetsViewModel] Updated snippet: \(command)")
        }
    }
    
    func deleteSnippet(_ snippetId: String) {
        if localStorageService.deleteSnippet(snippetId) {
            loadSnippets()
            lastUpdated = Date()
            print("[LocalSnippetsViewModel] Deleted snippet: \(snippetId)")
        }
    }
    
    func deleteMultipleSnippets(_ snippetIds: Set<String>) {
        for snippetId in snippetIds {
            _ = localStorageService.deleteSnippet(snippetId)
        }
        loadSnippets()
        lastUpdated = Date()
        print("[LocalSnippetsViewModel] Deleted \(snippetIds.count) snippets")
    }
    
    func clearAllData() {
        localStorageService.clearAllData()
        snippets = []
        lastUpdated = Date()
        
        // Notify TextReplacementService about the cleared snippets
        NotificationCenter.default.post(name: NSNotification.Name("SnippetsUpdated"), object: snippets)
        TextReplacementService.shared.updateSnippets(snippets)
        
        print("[LocalSnippetsViewModel] Cleared all data")
    }
    
    func startMonitoringRevisions() {
        // Not needed for local storage
    }
    
    func stopMonitoringRevisions() {
        // Not needed for local storage
    }
}