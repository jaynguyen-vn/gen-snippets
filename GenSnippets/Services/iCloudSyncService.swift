import Foundation
import Combine

// Stub implementation - iCloud sync is disabled due to missing entitlements
class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isICloudAvailable = false
    @Published var isICloudEnabled = false
    
    private init() {
        // iCloud is disabled - missing entitlements
    }
    
    var iCloudEnabled: Bool {
        get { false }
        set {
            print("[iCloud] iCloud sync is disabled - missing entitlements")
        }
    }
    
    func performSync() {
        // No-op - iCloud is disabled
    }
    
    func debugCheckCloudData() -> (categories: Int, snippets: Int, categoriesSize: Int, snippetsSize: Int) {
        return (categories: 0, snippets: 0, categoriesSize: 0, snippetsSize: 0)
    }
}