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

    // @Published for SwiftUI reactivity (read on main thread only)
    @Published private var usageData: [String: SnippetUsage] = [:]

    // Thread-safe internal storage — all access through dataQueue
    private var _storage: [String: SnippetUsage] = [:]
    private let dataQueue = DispatchQueue(label: "com.gensnippets.usage", attributes: .concurrent)

    private let storageKey = "snippetUsageData_v2"
    private let legacyStorageKey = "snippetUsageData"
    private let migrationKey = "didMigrateToCommandBased_v2"

    init() {
        loadUsageData()
        migrateIfNeeded()
    }

    // MARK: - Persistence

    /// Load usage data synchronously from UserDefaults
    private func loadUsageData() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: SnippetUsage].self, from: data)
            _storage = decoded
            usageData = decoded
        } catch {
            print("[UsageTracker] ⚠️ Failed to decode usage data, preserving raw data in UserDefaults: \(error)")
        }
    }

    /// Write _storage to UserDefaults. Must be called within dataQueue barrier.
    private func persistToDisk() {
        do {
            let encoded = try JSONEncoder().encode(_storage)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("[UsageTracker] ❌ Failed to save usage data: \(error)")
        }
    }

    /// Force save to disk. Call before app termination.
    func forceSave() {
        dataQueue.sync(flags: .barrier) {
            persistToDisk()
        }
    }

    // MARK: - Record & Query

    func recordUsage(for snippetCommand: String) {
        dataQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            if self._storage[snippetCommand] != nil {
                self._storage[snippetCommand]?.recordUsage()
            } else {
                var newUsage = SnippetUsage(snippetCommand: snippetCommand)
                newUsage.recordUsage()
                self._storage[snippetCommand] = newUsage
            }

            let count = self._storage[snippetCommand]?.usageCount ?? 0
            let snapshot = self._storage

            // Save to disk immediately
            self.persistToDisk()

            // Sync UI on main thread
            DispatchQueue.main.async {
                self.usageData = snapshot
                self.objectWillChange.send()
                NotificationCenter.default.post(name: NSNotification.Name("SnippetUsageUpdated"), object: snippetCommand)
            }

            print("[UsageTracker] 📊 Recorded usage for command '\(snippetCommand)', total: \(count)")
        }
    }

    func getUsage(for snippetCommand: String) -> SnippetUsage? {
        return dataQueue.sync {
            return _storage[snippetCommand]
        }
    }

    func getUsageCount(for snippetCommand: String) -> Int {
        return dataQueue.sync {
            return _storage[snippetCommand]?.usageCount ?? 0
        }
    }

    func getLastUsed(for snippetCommand: String) -> String {
        return dataQueue.sync {
            return _storage[snippetCommand]?.formattedLastUsed ?? "Never"
        }
    }

    func getMostUsedSnippets(limit: Int = 10) -> [(snippetCommand: String, usage: SnippetUsage)] {
        return dataQueue.sync {
            return _storage
                .map { ($0.key, $0.value) }
                .sorted { $0.1.usageCount > $1.1.usageCount }
                .prefix(limit)
                .map { ($0, $1) }
        }
    }

    func getRecentlyUsedSnippets(limit: Int = 10) -> [(snippetCommand: String, usage: SnippetUsage)] {
        return dataQueue.sync {
            return _storage
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
            guard let self = self else { return }
            self._storage.removeAll()
            self.persistToDisk()
            DispatchQueue.main.async {
                self.usageData.removeAll()
            }
        }
    }

    // MARK: - Migration from ID-based to Command-based tracking

    private func migrateIfNeeded() {
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("[UsageTracker] ✅ Already migrated to command-based tracking")
            return
        }

        guard let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey) else {
            print("[UsageTracker] ℹ️ No legacy usage data to migrate")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let legacyUsage: [String: SnippetUsage]
        do {
            legacyUsage = try JSONDecoder().decode([String: SnippetUsage].self, from: legacyData)
        } catch {
            print("[UsageTracker] ⚠️ Failed to decode legacy usage data: \(error)")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        print("[UsageTracker] 🔄 Starting migration from ID-based to command-based tracking...")

        let snippets = LocalStorageService.shared.loadSnippets()
        let idToCommandMap = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0.command) })

        var migratedData: [String: SnippetUsage] = [:]
        var migratedCount = 0
        var skippedCount = 0

        for (snippetId, usage) in legacyUsage {
            if let command = idToCommandMap[snippetId] {
                var migratedUsage = SnippetUsage(snippetCommand: command)
                migratedUsage.usageCount = usage.usageCount
                migratedUsage.lastUsedDate = usage.lastUsedDate
                migratedUsage.firstUsedDate = usage.firstUsedDate

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
                skippedCount += 1
            }
        }

        // Save migrated data synchronously
        _storage = migratedData
        usageData = migratedData

        do {
            let encoded = try JSONEncoder().encode(migratedData)
            UserDefaults.standard.set(encoded, forKey: storageKey)
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("[UsageTracker] ✅ Migration complete: \(migratedCount) migrated, \(skippedCount) orphaned data cleaned")
        } catch {
            print("[UsageTracker] ❌ Migration failed: \(error)")
        }
    }
}