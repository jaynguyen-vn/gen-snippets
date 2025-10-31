import Foundation

struct SnippetUsage: Codable {
    let snippetCommand: String
    var usageCount: Int
    var lastUsedDate: Date?
    var firstUsedDate: Date

    // Legacy field for migration
    let snippetId: String?

    init(snippetCommand: String) {
        self.snippetCommand = snippetCommand
        self.usageCount = 0
        self.lastUsedDate = nil
        self.firstUsedDate = Date()
        self.snippetId = nil
    }

    // Legacy init for backward compatibility during migration
    init(snippetId: String) {
        self.snippetCommand = ""
        self.usageCount = 0
        self.lastUsedDate = nil
        self.firstUsedDate = Date()
        self.snippetId = snippetId
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

    @Published private var usageData: [String: SnippetUsage] = [:]  // Key = snippet command
    private let storageKey = "snippetUsageData_v2"  // New key for command-based tracking
    private let legacyStorageKey = "snippetUsageData"  // Old key for migration
    private let migrationKey = "didMigrateToCommandBased_v2"

    // Thread safety
    private let dataQueue = DispatchQueue(label: "com.gensnippets.usage", attributes: .concurrent)

    // Batch save management
    private var saveTimer: Timer?
    private var pendingSave = false

    init() {
        loadUsageData()
        migrateIfNeeded()
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
    
    func recordUsage(for snippetCommand: String) {
        dataQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            var updatedData = self.usageData

            if updatedData[snippetCommand] != nil {
                updatedData[snippetCommand]?.recordUsage()
            } else {
                var newUsage = SnippetUsage(snippetCommand: snippetCommand)
                newUsage.recordUsage()
                updatedData[snippetCommand] = newUsage
            }

            let count = updatedData[snippetCommand]?.usageCount ?? 0

            // Update on main thread for UI
            DispatchQueue.main.async {
                self.usageData = updatedData
                self.objectWillChange.send()
                // Post notification for UI update
                NotificationCenter.default.post(name: NSNotification.Name("SnippetUsageUpdated"), object: snippetCommand)
            }

            self.saveUsageData()

            print("[UsageTracker] 📊 Recorded usage for command '\(snippetCommand)', total: \(count)")
        }
    }
    
    func getUsage(for snippetCommand: String) -> SnippetUsage? {
        return dataQueue.sync {
            return usageData[snippetCommand]
        }
    }

    func getUsageCount(for snippetCommand: String) -> Int {
        return dataQueue.sync {
            return usageData[snippetCommand]?.usageCount ?? 0
        }
    }

    func getLastUsed(for snippetCommand: String) -> String {
        return dataQueue.sync {
            return usageData[snippetCommand]?.formattedLastUsed ?? "Never"
        }
    }

    func getMostUsedSnippets(limit: Int = 10) -> [(snippetCommand: String, usage: SnippetUsage)] {
        return dataQueue.sync {
            return usageData
                .map { ($0.key, $0.value) }
                .sorted { $0.1.usageCount > $1.1.usageCount }
                .prefix(limit)
                .map { ($0, $1) }
        }
    }

    func getRecentlyUsedSnippets(limit: Int = 10) -> [(snippetCommand: String, usage: SnippetUsage)] {
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

    // MARK: - Migration from ID-based to Command-based tracking
    private func migrateIfNeeded() {
        // Check if migration already completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("[UsageTracker] ✅ Already migrated to command-based tracking")
            return
        }

        // Load legacy ID-based usage data
        guard let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
              let legacyUsage = try? JSONDecoder().decode([String: SnippetUsage].self, from: legacyData) else {
            print("[UsageTracker] ℹ️ No legacy usage data to migrate")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        print("[UsageTracker] 🔄 Starting migration from ID-based to command-based tracking...")

        // Load all snippets to map IDs to commands
        let snippets = LocalStorageService.shared.loadSnippets()
        let idToCommandMap = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0.command) })

        var migratedData: [String: SnippetUsage] = [:]
        var migratedCount = 0
        var skippedCount = 0

        for (snippetId, usage) in legacyUsage {
            if let command = idToCommandMap[snippetId] {
                // Migrate usage data to command-based key
                var migratedUsage = SnippetUsage(snippetCommand: command)
                migratedUsage.usageCount = usage.usageCount
                migratedUsage.lastUsedDate = usage.lastUsedDate
                migratedUsage.firstUsedDate = usage.firstUsedDate

                // If command already exists (unlikely), merge the data
                if let existing = migratedData[command] {
                    migratedUsage.usageCount += existing.usageCount
                    if let existingLastUsed = existing.lastUsedDate,
                       let migratedLastUsed = migratedUsage.lastUsedDate {
                        migratedUsage.lastUsedDate = max(existingLastUsed, migratedLastUsed)
                    }
                    migratedUsage.firstUsedDate = min(existing.firstUsedDate, migratedUsage.firstUsedDate)
                }

                migratedData[command] = migratedUsage
                migratedCount += 1
            } else {
                // Snippet was deleted, skip orphaned data
                skippedCount += 1
            }
        }

        // Save migrated data
        dataQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.usageData = migratedData
            }

            do {
                let encoded = try JSONEncoder().encode(migratedData)
                UserDefaults.standard.set(encoded, forKey: self.storageKey)
                UserDefaults.standard.set(true, forKey: self.migrationKey)
                print("[UsageTracker] ✅ Migration complete: \(migratedCount) migrated, \(skippedCount) orphaned data cleaned")
            } catch {
                print("[UsageTracker] ❌ Migration failed: \(error)")
            }
        }
    }
}