import SwiftUI

struct StatusBarView: View {
    let shortcuts = [
        ("⌃⌘S", "Search"),
        ("⌘N", "New Snippet"),
        ("⌘⇧N", "New Category"),
        ("⌘,", "Settings"),
        ("⌘S", "Save"),
        ("⌘D", "Duplicate"),
        ("⌘⌫", "Delete")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(shortcuts, id: \.0) { shortcut in
                        HStack(spacing: 4) {
                            Text(shortcut.0)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                            
                            Text(shortcut.1)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        
                        if shortcut.0 != shortcuts.last?.0 {
                            Divider()
                                .frame(height: 14)
                                .opacity(0.2)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("GenSnippets made by")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                
                Button(action: {
                    if let url = URL(string: "https://www.facebook.com/iductruong") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Jay")
                        .font(.system(size: 11))
                        .foregroundColor(.blue.opacity(0.8))
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.trailing, 12)
        }
        .frame(height: 26)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.secondary.opacity(0.15)),
            alignment: .top
        )
    }
}