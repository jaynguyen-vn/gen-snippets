import SwiftUI
import ServiceManagement

@available(macOS 12.0, *)
struct ModernSettingsView: View {
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
            // Header
            ZStack {
                HStack {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
                .opacity(0.5)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // General Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("General")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 16) {
                            // Start at Login
                            SettingRow(
                                icon: "power.circle",
                                title: "Start at Login",
                                description: "Launch app when you start your Mac"
                            ) {
                                Toggle("", isOn: $startAtLogin)
                                    .toggleStyle(MinimalToggleStyle())
                                    .onChange(of: startAtLogin) { value in
                                        toggleLaunchAtLogin(value)
                                    }
                            }
                            
                            Divider()
                                .opacity(0.3)
                            
                            // Status Bar Icon
                            SettingRow(
                                icon: "menubar.rectangle",
                                title: "Menu Bar Icon",
                                description: "Show icon in menu bar"
                            ) {
                                Toggle("", isOn: $showStatusBarIcon)
                                    .toggleStyle(MinimalToggleStyle())
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
                    }
                    
                    // Shortcuts Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Shortcuts")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 16) {
                            SettingRow(
                                icon: "command.square",
                                title: "Search Snippets",
                                description: "Global shortcut to open search"
                            ) {
                                HStack(spacing: 8) {
                                    ShortcutRecorderView(
                                        keyCode: $tempKeyCode,
                                        modifierFlags: $tempModifiers
                                    )
                                    .frame(width: 120, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(hasUnsavedShortcut ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
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
                                        .buttonStyle(MinimalButtonStyle(isProminent: true))
                                        
                                        Button("Cancel") {
                                            tempKeyCode = searchShortcutKeyCode
                                            tempModifiers = searchShortcutModifiers
                                            hasUnsavedShortcut = false
                                        }
                                        .buttonStyle(MinimalButtonStyle())
                                    }
                                    
                                    Button("Reset") {
                                        tempKeyCode = 0
                                        tempModifiers = []
                                        DispatchQueue.main.async {
                                            tempKeyCode = 49
                                            tempModifiers = .option
                                            searchShortcutKeyCode = 49
                                            searchShortcutModifiers = .option
                                            saveShortcut()
                                            hasUnsavedShortcut = false
                                        }
                                    }
                                    .buttonStyle(MinimalButtonStyle())
                                    .opacity(hasUnsavedShortcut ? 0.5 : 1)
                                    .disabled(hasUnsavedShortcut)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 380)
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
    
    private func saveShortcut() {
        UserDefaults.standard.set(searchShortcutKeyCode, forKey: "SearchShortcutKeyCode")
        UserDefaults.standard.set(Int(searchShortcutModifiers.rawValue), forKey: "SearchShortcutModifiers")
        NotificationCenter.default.post(name: NSNotification.Name("UpdateSearchShortcut"), object: nil)
    }
}

// Setting Row Component
struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.primary.opacity(0.8))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
            
            Spacer()
            
            // Control
            content()
        }
        .padding(.vertical, 4)
    }
}

// Minimal Toggle Style
struct MinimalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 42, height: 24)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isOn)
    }
}

// Minimal Button Style
struct MinimalButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isProminent ? Color.accentColor : Color.primary.opacity(configuration.isPressed ? 0.08 : 0.06))
            )
            .foregroundColor(isProminent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}