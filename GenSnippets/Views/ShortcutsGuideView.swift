import SwiftUI

struct ShortcutsGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                
                Text("Keyboard Shortcuts")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Global Shortcuts
                    ShortcutSection(title: "Global Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: "⌥ S",
                            description: "Open Snippet Search",
                            note: "Quick access to search and insert snippets"
                        )
                    ])
                    
                    // App Shortcuts
                    ShortcutSection(title: "App Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: "⌘ ,",
                            description: "Open Settings",
                            note: "Configure app preferences"
                        ),
                        ShortcutItem(
                            keys: "⌘ N",
                            description: "New Snippet",
                            note: "Create a new snippet in current category"
                        ),
                        ShortcutItem(
                            keys: "⌘ ⇧ N",
                            description: "New Category",
                            note: "Create a new category"
                        ),
                        ShortcutItem(
                            keys: "⌘ Q",
                            description: "Quit App",
                            note: "Show quit confirmation dialog"
                        )
                    ])
                    
                    // Search View Shortcuts
                    ShortcutSection(title: "Search View Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: "↑ ↓",
                            description: "Navigate snippets",
                            note: "Move between search results"
                        ),
                        ShortcutItem(
                            keys: "↩",
                            description: "Insert snippet",
                            note: "Insert selected snippet into previous app"
                        ),
                        ShortcutItem(
                            keys: "⎋",
                            description: "Close search",
                            note: "Close search window without inserting"
                        ),
                        ShortcutItem(
                            keys: "Double-click",
                            description: "Quick insert",
                            note: "Insert snippet immediately"
                        )
                    ])
                    
                    // Editor Shortcuts
                    ShortcutSection(title: "Editor Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: "⌘ S",
                            description: "Save",
                            note: "Save current snippet or category"
                        ),
                        ShortcutItem(
                            keys: "⌘ D",
                            description: "Duplicate",
                            note: "Duplicate selected snippet"
                        ),
                        ShortcutItem(
                            keys: "⌘ ⌫",
                            description: "Delete",
                            note: "Delete selected item"
                        )
                    ])
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [ShortcutItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(shortcuts, id: \.keys) { shortcut in
                    HStack(alignment: .top, spacing: 16) {
                        // Keys
                        Text(shortcut.keys)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.8))
                            )
                            .frame(minWidth: 80, alignment: .center)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if let note = shortcut.note {
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.leading, 4)
        }
    }
}

struct ShortcutItem {
    let keys: String
    let description: String
    let note: String?
}


struct ShortcutsGuideView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutsGuideView()
    }
}