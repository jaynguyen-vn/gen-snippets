import Foundation
import Combine

class SnippetsViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let localSnippetsKey = "localSnippets"
    
    init() {
        loadLocalSnippets()
    }
    
    func fetchSnippets(isRefresh: Bool = false) {
        isLoading = !isRefresh
        loadLocalSnippets()
        isLoading = false
    }
    
    func saveLocalSnippets() {
        if let encoded = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(encoded, forKey: localSnippetsKey)
            print("[SnippetsViewModel] Saved \(snippets.count) snippets locally")
        }
    }
    
    func loadLocalSnippets() {
        if let data = UserDefaults.standard.data(forKey: localSnippetsKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
            print("[SnippetsViewModel] Loaded \(snippets.count) snippets from local storage")
        } else {
            // Load default snippets if no local data exists
            useFallbackSnippets()
        }
        
        // Notify TextReplacementService about loaded snippets
        NotificationCenter.default.post(name: NSNotification.Name("SnippetsUpdated"), object: snippets)
        TextReplacementService.shared.updateSnippets(snippets)
    }
    
    private func useFallbackSnippets() {
        // Create some default snippets for first-time users
        let fallbackSnippets = [
            Snippet(_id: UUID().uuidString, 
                   command: ";thanks", 
                   content: "Thank you for your patience. If you need any further assistance, don't hesitate to ask!",
                   description: "Thank you message",
                   categoryId: nil,
                   userId: nil,
                   isDeleted: false,
                   createdAt: nil,
                   updatedAt: nil),
            Snippet(_id: UUID().uuidString, 
                   command: ";hello", 
                   content: "Hello! How can I assist you today?",
                   description: "Greeting message",
                   categoryId: nil,
                   userId: nil,
                   isDeleted: false,
                   createdAt: nil,
                   updatedAt: nil),
            Snippet(_id: UUID().uuidString, 
                   command: ";bye", 
                   content: "Thank you for contacting us. Have a great day!",
                   description: "Goodbye message",
                   categoryId: nil,
                   userId: nil,
                   isDeleted: false,
                   createdAt: nil,
                   updatedAt: nil)
        ]
        
        self.snippets = fallbackSnippets
        saveLocalSnippets()
        
        print("[SnippetsViewModel] Using fallback snippets")
    }
}