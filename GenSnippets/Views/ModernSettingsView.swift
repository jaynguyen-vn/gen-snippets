import SwiftUI
import ServiceManagement

@available(macOS 12.0, *)
struct ModernSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var startAtLogin = false
    @State private var showStatusBarIcon = UserDefaults.standard.bool(forKey: "ShowStatusBarIcon")
    @State private var searchShortcutKeyCode = UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode") == 0 ? 1 : UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode")
    @State private var searchShortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "SearchShortcutModifiers") == 0 ? Int(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.command.rawValue) : UserDefaults.standard.integer(forKey: "SearchShortcutModifiers")))
    @State private var tempKeyCode: Int = 0
    @State private var tempModifiers = NSEvent.ModifierFlags()
    @State private var hasUnsavedShortcut = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                HStack {
                    Text("Settings")
                        .font(DSTypography.displaySmall)
                        .foregroundColor(DSColors.textPrimary)

                    Spacer()

                    DSCloseButton {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.xl)
            }
            .background(DSColors.windowBackground)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xxxl) {
                    // General Section
                    VStack(alignment: .leading, spacing: DSSpacing.xl) {
                        DSSectionHeader(title: "General")
                        
                        VStack(spacing: DSSpacing.lg) {
                            // Start at Login
                            SettingRow(
                                icon: "power.circle",
                                title: "Start at Login",
                                description: "Launch app when you start your Mac"
                            ) {
                                Toggle("", isOn: $startAtLogin)
                                    .toggleStyle(DSToggleStyle())
                                    .onChange(of: startAtLogin) { value in
                                        toggleLaunchAtLogin(value)
                                    }
                            }

                            DSDivider()

                            // Status Bar Icon
                            SettingRow(
                                icon: "menubar.rectangle",
                                title: "Menu Bar Icon",
                                description: "Show icon in menu bar"
                            ) {
                                Toggle("", isOn: $showStatusBarIcon)
                                    .toggleStyle(DSToggleStyle())
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
                    VStack(alignment: .leading, spacing: DSSpacing.xl) {
                        DSSectionHeader(title: "Shortcuts")
                        
                        VStack(spacing: DSSpacing.lg) {
                            SettingRow(
                                icon: "command.square",
                                title: "Search Snippets",
                                description: "Global shortcut to open search"
                            ) {
                                HStack(spacing: DSSpacing.sm) {
                                    ShortcutRecorderView(
                                        keyCode: $tempKeyCode,
                                        modifierFlags: $tempModifiers
                                    )
                                    .frame(width: 120, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: DSRadius.sm)
                                            .fill(DSColors.surfaceSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DSRadius.sm)
                                            .stroke(hasUnsavedShortcut ? DSColors.warning.opacity(0.5) : Color.clear, lineWidth: 1)
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
                                        .buttonStyle(DSButtonStyle(.primary, size: .small))

                                        Button("Cancel") {
                                            tempKeyCode = searchShortcutKeyCode
                                            tempModifiers = searchShortcutModifiers
                                            hasUnsavedShortcut = false
                                        }
                                        .buttonStyle(DSButtonStyle(.tertiary, size: .small))
                                    }

                                    Button("Reset") {
                                        tempKeyCode = 0
                                        tempModifiers = []
                                        DispatchQueue.main.async {
                                            tempKeyCode = 1
                                            tempModifiers = [.control, .command]
                                            searchShortcutKeyCode = 1
                                            searchShortcutModifiers = [.control, .command]
                                            saveShortcut()
                                            hasUnsavedShortcut = false
                                        }
                                    }
                                    .buttonStyle(DSButtonStyle(.tertiary, size: .small))
                                    .opacity(hasUnsavedShortcut ? 0.5 : 1)
                                    .disabled(hasUnsavedShortcut)
                                }
                            }
                        }
                    }
                }
                .padding(DSSpacing.xxl)
            }
        }
        .frame(width: 500, height: 400)
        .background(DSColors.windowBackground)
        .onAppear {
            checkLaunchAtLogin()
            // Initialize temp variables with current or default values
            tempKeyCode = searchShortcutKeyCode == 0 ? 1 : searchShortcutKeyCode
            tempModifiers = searchShortcutModifiers.isEmpty ? [.control, .command] : searchShortcutModifiers
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
        HStack(alignment: .center, spacing: DSSpacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(DSColors.surfaceSecondary)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: DSIconSize.md))
                    .foregroundColor(DSColors.textPrimary.opacity(0.85))
            }

            // Text
            VStack(alignment: .leading, spacing: DSSpacing.xxxs) {
                Text(title)
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.textPrimary)

                Text(description)
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textSecondary)
            }

            Spacer()

            // Control
            content()
        }
        .padding(.vertical, DSSpacing.xxs)
    }
}

// Legacy MinimalToggleStyle - kept for compatibility but should migrate to DSToggleStyle
struct MinimalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? DSColors.accent : DSColors.hoverBackground)
                    .frame(width: 42, height: 24)

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: DSShadow.xs.color, radius: DSShadow.xs.radius, x: 0, y: DSShadow.xs.y)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(DSAnimation.springQuick, value: configuration.isOn)
    }
}

// Legacy MinimalButtonStyle - kept for compatibility but should migrate to DSButtonStyle
struct MinimalButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.labelSmall)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(isProminent ? DSColors.accent : (configuration.isPressed ? DSColors.hoverBackground : DSColors.surfaceSecondary))
            )
            .foregroundColor(isProminent ? .white : DSColors.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DSAnimation.springQuick, value: configuration.isPressed)
    }
}