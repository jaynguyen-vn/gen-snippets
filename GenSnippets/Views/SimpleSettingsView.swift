import SwiftUI
import ServiceManagement

@available(macOS 12.0, *)
struct SimpleSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var startAtLogin = false
    @State private var showStatusBarIcon = UserDefaults.standard.bool(forKey: "ShowStatusBarIcon")
    @State private var searchShortcutKeyCode = UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode") == 0 ? 1 : UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode")
    @State private var searchShortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "SearchShortcutModifiers") == 0 ? Int(NSEvent.ModifierFlags.option.rawValue) : UserDefaults.standard.integer(forKey: "SearchShortcutModifiers")))
    @State private var tempKeyCode: Int = 0
    @State private var tempModifiers = NSEvent.ModifierFlags()
    @State private var hasUnsavedShortcut = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple Header
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("GENERAL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Start at Login
                        HStack {
                            Image(systemName: "power.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start at Login")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Launch app when you start your Mac")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $startAtLogin)
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                .scaleEffect(0.8)
                                .onChange(of: startAtLogin) { value in
                                    toggleLaunchAtLogin(value)
                                }
                        }
                        
                        Divider()
                        
                        // Menu Bar Icon
                        HStack {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Menu Bar Icon")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Show icon in menu bar")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $showStatusBarIcon)
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                .scaleEffect(0.8)
                                .onChange(of: showStatusBarIcon) { value in
                                    UserDefaults.standard.set(value, forKey: "ShowStatusBarIcon")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("StatusBarIconVisibilityChanged"),
                                        object: nil,
                                        userInfo: ["isVisible": value]
                                    )
                                }
                        }
                    }
                    
                    Divider()
                    
                    // Shortcuts Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SHORTCUTS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "command.square")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Search Snippets")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Global shortcut to open search")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    ShortcutRecorderView(
                                        keyCode: $tempKeyCode,
                                        modifierFlags: $tempModifiers
                                    )
                                    .frame(width: 160, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(hasUnsavedShortcut ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                                    .onChange(of: tempKeyCode) { _ in checkShortcutChanged() }
                                    .onChange(of: tempModifiers) { _ in checkShortcutChanged() }
                                    
                                    if hasUnsavedShortcut {
                                        Button("Save") {
                                            searchShortcutKeyCode = tempKeyCode
                                            searchShortcutModifiers = tempModifiers
                                            saveShortcut()
                                            hasUnsavedShortcut = false
                                        }
                                        .buttonStyle(SimpleButtonStyle(isPrimary: true))
                                    }
                                    
                                    Button("Reset") {
                                        resetShortcut()
                                    }
                                    .buttonStyle(SimpleButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 680, idealWidth: 720, maxWidth: 800, minHeight: 320, idealHeight: 360, maxHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            checkLaunchAtLogin()
            tempKeyCode = searchShortcutKeyCode
            tempModifiers = searchShortcutModifiers
        }
        .background(
            KeyEventCaptureView {
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
    
    private func checkShortcutChanged() {
        hasUnsavedShortcut = (tempKeyCode != searchShortcutKeyCode || tempModifiers != searchShortcutModifiers)
    }
    
    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            startAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            // For macOS 12, check if the helper app is in login items
            let bundleId = "com.bip.GenSnippets-Helper"
            let runningApps = NSWorkspace.shared.runningApplications
            startAtLogin = runningApps.contains { $0.bundleIdentifier == bundleId }
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
                print("[Settings] Launch at login: \(enable ? "enabled" : "disabled")")
            } catch {
                print("[Settings] Failed to toggle launch at login: \(error)")
                // Revert the toggle if it failed
                DispatchQueue.main.async {
                    startAtLogin = !enable
                }
            }
        } else {
            // For macOS 12, use legacy approach
            UserDefaults.standard.set(enable, forKey: "LaunchAtLogin")
            print("[Settings] Launch at login preference saved: \(enable)")
        }
    }
    
    private func saveShortcut() {
        UserDefaults.standard.set(searchShortcutKeyCode, forKey: "SearchShortcutKeyCode")
        UserDefaults.standard.set(Int(searchShortcutModifiers.rawValue), forKey: "SearchShortcutModifiers")
        NotificationCenter.default.post(name: NSNotification.Name("UpdateSearchShortcut"), object: nil)
    }
    
    private func resetShortcut() {
        // Reset to default values immediately
        tempKeyCode = 49  // Space key
        tempModifiers = .option
        searchShortcutKeyCode = 49
        searchShortcutModifiers = .option
        hasUnsavedShortcut = false
        
        // Save the default values
        saveShortcut()
    }
}

// Simple Button Style
struct SimpleButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isPrimary ? Color.accentColor : Color.primary.opacity(configuration.isPressed ? 0.08 : 0.06))
            )
            .foregroundColor(isPrimary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

// Preview
@available(macOS 12.0, *)
struct SimpleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleSettingsView()
    }
}