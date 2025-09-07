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
    
    // Thread safety
    private let dataQueue = DispatchQueue(label: "com.gensnippets.usage", attributes: .concurrent)
    
    // Batch save management
    private var saveTimer: Timer?
    private var pendingSave = false
    
    init() {
        loadUsageData()
    }
    
    deinit {
        saveTimer?.invalidate()
        performPendingSave()
    }
    
    private func loadUsageData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: SnippetUsage].self, from: data) {
            DispatchQueue.main.async {
                self.usageData = decoded
            }
        }
    }
    
    private func saveUsageData() {
        pendingSave = true
        scheduleSave()
    }
    
    private func performSave() {
        dataQueue.sync {
            do {
                let encoded = try JSONEncoder().encode(usageData)
                UserDefaults.standard.set(encoded, forKey: storageKey)
                pendingSave = false
            } catch {
                print("[UsageTracker] Failed to save usage data: \(error)")
            }
        }
    }
    
    private func scheduleSave() {
        // Cancel existing timer
        saveTimer?.invalidate()
        
        // Schedule new save after 0.5 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performPendingSave()
        }
    }
    
    private func performPendingSave() {
        if pendingSave {
            performSave()
        }
    }
    
    func recordUsage(for snippetId: String) {
        dataQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var updatedData = self.usageData
            
            if updatedData[snippetId] != nil {
                updatedData[snippetId]?.recordUsage()
            } else {
                var newUsage = SnippetUsage(snippetId: snippetId)
                newUsage.recordUsage()
                updatedData[snippetId] = newUsage
            }
            
            let count = updatedData[snippetId]?.usageCount ?? 0
            
            // Update on main thread for UI
            DispatchQueue.main.async {
                self.usageData = updatedData
                self.objectWillChange.send()
                // Post notification for UI update
                NotificationCenter.default.post(name: NSNotification.Name("SnippetUsageUpdated"), object: snippetId)
            }
            
            self.saveUsageData()
            
            print("[UsageTracker] 📊 Recorded usage for snippet \(snippetId), total: \(count)")
        }
    }
    
    func getUsage(for snippetId: String) -> SnippetUsage? {
        return dataQueue.sync {
            return usageData[snippetId]
        }
    }
    
    func getUsageCount(for snippetId: String) -> Int {
        return dataQueue.sync {
            return usageData[snippetId]?.usageCount ?? 0
        }
    }
    
    func getLastUsed(for snippetId: String) -> String {
        return dataQueue.sync {
            return usageData[snippetId]?.formattedLastUsed ?? "Never"
        }
    }
    
    func getMostUsedSnippets(limit: Int = 10) -> [(snippetId: String, usage: SnippetUsage)] {
        return dataQueue.sync {
            return usageData
                .map { ($0.key, $0.value) }
                .sorted { $0.1.usageCount > $1.1.usageCount }
                .prefix(limit)
                .map { ($0, $1) }
        }
    }
    
    func getRecentlyUsedSnippets(limit: Int = 10) -> [(snippetId: String, usage: SnippetUsage)] {
        return dataQueue.sync {
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
    }
    
    func clearUsageData() {
        dataQueue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.usageData.removeAll()
            }
            self?.saveUsageData()
        }
    }
}