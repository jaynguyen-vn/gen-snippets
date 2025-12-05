import SwiftUI

struct StatusBarView: View {
    let shortcuts = [
        (["Option", "Cmd", "E"], "Search"),
        (["Cmd", "N"], "New"),
        (["Cmd", "Shift", "N"], "Category"),
        (["Cmd", ","], "Settings"),
        (["Cmd", "S"], "Save")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    ForEach(shortcuts, id: \.1) { shortcut in
                        StatusBarShortcut(keys: shortcut.0, label: shortcut.1)

                        if shortcut.1 != shortcuts.last?.1 {
                            Circle()
                                .fill(DSColors.borderSubtle)
                                .frame(width: 3, height: 3)
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.md)
            }

            Spacer()

            HStack(spacing: DSSpacing.xxs) {
                Text("GenSnippets by")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)

                Button(action: {
                    if let url = URL(string: "https://www.facebook.com/iductruong") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Jay")
                        .font(DSTypography.captionMedium)
                        .foregroundColor(DSColors.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.trailing, DSSpacing.md)
        }
        .frame(height: 28)
        .background(DSColors.surfaceSecondary.opacity(0.8))
        .overlay(
            DSDivider(),
            alignment: .top
        )
    }
}

struct StatusBarShortcut: View {
    let keys: [String]
    let label: String

    private func keySymbol(_ key: String) -> String {
        switch key.lowercased() {
        case "cmd", "command": return "\u{2318}"
        case "option", "alt": return "\u{2325}"
        case "shift": return "\u{21E7}"
        case "control", "ctrl": return "\u{2303}"
        default: return key
        }
    }

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            HStack(spacing: 1) {
                ForEach(keys, id: \.self) { key in
                    Text(keySymbol(key))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
            }
            .foregroundColor(DSColors.textPrimary.opacity(0.8))
            .padding(.horizontal, DSSpacing.xxs + 2)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.xxs)
                    .fill(DSColors.accent.opacity(0.1))
            )

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DSColors.textSecondary)
        }
    }
}
