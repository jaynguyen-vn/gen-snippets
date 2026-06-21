import SwiftUI
import Combine
import UniformTypeIdentifiers

struct AddSnippetSheet: View {
    @ObservedObject var snippetsViewModel: LocalSnippetsViewModel
    let categoryId: String?
    @Environment(\.presentationMode) var presentationMode

    @State private var command = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var shouldFocusCommand = true

    // Inline rich-text document (text + inline images) + secondary file/link attachments.
    @State private var attributedText = NSAttributedString(string: "")
    @State private var extraItems: [RichContentItem] = []
    @State private var pendingSnippetId = UUID().uuidString
    private let inlineController = InlineRichTextController()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Snippet")
                    .font(DSTypography.displaySmall)
                    .foregroundColor(DSColors.textPrimary)

                Spacer()

                DSCloseButton {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)

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

                        FocusableTextField(
                            "Type the trigger text...",
                            text: $command,
                            shouldFocus: $shouldFocusCommand
                        )
                        .font(DSTypography.code)
                        .onChange(of: command) { _ in
                            errorMessage = ""
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

                            ContentHelpButton()
                        }

                        InlineRichTextField(
                            attributedText: $attributedText,
                            controller: inlineController,
                            onAddFile: {
                                extraItems.append(contentsOf: RichContentService.shared.pickFiles(for: pendingSnippetId))
                                errorMessage = ""
                            },
                            onChange: { errorMessage = "" }
                        )

                        SnippetFileAttachments(
                            items: $extraItems,
                            onChange: { errorMessage = "" }
                        )
                    }

                    // Description Field
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Description (Optional)")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        TextField("Add a description...", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(DSTypography.body)
                    }

                    if !errorMessage.isEmpty {
                        HStack(spacing: DSSpacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: DSIconSize.sm))
                            Text(errorMessage)
                                .font(DSTypography.caption)
                        }
                        .foregroundColor(DSColors.error)
                        .padding(DSSpacing.sm)
                        .background(DSColors.errorBackground)
                        .cornerRadius(DSRadius.sm)
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.lg)
            }

            // Action Buttons
            HStack(spacing: DSSpacing.md) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .focusable(false)
                .keyboardShortcut(.escape)
                .disabled(isCreating)

                Spacer()

                Button(action: {
                    createSnippet()
                }) {
                    HStack(spacing: DSSpacing.sm) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(isCreating ? "Adding..." : "Add Snippet")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
                .disabled(command.isEmpty || !isContentValid || isCreating)
                .opacity((command.isEmpty || !isContentValid || isCreating) ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 560, height: 680)
        .background(DSColors.windowBackground)
    }

    // MARK: - Validation

    /// Valid when the inline document has text or an image, or any file/link attachment exists.
    private var isContentValid: Bool {
        if !attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if RichContentService.shared.containsAttachment(attributedText) { return true }
        return !extraItems.isEmpty
    }

    // MARK: - Create Snippet
    private func createSnippet() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCommand.isEmpty {
            errorMessage = "Command cannot be empty"
            return
        }

        let stored = RichContentService.shared.makeStoredItems(
            attributed: attributedText,
            extraItems: extraItems,
            snippetId: pendingSnippetId
        )

        if stored.content.isEmpty && stored.items == nil {
            errorMessage = "Content cannot be empty"
            return
        }

        isCreating = true
        errorMessage = ""

        snippetsViewModel.createSnippet(
            command: trimmedCommand,
            content: stored.content,
            description: description.isEmpty ? nil : description,
            categoryId: categoryId,
            contentType: stored.contentType,
            richContentItems: stored.items,
            snippetId: pendingSnippetId
        )

        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - FocusableTextField for macOS 11.5 compatibility
struct FocusableTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var shouldFocus: Bool

    init(_ placeholder: String, text: Binding<String>, shouldFocus: Binding<Bool>) {
        self.placeholder = placeholder
        self._text = text
        self._shouldFocus = shouldFocus
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        if shouldFocus {
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                shouldFocus = false
            }
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text

        if shouldFocus {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                shouldFocus = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}
