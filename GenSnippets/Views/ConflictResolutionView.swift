import SwiftUI

struct SnippetConflictResolutionView: View {
    let conflict: SnippetConflictInfo
    let currentIndex: Int
    let totalConflicts: Int
    let onResolve: (ConflictResolution) -> Void
    let onCancel: (() -> Void)?

    @State private var customCommand: String = ""

    init(conflict: SnippetConflictInfo, currentIndex: Int, totalConflicts: Int, onResolve: @escaping (ConflictResolution) -> Void, onCancel: (() -> Void)? = nil) {
        self.conflict = conflict
        self.currentIndex = currentIndex
        self.totalConflicts = totalConflicts
        self.onResolve = onResolve
        self.onCancel = onCancel
        self._customCommand = State(initialValue: conflict.suggestedRename)
    }

    private var progress: Double {
        guard totalConflicts > 0 else { return 0 }
        return Double(currentIndex) / Double(totalConflicts)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Resolve Conflict")
                        .font(DSTypography.displaySmall)
                        .foregroundColor(DSColors.textPrimary)

                    Text("Conflict \(currentIndex + 1) of \(totalConflicts)")
                        .font(DSTypography.bodySmall)
                        .foregroundColor(DSColors.textSecondary)
                }

                Spacer()

                if let onCancel = onCancel {
                    DSCloseButton {
                        onCancel()
                    }
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DSColors.borderSubtle)
                        .frame(height: 3)

                    Rectangle()
                        .fill(DSColors.accent)
                        .frame(width: geometry.size.width * progress, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, DSSpacing.lg)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Conflict info
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: DSIconSize.sm))
                            .foregroundColor(DSColors.warning)

                        Text("Command \"\(conflict.command)\" already exists")
                            .font(DSTypography.body)
                            .foregroundColor(DSColors.textPrimary)
                    }
                    .padding(DSSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSColors.warningBackground)
                    .cornerRadius(DSRadius.sm)

                    // Side by side comparison
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        // Existing snippet
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            HStack {
                                Text("EXISTING")
                                    .font(DSTypography.captionMedium)
                                    .foregroundColor(DSColors.textTertiary)

                                Spacer()

                                Text("Will be replaced")
                                    .font(DSTypography.caption)
                                    .foregroundColor(DSColors.error)
                                    .opacity(0.8)
                            }

                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                Text(conflict.existingSnippet.command)
                                    .font(DSTypography.code)
                                    .foregroundColor(DSColors.accent)

                                Text(conflict.existingSnippet.content)
                                    .font(DSTypography.bodySmall)
                                    .foregroundColor(DSColors.textSecondary)
                                    .lineLimit(4)
                            }
                            .padding(DSSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DSColors.textBackground)
                            .cornerRadius(DSRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm)
                                    .stroke(DSColors.borderSubtle, lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Incoming snippet
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            HStack {
                                Text("INCOMING")
                                    .font(DSTypography.captionMedium)
                                    .foregroundColor(DSColors.textTertiary)

                                Spacer()

                                Text("New")
                                    .font(DSTypography.caption)
                                    .foregroundColor(DSColors.success)
                            }

                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                Text(conflict.incomingSnippet.command)
                                    .font(DSTypography.code)
                                    .foregroundColor(DSColors.accent)

                                Text(conflict.incomingSnippet.content)
                                    .font(DSTypography.bodySmall)
                                    .foregroundColor(DSColors.textSecondary)
                                    .lineLimit(4)
                            }
                            .padding(DSSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DSColors.textBackground)
                            .cornerRadius(DSRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm)
                                    .stroke(DSColors.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Rename option
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Or import with a new command:")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        HStack(spacing: DSSpacing.sm) {
                            TextField("New command", text: $customCommand)
                                .font(DSTypography.code)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.sm)
                                .background(DSColors.textBackground)
                                .cornerRadius(DSRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSRadius.sm)
                                        .stroke(DSColors.borderSubtle, lineWidth: 1)
                                )

                            Button("Import as New") {
                                onResolve(.rename(newCommand: customCommand))
                            }
                            .buttonStyle(DSButtonStyle(.tertiary, size: .small))
                            .disabled(customCommand.isEmpty || customCommand == conflict.command)
                        }
                    }

                    // Keyboard shortcuts hint
                    HStack(spacing: DSSpacing.lg) {
                        KeyboardShortcutHint(key: "S", action: "Skip")
                        KeyboardShortcutHint(key: "O", action: "Overwrite")
                        KeyboardShortcutHint(key: "Return", action: "Import as New")
                    }
                    .padding(.top, DSSpacing.xs)
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.lg)
            }

            // Footer with action buttons
            HStack(spacing: DSSpacing.md) {
                Button("Skip") {
                    onResolve(.skip)
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .keyboardShortcut("s", modifiers: [])

                Spacer()

                Button("Overwrite Existing") {
                    onResolve(.overwrite)
                }
                .buttonStyle(DSButtonStyle(.destructive))
                .keyboardShortcut("o", modifiers: [])
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 520, height: 520)
        .background(DSColors.windowBackground)
    }
}

// MARK: - Keyboard Shortcut Hint

private struct KeyboardShortcutHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            Text(key)
                .font(DSTypography.captionMedium)
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, DSSpacing.xxxs)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.xs)
                        .fill(DSColors.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.xs)
                        .stroke(DSColors.borderSubtle, lineWidth: 0.5)
                )

            Text(action)
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SnippetConflictResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        let existingSnippet = Snippet(
            _id: "1",
            command: "/sig",
            content: "Best regards,\nJohn Doe",
            description: "Email signature",
            categoryId: nil,
            userId: nil,
            isDeleted: false,
            createdAt: nil,
            updatedAt: nil
        )

        let incomingSnippet = ShareSnippet(
            command: "/sig",
            content: "Kind regards,\nJane Smith",
            description: "New signature",
            categoryName: "Work"
        )

        let conflict = SnippetConflictInfo(
            command: "/sig",
            existingSnippet: existingSnippet,
            incomingSnippet: incomingSnippet,
            suggestedRename: "/sig (copy)"
        )

        SnippetConflictResolutionView(
            conflict: conflict,
            currentIndex: 1,
            totalConflicts: 3,
            onResolve: { _ in },
            onCancel: { }
        )
    }
}
#endif
