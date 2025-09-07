import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var startAtLogin = false
    @State private var showStatusBarIcon = UserDefaults.standard.bool(forKey: "ShowStatusBarIcon")
    @State private var searchShortcutKeyCode = UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode") == 0 ? 1 : UserDefaults.standard.integer(forKey: "SearchShortcutKeyCode")
    @State private var searchShortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "SearchShortcutModifiers") == 0 ? Int(NSEvent.ModifierFlags.option.rawValue) : UserDefaults.standard.integer(forKey: "SearchShortcutModifiers")))
    @State private var tempKeyCode: Int = 0
    @State private var tempModifiers = NSEvent.ModifierFlags()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close (Esc)")
            }
            
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
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Search Shortcut:")
                                .frame(width: 120, alignment: .leading)
                            
                            ShortcutRecorderView(
                                keyCode: $tempKeyCode,
                                modifierFlags: $tempModifiers
                            )
                            .frame(height: 24)
                            
                            Button("Save") {
                                searchShortcutKeyCode = tempKeyCode
                                searchShortcutModifiers = tempModifiers
                                saveShortcut()
                            }
                            .buttonStyle(.bordered)
                            .disabled(tempKeyCode == searchShortcutKeyCode && tempModifiers == searchShortcutModifiers)
                            
                            Button("Reset") {
                                // Force update by setting to different value first
                                tempKeyCode = 0
                                tempModifiers = []
                                
                                // Then set to default values
                                DispatchQueue.main.async {
                                    tempKeyCode = 49 // Space
                                    tempModifiers = .option
                                    searchShortcutKeyCode = 49
                                    searchShortcutModifiers = .option
                                    saveShortcut()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                        
                        if tempKeyCode != searchShortcutKeyCode || tempModifiers != searchShortcutModifiers {
                            Text("Click Save to apply the new shortcut")
                                .font(.caption)
                                .foregroundColor(.orange)
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
            // Initialize temp variables with current values
            tempKeyCode = searchShortcutKeyCode
            tempModifiers = searchShortcutModifiers
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EscapeKeyPressed"))) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .background(
            // Invisible view to capture keyboard events
            KeyEventCaptureView {
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
}

// Helper view to capture Escape key
struct KeyEventCaptureView: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = EscapeKeyView()
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class EscapeKeyView: NSView {
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

extension SettingsView {
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
        
        // Notify the hotkey manager to update
        NotificationCenter.default.post(name: NSNotification.Name("UpdateSearchShortcut"), object: nil)
    }
}