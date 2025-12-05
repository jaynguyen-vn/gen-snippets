import SwiftUI

struct ShortcutsGuideView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: DSSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .fill(DSColors.accent.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "keyboard")
                            .font(.system(size: DSIconSize.md))
                            .foregroundColor(DSColors.accent)
                    }

                    Text("Keyboard Shortcuts")
                        .font(DSTypography.displaySmall)
                        .foregroundColor(DSColors.textPrimary)
                }

                Spacer()

                DSCloseButton {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                    // Global Shortcuts
                    ShortcutSection(title: "Global Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: ["Option", "Cmd", "E"],
                            description: "Open Snippet Search",
                            note: "Quick access to search and insert snippets"
                        )
                    ])

                    // App Shortcuts
                    ShortcutSection(title: "App Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: ["Cmd", ","],
                            description: "Open Settings",
                            note: "Configure app preferences"
                        ),
                        ShortcutItem(
                            keys: ["Cmd", "N"],
                            description: "New Snippet",
                            note: "Create a new snippet in current category"
                        ),
                        ShortcutItem(
                            keys: ["Cmd", "Shift", "N"],
                            description: "New Category",
                            note: "Create a new category"
                        ),
                        ShortcutItem(
                            keys: ["Cmd", "Q"],
                            description: "Quit App",
                            note: "Show quit confirmation dialog"
                        )
                    ])

                    // Editor Shortcuts
                    ShortcutSection(title: "Editor Shortcuts", shortcuts: [
                        ShortcutItem(
                            keys: ["Cmd", "S"],
                            description: "Save",
                            note: "Save current snippet or category"
                        ),
                        ShortcutItem(
                            keys: ["Cmd", "D"],
                            description: "Duplicate",
                            note: "Duplicate selected snippet"
                        ),
                        ShortcutItem(
                            keys: ["Cmd", "Delete"],
                            description: "Delete",
                            note: "Delete selected item"
                        )
                    ])

                    // Navigation Shortcuts
                    ShortcutSection(title: "Navigation", shortcuts: [
                        ShortcutItem(
                            keys: ["Up", "Down"],
                            description: "Navigate Items",
                            note: "Move between snippets or categories"
                        ),
                        ShortcutItem(
                            keys: ["Return"],
                            description: "Select/Confirm",
                            note: "Select item or confirm action"
                        ),
                        ShortcutItem(
                            keys: ["Escape"],
                            description: "Cancel/Close",
                            note: "Close dialogs or cancel actions"
                        )
                    ])
                }
                .padding(DSSpacing.xxl)
            }
        }
        .frame(width: 520, height: 640)
        .background(DSColors.windowBackground)
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [ShortcutItem]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title)
                .font(DSTypography.heading2)
                .foregroundColor(DSColors.textPrimary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(shortcuts, id: \.description) { shortcut in
                    ShortcutRowView(shortcut: shortcut)
                }
            }
        }
    }
}

struct ShortcutRowView: View {
    let shortcut: ShortcutItem
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.lg) {
            // Keys
            HStack(spacing: DSSpacing.xxs) {
                ForEach(shortcut.keys, id: \.self) { key in
                    KeyCapView(key: key)
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            // Description
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(shortcut.description)
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.textPrimary)

                if let note = shortcut.note {
                    Text(note)
                        .font(DSTypography.caption)
                        .foregroundColor(DSColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(isHovered ? DSColors.hoverBackground : DSColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(DSColors.borderSubtle, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(DSAnimation.easeOut) {
                isHovered = hovering
            }
        }
    }
}

struct KeyCapView: View {
    let key: String

    private var displayKey: String {
        switch key.lowercased() {
        case "cmd", "command": return "\u{2318}"
        case "option", "alt": return "\u{2325}"
        case "shift": return "\u{21E7}"
        case "control", "ctrl": return "\u{2303}"
        case "return", "enter": return "\u{23CE}"
        case "delete", "backspace": return "\u{232B}"
        case "escape", "esc": return "\u{238B}"
        case "tab": return "\u{21E5}"
        case "up": return "\u{2191}"
        case "down": return "\u{2193}"
        case "left": return "\u{2190}"
        case "right": return "\u{2192}"
        default: return key
        }
    }

    var body: some View {
        Text(displayKey)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(DSColors.textPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.xs)
                    .fill(DSColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.xs)
                    .stroke(DSColors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct ShortcutItem {
    let keys: [String]
    let description: String
    let note: String?
}


struct ShortcutsGuideView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutsGuideView()
    }
}
