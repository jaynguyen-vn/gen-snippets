import SwiftUI

struct StatusBarView: View {
    let shortcuts = [
        ("Cmd+N", "New Snippet"),
        ("Cmd+Shift+N", "New Category"),
        ("Cmd+Q", "Quit")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(shortcuts, id: \.0) { shortcut in
                HStack(spacing: 4) {
                    Text(shortcut.0)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    
                    Text(shortcut.1)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                
                if shortcut.0 != shortcuts.last?.0 {
                    Divider()
                        .frame(height: 16)
                        .opacity(0.3)
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
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.secondary.opacity(0.2)),
            alignment: .top
        )
    }
}