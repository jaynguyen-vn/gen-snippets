import SwiftUI
import Combine

struct SnippetDetailView: View {
    let snippet: Snippet
    let snippetsViewModel: LocalSnippetsViewModel
    let categoryName: String?
    var onUpdate: (Snippet) -> Void
    var onDelete: () -> Void
    
    @State private var command: String
    @State private var content: String
    @State private var description: String
    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showPlaceholderMenu: Bool = false
    @StateObject private var toastManager = ToastManager.shared
    @State private var currentToast: Toast?
    @StateObject private var usageTracker = UsageTracker.shared
    @State private var focusedField: FocusedField = .none
    @State private var savedCursorPosition: NSRange?
    @State private var savedFieldIdentifier: String?
    
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
        
        // Initialize state with snippet values
        self._command = State(initialValue: snippet.command)
        self._content = State(initialValue: snippet.content)
        self._description = State(initialValue: snippet.description ?? "")
    }
    
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
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit Snippet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            if let categoryName = categoryName {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12))
                                    Text(categoryName)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            // Usage Statistics
                            if let usage = usageTracker.getUsage(for: snippet.id), usage.usageCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 12))
                                    Text("Used \(usage.usageCount) time\(usage.usageCount > 1 ? "s" : "")")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text(usage.formattedLastUsed)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar")
                                        .font(.system(size: 12))
                                    Text("Not used yet")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Responsive Action Buttons
                    if geometry.size.width > 500 {
                        // Full layout for wide screens
                        HStack(spacing: 12) {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(ModernButtonStyle(isDestructive: true))
                            
                            Button(action: {
                                saveSnippet()
                            }) {
                                HStack(spacing: 6) {
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
                            .buttonStyle(ModernButtonStyle(isPrimary: true))
                            .disabled(!hasChanges || isSaving || command.isEmpty || content.isEmpty)
                        }
                    } else {
                        // Compact layout for narrow screens
                        HStack(spacing: 8) {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(ModernButtonStyle(isDestructive: true))
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
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(ModernButtonStyle(isPrimary: true))
                            .disabled(!hasChanges || isSaving || command.isEmpty || content.isEmpty)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Form Fields
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Command Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Command")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("*")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            CustomTextField(
                                placeholder: "Type the trigger text...",
                                text: $command,
                                identifier: "commandField",
                                onFocus: { focusedField = .command }
                            )
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: command) { _ in
                                checkForChanges()
                            }
                            
                            if !command.isEmpty {
                                Button(action: {
                                    command = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Text("This text will trigger the snippet replacement")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    // Content Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Content")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("*")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            // Character count
                            Text("\(content.count) characters")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                            
                            // Insert placeholder button
                            Button(action: {
                                saveCursorPosition()
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
                                    insertPlaceholderAtSavedPosition(placeholder.symbol)
                                    showPlaceholderMenu = false
                                }
                            }
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200, maxHeight: 400)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: content) { _ in
                                checkForChanges()
                            }
                            .onTapGesture {
                                focusedField = .content
                            }
                    }
                    
                    // Description Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
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
                .padding(.horizontal, 24)
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
    
    private func checkForChanges() {
        hasChanges = command != snippet.command ||
                    content != snippet.content ||
                    description != (snippet.description ?? "")
    }
    
    private func saveCursorPosition() {
        // Save cursor position before showing the menu
        if let window = NSApp.keyWindow,
           let responder = window.firstResponder {
            
            if let textView = responder as? NSTextView {
                // Content field (TextEditor)
                savedCursorPosition = textView.selectedRange()
                savedFieldIdentifier = "content"
            } else if let fieldEditor = responder as? NSText,
                      let textField = fieldEditor.delegate as? NSTextField {
                // Command or Description field
                savedCursorPosition = fieldEditor.selectedRange
                savedFieldIdentifier = textField.identifier?.rawValue
            }
        }
    }
    
    private func insertPlaceholderAtSavedPosition(_ placeholder: String) {
        // Use saved cursor position if available
        if let savedPosition = savedCursorPosition,
           let fieldId = savedFieldIdentifier {
            
            if fieldId == "content" {
                // Handle content field
                let location = min(savedPosition.location, content.count)
                let length = min(savedPosition.length, content.count - location)
                
                let startIndex = content.index(content.startIndex, offsetBy: location)
                let endIndex = content.index(startIndex, offsetBy: length)
                content = content.replacingCharacters(in: startIndex..<endIndex, with: placeholder)
                
                // Try to restore focus and move cursor
                DispatchQueue.main.async {
                    if let window = NSApp.keyWindow {
                        // Find the TextEditor and make it first responder
                        window.makeFirstResponder(nil)
                        if let textView = window.firstResponder as? NSTextView {
                            let newPosition = location + placeholder.count
                            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
                        }
                    }
                }
            } else if fieldId == "commandField" {
                // Handle command field
                let location = min(savedPosition.location, command.count)
                let length = min(savedPosition.length, command.count - location)
                
                let startIndex = command.index(command.startIndex, offsetBy: location)
                let endIndex = command.index(startIndex, offsetBy: length)
                command = command.replacingCharacters(in: startIndex..<endIndex, with: placeholder)
            } else if fieldId == "descriptionField" {
                // Handle description field
                let location = min(savedPosition.location, description.count)
                let length = min(savedPosition.length, description.count - location)
                
                let startIndex = description.index(description.startIndex, offsetBy: location)
                let endIndex = description.index(startIndex, offsetBy: length)
                description = description.replacingCharacters(in: startIndex..<endIndex, with: placeholder)
            }
            
            // Clear saved position
            savedCursorPosition = nil
            savedFieldIdentifier = nil
        } else {
            // Fallback to original method if no saved position
            insertPlaceholder(placeholder)
        }
    }
    
    private func insertPlaceholder(_ placeholder: String) {
        // First try to handle TextFields using stored field editors
        if focusedField == .command || focusedField == .description {
            let identifier = focusedField == .command ? "commandField" : "descriptionField"
            
            if let fieldEditor = CustomTextField.fieldEditors[identifier] {
                // Get current cursor position
                let selectedRange = fieldEditor.selectedRange
                let currentText = focusedField == .command ? command : description
                
                // Calculate insertion position
                let location = min(selectedRange.location, currentText.count)
                let length = min(selectedRange.length, currentText.count - location)
                
                // Insert placeholder at cursor position
                let startIndex = currentText.index(currentText.startIndex, offsetBy: location)
                let endIndex = currentText.index(startIndex, offsetBy: length)
                let newText = currentText.replacingCharacters(in: startIndex..<endIndex, with: placeholder)
                
                // Update the appropriate field
                if focusedField == .command {
                    command = newText
                } else {
                    description = newText
                }
                
                // Move cursor after inserted placeholder
                DispatchQueue.main.async {
                    let newPosition = location + placeholder.count
                    fieldEditor.selectedRange = NSRange(location: newPosition, length: 0)
                }
                return
            }
        }
        
        // Handle NSTextView (TextEditor for content field)
        if focusedField == .content {
            if let window = NSApp.keyWindow,
               let responder = window.firstResponder as? NSTextView {
                let selectedRange = responder.selectedRange()
                responder.insertText(placeholder, replacementRange: selectedRange)
                return
            }
        }
        
        // Fallback: Try to detect the current responder
        if let window = NSApp.keyWindow,
           let responder = window.firstResponder {
            
            // Handle NSTextView
            if let textView = responder as? NSTextView {
                let selectedRange = textView.selectedRange()
                textView.insertText(placeholder, replacementRange: selectedRange)
                return
            }
            
            // Handle NSText (field editor)
            if let fieldEditor = responder as? NSText {
                let selectedRange = fieldEditor.selectedRange
                let string = fieldEditor.string
                let location = min(selectedRange.location, string.count)
                let length = min(selectedRange.length, string.count - location)
                
                let startIndex = string.index(string.startIndex, offsetBy: location)
                let endIndex = string.index(startIndex, offsetBy: length)
                let newText = string.replacingCharacters(in: startIndex..<endIndex, with: placeholder)
                
                fieldEditor.string = newText
                let newPosition = location + placeholder.count
                fieldEditor.selectedRange = NSRange(location: newPosition, length: 0)
                
                // Update the appropriate binding
                if let textField = fieldEditor.delegate as? NSTextField {
                    if textField.identifier?.rawValue == "commandField" {
                        command = newText
                    } else if textField.identifier?.rawValue == "descriptionField" {
                        description = newText
                    }
                }
                return
            }
        }
        
        // Last fallback: append to the focused field
        switch focusedField {
        case .command:
            command += placeholder
        case .description:
            description += placeholder
        case .content, .none:
            content += placeholder
        }
    }
    
    private func saveSnippet() {
        isSaving = true
        
        snippetsViewModel.updateSnippet(
            snippet.id,
            command: command,
            content: content,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId
        )
        
        let updatedSnippet = Snippet(
            _id: snippet.id,
            command: command,
            content: content,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId,
            userId: snippet.userId,
            isDeleted: snippet.isDeleted,
            createdAt: snippet.createdAt,
            updatedAt: Date().description
        )
        
        onUpdate(updatedSnippet)
        hasChanges = false
        isSaving = false
        
        // Show success toast
        currentToast = Toast(type: .success, message: "Snippet saved successfully", duration: 2.0)
    }
    
    private func deleteSnippet() {
        snippetsViewModel.deleteSnippet(snippet.id)
        
        // Show success toast before closing
        currentToast = Toast(type: .success, message: "Snippet deleted successfully", duration: 2.0)
        
        // Delay the onDelete callback to allow toast to show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDelete()
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Placeholder Item
struct PlaceholderItem: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let description: String
}

// MARK: - Placeholder Menu View
struct PlaceholderMenuView: View {
    let placeholders: [PlaceholderItem]
    let onSelect: (PlaceholderItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Insert Placeholder")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
            
            ForEach(placeholders) { placeholder in
                Button(action: {
                    onSelect(placeholder)
                }) {
                    HStack(spacing: 12) {
                        Text(placeholder.symbol)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 120, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(placeholder.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(placeholder.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.clear)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .frame(width: 400)
        .background(Color(NSColor.controlBackgroundColor))
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
        
        // Store reference for later access
        context.coordinator.textField = textField
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if the text is different and we're not editing
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
            
            // Store the field editor for this identifier
            if let textField = obj.object as? NSTextField,
               let fieldEditor = textField.currentEditor() {
                CustomTextField.fieldEditors[parent.identifier] = fieldEditor
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Remove the field editor reference when editing ends
            CustomTextField.fieldEditors.removeValue(forKey: parent.identifier)
        }
    }
}