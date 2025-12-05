import SwiftUI
import Combine

struct AddSnippetSheet: View {
    @ObservedObject var snippetsViewModel: LocalSnippetsViewModel
    let categoryId: String?
    @Environment(\.presentationMode) var presentationMode

    @State private var command = ""
    @State private var content = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var showPlaceholderMenu = false
    @State private var shouldFocusCommand = true

    private let placeholders = [
        PlaceholderItem(symbol: "{cursor}", name: "Cursor Position", description: "Place cursor here after expansion"),
        PlaceholderItem(symbol: "{time}", name: "Current Time", description: "Insert current time"),
        PlaceholderItem(symbol: "{timestamp}", name: "Unix Timestamp", description: "Insert Unix timestamp"),
        PlaceholderItem(symbol: "{dd/mm}", name: "Short Date", description: "Current date (DD/MM)"),
        PlaceholderItem(symbol: "{dd/mm/yyyy}", name: "Full Date", description: "Current date (DD/MM/YYYY)"),
        PlaceholderItem(symbol: "{clipboard}", name: "Clipboard", description: "Paste from clipboard"),
        PlaceholderItem(symbol: "{random-number}", name: "Random Number", description: "Generate random number")
    ]

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

                    // Content Field
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Text("Content")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textSecondary)

                            Text("*")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.error)

                            Spacer()

                            // Character count
                            Text("\(content.count) characters")
                                .font(DSTypography.caption)
                                .foregroundColor(DSColors.textTertiary)

                            // Insert placeholder button
                            Button(action: {
                                showPlaceholderMenu.toggle()
                            }) {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: "curlybraces")
                                        .font(.system(size: DSIconSize.xs, weight: .medium))
                                    Text("Insert placeholder")
                                        .font(DSTypography.captionMedium)
                                }
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xxs)
                                .background(DSColors.accent.opacity(0.12))
                                .foregroundColor(DSColors.accent)
                                .cornerRadius(DSRadius.xs)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Insert Placeholder")
                            .popover(isPresented: $showPlaceholderMenu) {
                                PlaceholderMenuView(placeholders: placeholders) { placeholder in
                                    insertPlaceholder(placeholder.symbol)
                                    showPlaceholderMenu = false
                                }
                            }
                        }

                        TextEditor(text: $content)
                            .font(DSTypography.code)
                            .frame(minHeight: 150)
                            .padding(DSSpacing.sm)
                            .background(DSColors.textBackground)
                            .cornerRadius(DSRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm)
                                    .stroke(DSColors.border, lineWidth: 1)
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
                .disabled(command.isEmpty || content.isEmpty || isCreating)
                .opacity((command.isEmpty || content.isEmpty || isCreating) ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 520, height: 520)
        .background(DSColors.windowBackground)
    }

    private func insertPlaceholder(_ placeholder: String) {
        content += placeholder
    }

    private func createSnippet() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCommand.isEmpty {
            errorMessage = "Command cannot be empty"
            return
        }

        if trimmedContent.isEmpty {
            errorMessage = "Content cannot be empty"
            return
        }

        isCreating = true
        errorMessage = ""

        snippetsViewModel.createSnippet(
            command: trimmedCommand,
            content: trimmedContent,
            description: description.isEmpty ? nil : description,
            categoryId: categoryId
        )

        presentationMode.wrappedValue.dismiss()
    }

    @State private var cancellables = Set<AnyCancellable>()
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
