import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @StateObject private var categoryViewModel = CategoryViewModel()
    @StateObject private var snippetsViewModel = LocalSnippetsViewModel()
    @State private var isQuitting = false
    @State private var showClearDataAlert = false
    
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
                    Text("GenSnippets")
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