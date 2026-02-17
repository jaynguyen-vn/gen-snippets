import Foundation

/// One-time migration of UserDefaults data from sandboxed container to non-sandboxed location.
/// Required when transitioning from ENABLE_APP_SANDBOX=YES to NO (v2.7.0).
class SandboxMigrationService {
    static let shared = SandboxMigrationService()

    private let migrationKey = "SandboxMigrationCompleted_v2.7.0"
    private let bundleID = "Jay8448.Gen-Snippets"

    private init() {}

    /// Migrate sandbox data if needed. Call this BEFORE any UserDefaults reads.
    func migrateIfNeeded() {
        // Skip if already migrated
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            NSLog("📦 SandboxMigration: Already migrated, skipping")
            return
        }

        // Skip if non-sandboxed plist already has data (fresh install or already working)
        let nonSandboxedKeys = ["localSnippets", "localCategories"]
        let hasExistingData = nonSandboxedKeys.contains { UserDefaults.standard.object(forKey: $0) != nil }
        if hasExistingData {
            NSLog("📦 SandboxMigration: Non-sandboxed data exists, marking complete")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // Check if sandboxed plist exists
        let sandboxedPlistPath = NSHomeDirectory()
            .appending("/Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")

        guard FileManager.default.fileExists(atPath: sandboxedPlistPath) else {
            NSLog("📦 SandboxMigration: No sandboxed plist found at \(sandboxedPlistPath)")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        NSLog("📦 SandboxMigration: Found sandboxed plist, migrating...")

        // Load sandboxed plist
        guard let sandboxedData = NSDictionary(contentsOfFile: sandboxedPlistPath) as? [String: Any] else {
            NSLog("📦 SandboxMigration: Failed to read sandboxed plist")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // Copy all keys to current UserDefaults
        var migratedCount = 0
        for (key, value) in sandboxedData {
            // Don't overwrite migration marker or Apple internal keys
            if key.hasPrefix("NS") || key.hasPrefix("Apple") || key.hasPrefix("com.apple") {
                continue
            }
            UserDefaults.standard.set(value, forKey: key)
            migratedCount += 1
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()

        NSLog("📦 SandboxMigration: Migrated \(migratedCount) keys successfully")
    }
}
