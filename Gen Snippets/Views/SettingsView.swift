import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var iCloudSync = iCloudSyncService.shared
    @State private var startAtLogin = false
    @State private var showStatusBarIcon = UserDefaults.standard.bool(forKey: "ShowStatusBarIcon")
    @State private var showSyncAlert = false
    @State private var syncAlertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.largeTitle)
                .bold()
            
            GroupBox(label: Label("General", systemImage: "gear")) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Start at Login", isOn: $startAtLogin)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onReceive([startAtLogin].publisher) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                    
                    Toggle("Show Status Bar Icon", isOn: $showStatusBarIcon)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onReceive([showStatusBarIcon].publisher) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "ShowStatusBarIcon")
                            NotificationCenter.default.post(name: NSNotification.Name("StatusBarIconVisibilityChanged"), object: nil, userInfo: ["isVisible": newValue])
                        }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("iCloud Sync", systemImage: "icloud")) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable iCloud Sync")
                                .font(.headline)
                            Text("Automatically sync your snippets across all your devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { iCloudSync.iCloudEnabled },
                            set: { newValue in
                                if newValue && !iCloudSync.isICloudAvailable {
                                    syncAlertMessage = "iCloud is not available. Please check your iCloud settings."
                                    showSyncAlert = true
                                } else {
                                    iCloudSync.iCloudEnabled = newValue
                                    if newValue {
                                        syncAlertMessage = "iCloud sync enabled. Your snippets will now sync across all your devices."
                                    } else {
                                        syncAlertMessage = "iCloud sync disabled. Your snippets will only be stored locally."
                                    }
                                    showSyncAlert = true
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .disabled(!iCloudSync.isICloudAvailable)
                    }
                    
                    if iCloudSync.isICloudEnabled {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    if iCloudSync.isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text(iCloudSync.isSyncing ? "Syncing..." : "Synced")
                                        .font(.subheadline)
                                }
                                
                                if let lastSync = iCloudSync.lastSyncDate {
                                    Text("Last synced: \(lastSync, formatter: relativeDateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button("Sync Now") {
                                iCloudSync.performSync()
                            }
                            .buttonStyle(.bordered)
                            .disabled(iCloudSync.isSyncing)
                        }
                    }
                    
                    if let error = iCloudSync.syncError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onAppear {
            checkLaunchAtLogin()
        }
        .alert(isPresented: $showSyncAlert) {
            Alert(
                title: Text("iCloud Sync"),
                message: Text(syncAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            startAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            startAtLogin = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
    }
    
    private func toggleLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        } else {
            UserDefaults.standard.set(enable, forKey: "LaunchAtLogin")
        }
    }
    
    private var relativeDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
}