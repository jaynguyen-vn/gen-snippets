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
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Snippet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Form Fields
            VStack(alignment: .leading, spacing: 16) {
                // Command Field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Command")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("*")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    FocusableTextField(
                        "Type the trigger text...",
                        text: $command,
                        shouldFocus: $shouldFocusCommand
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: command) { _ in
                        errorMessage = ""
                    }
                }
                
                // Content Field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("*")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        // Character count
                        Text("\(content.count) characters")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                        
                        // Insert placeholder button
                        Button(action: {
                            showPlaceholderMenu.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Insert placeholder")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
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
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Description Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Add a description...", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(isPrimary: false))
                .keyboardShortcut(.escape)
                .disabled(isCreating)
                
                Spacer()
                
                Button(action: {
                    createSnippet()
                }) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Add")
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .keyboardShortcut(.return)
                .disabled(command.isEmpty || content.isEmpty || isCreating)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
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