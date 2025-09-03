import Foundation
import Combine

class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isICloudAvailable = false
    @Published var isICloudEnabled = false
    
    private let kvStore = NSUbiquitousKeyValueStore.default
    private let categoriesKey = "iCloud.categories"
    private let snippetsKey = "iCloud.snippets"
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let iCloudEnabledKey = "iCloudSyncEnabled"
    private let localStorageService = LocalStorageService.shared
    
    private init() {
        self.isICloudEnabled = UserDefaults.standard.bool(forKey: iCloudEnabledKey)
        
        checkICloudAvailability()
        if isICloudEnabled {
            setupCloudSync()
            startAutoSync()
        }
    }
    
    var iCloudEnabled: Bool {
        get { isICloudEnabled }
        set {
            isICloudEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: iCloudEnabledKey)
            
            if newValue {
                setupCloudSync()
                startAutoSync()
                performSync()
            } else {
                stopAutoSync()
            }
        }
    }
    
    private func checkICloudAvailability() {
        if FileManager.default.ubiquityIdentityToken != nil {
            isICloudAvailable = true
            print("[iCloud] iCloud account is available")
        } else {
            isICloudAvailable = false
            syncError = "No iCloud account configured"
            print("[iCloud] No iCloud account available")
        }
    }
    
    private func setupCloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        
        kvStore.synchronize()
    }
    
    @objc private func kvStoreDidChange(_ notification: Notification) {
        guard isICloudEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.syncFromCloud()
        }
    }
    
    private func startAutoSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performSync()
        }
    }
    
    private func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    func performSync() {
        guard isICloudEnabled && isICloudAvailable else { return }
        
        isSyncing = true
        syncError = nil
        
        syncToCloud()
        syncFromCloud()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isSyncing = false
            self?.lastSyncDate = Date()
            print("[iCloud] Sync completed")
        }
    }
    
    private func syncToCloud() {
        let categories = localStorageService.loadCategories()
        let snippets = localStorageService.loadSnippets()
        
        if let categoriesData = try? JSONEncoder().encode(categories) {
            kvStore.set(categoriesData, forKey: categoriesKey)
        }
        
        if let snippetsData = try? JSONEncoder().encode(snippets) {
            kvStore.set(snippetsData, forKey: snippetsKey)
        }
        
        kvStore.synchronize()
        print("[iCloud] Synced \(categories.count) categories and \(snippets.count) snippets to iCloud")
    }
    
    private func syncFromCloud() {
        var cloudCategories: [Category] = []
        var cloudSnippets: [Snippet] = []
        
        if let categoriesData = kvStore.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([Category].self, from: categoriesData) {
            cloudCategories = categories
        }
        
        if let snippetsData = kvStore.data(forKey: snippetsKey),
           let snippets = try? JSONDecoder().decode([Snippet].self, from: snippetsData) {
            cloudSnippets = snippets
        }
        
        if !cloudCategories.isEmpty || !cloudSnippets.isEmpty {
            mergeWithLocal(categories: cloudCategories, snippets: cloudSnippets)
            print("[iCloud] Synced \(cloudCategories.count) categories and \(cloudSnippets.count) snippets from iCloud")
        }
    }
    
    private func mergeWithLocal(categories: [Category], snippets: [Snippet]) {
        let localCategories = localStorageService.loadCategories()
        let localSnippets = localStorageService.loadSnippets()
        
        var mergedCategories = localCategories
        var mergedSnippets = localSnippets
        
        for cloudCategory in categories {
            if !mergedCategories.contains(where: { $0.id == cloudCategory.id }) {
                mergedCategories.append(cloudCategory)
            } else if let index = mergedCategories.firstIndex(where: { $0.id == cloudCategory.id }) {
                let localDate = ISO8601DateFormatter().date(from: mergedCategories[index].updatedAt ?? "") ?? Date.distantPast
                let cloudDate = ISO8601DateFormatter().date(from: cloudCategory.updatedAt ?? "") ?? Date.distantPast
                
                if cloudDate > localDate {
                    mergedCategories[index] = cloudCategory
                }
            }
        }
        
        for cloudSnippet in snippets {
            if !mergedSnippets.contains(where: { $0.id == cloudSnippet.id }) {
                mergedSnippets.append(cloudSnippet)
            } else if let index = mergedSnippets.firstIndex(where: { $0.id == cloudSnippet.id }) {
                let localDate = ISO8601DateFormatter().date(from: mergedSnippets[index].updatedAt ?? "") ?? Date.distantPast
                let cloudDate = ISO8601DateFormatter().date(from: cloudSnippet.updatedAt ?? "") ?? Date.distantPast
                
                if cloudDate > localDate {
                    mergedSnippets[index] = cloudSnippet
                }
            }
        }
        
        localStorageService.saveCategories(mergedCategories)
        localStorageService.saveSnippets(mergedSnippets)
        
        NotificationCenter.default.post(name: NSNotification.Name("CategoriesUpdated"), object: mergedCategories)
        NotificationCenter.default.post(name: NSNotification.Name("SnippetsUpdated"), object: mergedSnippets)
        TextReplacementService.shared.updateSnippets(mergedSnippets)
    }
    
    func saveSnippetToCloud(_ snippet: Snippet) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
    
    func updateSnippetInCloud(_ snippet: Snippet) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
    
    func deleteSnippetFromCloud(_ snippetId: String) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
    
    func saveCategoryToCloud(_ category: Category) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
    
    func updateCategoryInCloud(_ category: Category) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
    
    func deleteCategoryFromCloud(_ categoryId: String) {
        guard isICloudEnabled && isICloudAvailable else { return }
        performSync()
    }
}