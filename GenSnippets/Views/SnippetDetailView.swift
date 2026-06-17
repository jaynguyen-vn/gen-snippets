import SwiftUI
import Combine
import UniformTypeIdentifiers

struct SnippetDetailView: View {
    let snippet: Snippet
    let snippetsViewModel: LocalSnippetsViewModel
    let categoryName: String?
    var onUpdate: (Snippet) -> Void
    var onDelete: () -> Void

    @State private var command: String
    @State private var description: String
    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false
    @State private var showDeleteAlert: Bool = false
    @StateObject private var toastManager = ToastManager.shared
    @State private var currentToast: Toast?
    @StateObject private var usageTracker = UsageTracker.shared
    @State private var focusedField: FocusedField = .none

    // Inline rich-text document (text + inline images) + secondary file/link attachments.
    @State private var attributedText: NSAttributedString
    @State private var extraItems: [RichContentItem]
    // Set true on any editor/attachment edit so command/description checks can't reset it.
    @State private var contentDirty = false
    private let inlineController = InlineRichTextController()

    enum FocusedField {
        case none
        case command
        case content
        case description
    }

    init(snippet: Snippet, snippetsViewModel: LocalSnippetsViewModel, categoryName: String? = nil, onUpdate: @escaping (Snippet) -> Void, onDelete: @escaping () -> Void) {
        self.snippet = snippet
        self.snippetsViewModel = snippetsViewModel
        self.categoryName = categoryName
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        self._command = State(initialValue: snippet.command)
        self._description = State(initialValue: snippet.description ?? "")

        // Load any snippet kind (plainText / legacy single / block / inlineRichText) into the editor.
        let comps = RichContentService.shared.inlineComponents(for: snippet)
        self._attributedText = State(initialValue: comps.attributed)
        self._extraItems = State(initialValue: comps.extras)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text("Edit Snippet")
                            .font(DSTypography.displaySmall)
                            .foregroundColor(DSColors.textPrimary)

                        HStack(spacing: DSSpacing.md) {
                            if let categoryName = categoryName {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: "folder")
                                        .font(.system(size: DSIconSize.xs))
                                    Text(categoryName)
                                        .font(DSTypography.caption)
                                }
                                .foregroundColor(DSColors.textSecondary)
                            }

                            // Usage Statistics
                            if let usage = usageTracker.getUsage(for: snippet.id), usage.usageCount > 0 {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: DSIconSize.xs))
                                    Text("Used \(usage.usageCount) time\(usage.usageCount > 1 ? "s" : "")")
                                        .font(DSTypography.caption)
                                }
                                .foregroundColor(DSColors.info.opacity(0.9))

                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: "clock")
                                        .font(.system(size: DSIconSize.xs))
                                    Text(usage.formattedLastUsed)
                                        .font(DSTypography.caption)
                                }
                                .foregroundColor(DSColors.textSecondary)
                            } else {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: "chart.bar")
                                        .font(.system(size: DSIconSize.xs))
                                    Text("Not used yet")
                                        .font(DSTypography.caption)
                                }
                                .foregroundColor(DSColors.textTertiary)
                            }

                            // Content Type Badge
                            if snippet.hasRichContent {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: badgeIcon)
                                        .font(.system(size: DSIconSize.xs))
                                    Text(badgeLabel)
                                        .font(DSTypography.caption)
                                }
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xxs)
                                .background(DSColors.accent.opacity(0.15))
                                .foregroundColor(DSColors.accent)
                                .cornerRadius(DSRadius.xs)
                            }
                        }
                    }

                    Spacer()

                    // Responsive Action Buttons
                    if geometry.size.width > 500 {
                        HStack(spacing: DSSpacing.md) {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(DSButtonStyle(.destructive, size: .medium))

                            Button(action: {
                                saveSnippet()
                            }) {
                                HStack(spacing: DSSpacing.xs) {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                            .frame(width: 14, height: 14)
                                    }
                                    Text(isSaving ? "Saving..." : "Save")
                                }
                                .frame(minWidth: 80)
                            }
                            .buttonStyle(DSButtonStyle(.primary, size: .medium))
                            .disabled(!hasChanges || isSaving || command.isEmpty || !isContentValid)
                            .opacity((!hasChanges || isSaving || command.isEmpty || !isContentValid) ? 0.6 : 1)
                            .keyboardShortcut("s", modifiers: .command)
                            .help("Save changes")
                        }
                    } else {
                        HStack(spacing: DSSpacing.sm) {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: DSIconSize.sm))
                            }
                            .buttonStyle(DSButtonStyle(.destructive, size: .small))
                            .help("Delete Snippet")

                            Button(action: {
                                saveSnippet()
                            }) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Text("Save")
                                }
                            }
                            .buttonStyle(DSButtonStyle(.primary, size: .small))
                            .disabled(!hasChanges || isSaving || command.isEmpty || !isContentValid)
                            .opacity((!hasChanges || isSaving || command.isEmpty || !isContentValid) ? 0.6 : 1)
                            .keyboardShortcut("s", modifiers: .command)
                            .help("Save changes")
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.top, DSSpacing.xl)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)

            // Form Fields
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    // Command Field
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Text("Command")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textSecondary)

                            Text("*")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.error)
                        }

                        HStack {
                            CustomTextField(
                                placeholder: "Type the trigger text...",
                                text: $command,
                                identifier: "commandField",
                                onFocus: { focusedField = .command }
                            )
                            .font(DSTypography.code)
                            .onChange(of: command) { _ in
                                checkForChanges()
                            }

                            if !command.isEmpty {
                                Button(action: {
                                    command = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: DSIconSize.sm))
                                        .foregroundColor(DSColors.textTertiary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        Text("This text will trigger the snippet replacement")
                            .font(DSTypography.caption)
                            .foregroundColor(DSColors.textTertiary)
                    }

                    // Content: inline rich-text document + optional file/link attachments
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Text("Content")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textSecondary)

                            Text("*")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.error)
                        }

                        InlineRichTextField(
                            attributedText: $attributedText,
                            controller: inlineController,
                            onAddFile: {
                                let picked = RichContentService.shared.pickFiles(for: snippet.id)
                                if !picked.isEmpty {
                                    extraItems.append(contentsOf: picked)
                                    contentDirty = true
                                    checkForChanges()
                                }
                            },
                            onChange: {
                                contentDirty = true
                                checkForChanges()
                            },
                            height: 220
                        )

                        SnippetFileAttachments(
                            items: $extraItems,
                            onChange: {
                                contentDirty = true
                                checkForChanges()
                            }
                        )

                        Text("Type text and paste images inline. {time}, {uuid}, {clipboard}, {dd/mm/yyyy} resolve on paste. Files paste after the document. ({cursor} and {{field}} only apply to text-only snippets.)")
                            .font(DSTypography.caption)
                            .foregroundColor(DSColors.textTertiary)
                    }

                    // Description Field
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Description (Optional)")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        CustomTextField(
                            placeholder: "Add a description...",
                            text: $description,
                            identifier: "descriptionField",
                            onFocus: { focusedField = .description }
                        )
                        .onChange(of: description) { _ in
                            checkForChanges()
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
            }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toast($currentToast)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Snippet"),
                    message: Text("Are you sure you want to delete this snippet? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteSnippet()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: - Badge

    private var badgeLabel: String {
        if snippet.isInlineRichText { return "Rich Text" }
        if snippet.isMixedContent { return "Mixed" }
        return snippet.actualContentType.displayName
    }

    private var badgeIcon: String {
        if snippet.isInlineRichText { return "doc.richtext" }
        if snippet.isMixedContent { return "square.stack.3d.up" }
        return snippet.actualContentType.systemImage
    }

    // MARK: - Validation

    private var isContentValid: Bool {
        if !attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if RichContentService.shared.containsAttachment(attributedText) { return true }
        return !extraItems.isEmpty
    }

    private func checkForChanges() {
        hasChanges = contentDirty ||
                    command != snippet.command ||
                    description != (snippet.description ?? "")
    }

    private func saveSnippet() {
        isSaving = true

        let stored = RichContentService.shared.makeStoredItems(
            attributed: attributedText,
            extraItems: extraItems,
            snippetId: snippet.id
        )

        snippetsViewModel.updateSnippet(
            snippet.id,
            command: command,
            content: stored.content,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId,
            contentType: stored.contentType,
            richContentItems: stored.items
        )

        let updatedSnippet = Snippet(
            _id: snippet.id,
            command: command,
            content: stored.content,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId,
            userId: snippet.userId,
            isDeleted: snippet.isDeleted,
            createdAt: snippet.createdAt,
            updatedAt: Date().description,
            contentType: stored.contentType,
            richContentItems: stored.items
        )

        onUpdate(updatedSnippet)

        // Reclaim superseded rich files (old inline RTFD blob, images now embedded in the new
        // RTFD, or removed attachments) while keeping everything still referenced. Always include
        // the live file attachments so an RTFD-serialization fallback (items == nil) can never
        // delete a file the user still has attached.
        var referenced = Set((stored.items ?? []).map { $0.data })
        referenced.formUnion(extraItems.map { $0.data })
        RichContentService.shared.deleteUnreferencedFiles(for: snippet.id, keeping: referenced)

        hasChanges = false
        contentDirty = false
        isSaving = false

        currentToast = Toast(type: .success, message: "Snippet saved successfully", duration: 2.0)
    }

    private func deleteSnippet() {
        snippetsViewModel.deleteSnippet(snippet.id)

        currentToast = Toast(type: .success, message: "Snippet deleted successfully", duration: 2.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDelete()
        }
    }

    @State private var cancellables = Set<AnyCancellable>()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Placeholder Item
struct PlaceholderItem: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let description: String
}

struct PlaceholderSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [PlaceholderItem]
}

// MARK: - Placeholder Menu View
struct PlaceholderMenuView: View {
    let sections: [PlaceholderSection]
    let onSelect: (PlaceholderItem) -> Void

    @State private var hoveredId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Insert Placeholder")
                .font(DSTypography.heading2)
                .foregroundColor(DSColors.textPrimary)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.md)

            DSDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ForEach(sections) { section in
                        HStack(spacing: DSSpacing.xs) {
                            Text(section.icon)
                                .font(.system(size: 12))
                            Text(section.title)
                                .font(DSTypography.captionMedium)
                                .foregroundColor(DSColors.textSecondary)
                        }
                        .padding(.horizontal, DSSpacing.lg)
                        .padding(.top, DSSpacing.sm)
                        .padding(.bottom, DSSpacing.xxs)

                        ForEach(section.items) { placeholder in
                            Button(action: {
                                onSelect(placeholder)
                            }) {
                                HStack(spacing: DSSpacing.md) {
                                    Text(placeholder.symbol)
                                        .font(DSTypography.code)
                                        .foregroundColor(DSColors.accent)
                                        .frame(width: 120, alignment: .leading)

                                    VStack(alignment: .leading, spacing: DSSpacing.xxxs) {
                                        Text(placeholder.name)
                                            .font(DSTypography.body)
                                            .foregroundColor(DSColors.textPrimary)

                                        Text(placeholder.description)
                                            .font(DSTypography.caption)
                                            .foregroundColor(DSColors.textSecondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, DSSpacing.lg)
                                .padding(.vertical, DSSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: DSRadius.sm)
                                        .fill(hoveredId == placeholder.id ? DSColors.hoverBackground : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover { isHovering in
                                withAnimation(DSAnimation.easeOut) {
                                    hoveredId = isHovering ? placeholder.id : nil
                                }
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(.horizontal, DSSpacing.xxs)
                    }
                }
                .padding(.vertical, DSSpacing.xxs)
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 420)
        .background(DSColors.controlBackground)
    }
}

// MARK: - Custom TextField for proper cursor position handling
struct CustomTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let identifier: String
    var onFocus: (() -> Void)?

    static var fieldEditors: [String: NSText] = [:]

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.identifier = NSUserInterfaceItemIdentifier(identifier)
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        context.coordinator.textField = textField

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text && nsView.currentEditor() == nil {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        weak var textField: NSTextField?

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocus?()

            if let textField = obj.object as? NSTextField,
               let fieldEditor = textField.currentEditor() {
                CustomTextField.fieldEditors[parent.identifier] = fieldEditor
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            CustomTextField.fieldEditors.removeValue(forKey: parent.identifier)
        }
    }
}
