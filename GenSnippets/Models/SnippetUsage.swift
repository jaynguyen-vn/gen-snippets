import Foundation

struct SnippetUsage: Codable {
    let snippetId: String
    var usageCount: Int
    var lastUsedDate: Date?
    var firstUsedDate: Date
    
    init(snippetId: String) {
        self.snippetId = snippetId
        self.usageCount = 0
        self.lastUsedDate = nil
        self.firstUsedDate = Date()
    }
    
    mutating func recordUsage() {
        usageCount += 1
        lastUsedDate = Date()
    }
    
    var daysSinceLastUse: Int? {
        guard let lastUsed = lastUsedDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastUsed, to: Date()).day
        return days
    }
    
    var formattedLastUsed: String {
        guard let lastUsed = lastUsedDate else { return "Never" }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(lastUsed) {
            return "Today"
        } else if calendar.isDateInYesterday(lastUsed) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: lastUsed, to: now).day ?? 0
            if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
            } else if days < 365 {
                let months = days / 30
                return "\(months) month\(months > 1 ? "s" : "") ago"
            } else {
                let years = days / 365
                return "\(years) year\(years > 1 ? "s" : "") ago"
            }
        }
    }
}

class UsageTracker: ObservableObject {
    static let shared = UsageTracker()
    
    @Published private var usageData: [String: SnippetUsage] = [:]
    private let storageKey = "snippetUsageData"
    
    init() {
        loadUsageData()
    }
    
    private func loadUsageData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: SnippetUsage].self, from: data) {
            usageData = decoded
        }
    }
    
    private func saveUsageData() {
        if let encoded = try? JSONEncoder().encode(usageData) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func recordUsage(for snippetId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.usageData[snippetId] != nil {
                self.usageData[snippetId]?.recordUsage()
            } else {
                var newUsage = SnippetUsage(snippetId: snippetId)
                newUsage.recordUsage()
                self.usageData[snippetId] = newUsage
            }
            self.saveUsageData()
            self.objectWillChange.send()
            
            // Post notification for UI update
            NotificationCenter.default.post(name: NSNotification.Name("SnippetUsageUpdated"), object: snippetId)
            
            print("[UsageTracker] 📊 Recorded usage for snippet \(snippetId), total: \(self.usageData[snippetId]?.usageCount ?? 0)")
        }
    }
    
    func getUsage(for snippetId: String) -> SnippetUsage? {
        return usageData[snippetId]
    }
    
    func getUsageCount(for snippetId: String) -> Int {
        return usageData[snippetId]?.usageCount ?? 0
    }
    
    func getLastUsed(for snippetId: String) -> String {
        return usageData[snippetId]?.formattedLastUsed ?? "Never"
    }
    
    func getMostUsedSnippets(limit: Int = 10) -> [(snippetId: String, usage: SnippetUsage)] {
        return usageData
            .map { ($0.key, $0.value) }
            .sorted { $0.1.usageCount > $1.1.usageCount }
            .prefix(limit)
            .map { ($0, $1) }
    }
    
    func getRecentlyUsedSnippets(limit: Int = 10) -> [(snippetId: String, usage: SnippetUsage)] {
        return usageData
            .compactMap { key, value in
                guard value.lastUsedDate != nil else { return nil }
                return (key, value)
            }
            .sorted { 
                ($0.1.lastUsedDate ?? Date.distantPast) > ($1.1.lastUsedDate ?? Date.distantPast)
            }
            .prefix(limit)
            .map { ($0, $1) }
    }
    
    func clearUsageData() {
        usageData.removeAll()
        saveUsageData()
    }
}