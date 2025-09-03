import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @StateObject private var categoryViewModel = CategoryViewModel()
    @StateObject private var snippetsViewModel = LocalSnippetsViewModel()
    @State private var isQuitting = false
    @State private var showClearDataAlert = false
    @State private var launchAtLogin = false
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with Open App button
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gen Snippets")
                        .font(.system(size: 14, weight: .medium))
                    Text("Text Expansion Tool")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // First show dock icon
                    NotificationCenter.default.post(name: NSNotification.Name("ShowDockIcon"), object: nil)
                    // Then open main window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let window = NSApplication.shared.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                    // Close popover
                    NotificationCenter.default.post(name: NSNotification.Name("ClosePopover"), object: nil)
                }) {
                    Text("Open App")
                        .font(.system(size: 12))
                }
                .buttonStyle(ModernButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider()
            
            // Info Section
            VStack(spacing: 0) {
                // Total Snippets
                HStack {
                    Image(systemName: "doc.text")
                        .frame(width: 20)
                        .foregroundColor(.primary)
                    Text("Total Snippets")
                    Spacer()
                    Text("\(snippetsViewModel.snippets.count)")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Categories
                HStack {
                    Image(systemName: "folder")
                        .frame(width: 20)
                        .foregroundColor(.primary)
                    Text("Categories")
                    Spacer()
                    Text("\(categoryViewModel.categories.count)")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // About
                HStack {
                    Image(systemName: "info.circle")
                        .frame(width: 20)
                        .foregroundColor(.primary)
                    Text("About")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Launch at Login toggle
            Button(action: {
                toggleLaunchAtLogin()
            }) {
                HStack {
                    Image(systemName: launchAtLogin ? "checkmark.square" : "square")
                        .frame(width: 20)
                        .foregroundColor(.primary)
                    Text("Launch at Login")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
            
            // Clear All Data button
            Button(action: {
                showClearDataAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .frame(width: 20)
                        .foregroundColor(.red)
                    Text("Clear All Data")
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(VisualEffectBackground())
        .onAppear {
            categoryViewModel.fetchCategories()
            snippetsViewModel.fetchSnippets()
            checkLaunchAtLoginStatus()
        }
        .alert(isPresented: $showClearDataAlert) {
            Alert(
                title: Text("Clear All Data"),
                message: Text("Are you sure you want to delete all snippets and categories? This action cannot be undone."),
                primaryButton: .destructive(Text("Clear All")) {
                    clearAllData()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func clearAllData() {
        // Clear all data
        snippetsViewModel.clearAllData()
        categoryViewModel.clearAllData()
        
        // Force reload data after a short delay to ensure clearing is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            categoryViewModel.fetchCategories()
            snippetsViewModel.fetchSnippets()
            
            // Notify main app to refresh its views
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAllData"), object: nil)
        }
        
        // Close popover after clearing
        NotificationCenter.default.post(name: NSNotification.Name("ClosePopover"), object: nil)
        
        // Show notification
        NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: ["message": "All data has been cleared", "type": "success"])
    }
    
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            // For macOS 12 and earlier, we can't directly check the status
            // so we use UserDefaults as our source of truth
            launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
            
            // Try to sync the actual state with our saved state
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                // This will ensure the state matches what we have saved
                _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, launchAtLogin)
            }
        }
    }
    
    private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                    launchAtLogin = false
                } else {
                    try service.register()
                    launchAtLogin = true
                }
                
                // Save to UserDefaults for persistence
                UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
                
                // Show notification
                let message = launchAtLogin ? "Gen Snippets will start automatically at login" : "Gen Snippets will not start automatically at login"
                NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: ["message": message, "type": "success"])
            } catch {
                print("Failed to toggle login item: \(error)")
                // Show error notification
                NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: ["message": "Failed to update launch at login setting", "type": "error"])
            }
        } else {
            // For macOS 12 and earlier
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                launchAtLogin.toggle()
                let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, launchAtLogin)
                
                if success {
                    // Save to UserDefaults for persistence
                    UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
                    
                    // Show notification
                    let message = launchAtLogin ? "Gen Snippets will start automatically at login" : "Gen Snippets will not start automatically at login"
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: ["message": message, "type": "success"])
                } else {
                    // Revert state on failure
                    launchAtLogin.toggle()
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: ["message": "Failed to update launch at login setting", "type": "error"])
                }
            }
        }
    }
}

// MARK: - Status Row View
struct StatusRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - Visual Effect Background
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .frame(width: 350, height: 500)
    }
}