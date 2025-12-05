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
    
    private let placeholderSections = [
        PlaceholderSection(title: "CURSOR", icon: "I", items: [
            PlaceholderItem(symbol: "{cursor}", name: "Cursor Position", description: "Place cursor here after expansion")
        ]),
        PlaceholderSection(title: "TIME", icon: "", items: [
            PlaceholderItem(symbol: "{time}", name: "Time (HH:mm:ss)", description: "Current time with seconds"),
            PlaceholderItem(symbol: "{time:short}", name: "Time (HH:mm)", description: "Current time without seconds")
        ]),
        PlaceholderSection(title: "DATE", icon: "", items: [
            PlaceholderItem(symbol: "{dd/mm}", name: "Date (DD/MM)", description: "Short date format"),
            PlaceholderItem(symbol: "{dd/mm/yyyy}", name: "Date (DD/MM/YYYY)", description: "Full date format"),
            PlaceholderItem(symbol: "{yyyy-mm-dd}", name: "Date (ISO)", description: "ISO date format"),
            PlaceholderItem(symbol: "{mm/dd/yyyy}", name: "Date (US)", description: "US date format"),
            PlaceholderItem(symbol: "{datetime}", name: "Date & Time", description: "Full date and time"),
            PlaceholderItem(symbol: "{date-iso}", name: "ISO 8601", description: "Full ISO timestamp"),
            PlaceholderItem(symbol: "{weekday}", name: "Weekday", description: "Day name (Monday, Tuesday...)"),
            PlaceholderItem(symbol: "{month}", name: "Month", description: "Month name (January, February...)")
        ]),
        PlaceholderSection(title: "UTILITY", icon: "", items: [
            PlaceholderItem(symbol: "{clipboard}", name: "Clipboard", description: "Paste from clipboard"),
            PlaceholderItem(symbol: "{upper}", name: "Uppercase", description: "Clipboard in UPPERCASE"),
            PlaceholderItem(symbol: "{lower}", name: "Lowercase", description: "Clipboard in lowercase"),
            PlaceholderItem(symbol: "{uuid}", name: "UUID", description: "Unique identifier"),
            PlaceholderItem(symbol: "{timestamp}", name: "Unix Timestamp", description: "Unix timestamp in seconds"),
            PlaceholderItem(symbol: "{random:1-100}", name: "Random Number", description: "Random with custom range (e.g. {random:1-1000})")
        ])
    ]
    
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
                        }
                    }

                    Spacer()

                    // Responsive Action Buttons
                    if geometry.size.width > 500 {
                        // Full layout for wide screens
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
                            .disabled(!hasChanges || isSaving || command.isEmpty || content.isEmpty)
                            .opacity((!hasChanges || isSaving || command.isEmpty || content.isEmpty) ? 0.6 : 1)
                            .keyboardShortcut("s", modifiers: .command)
                            .help("Save changes")
                        }
                    } else {
                        // Compact layout for narrow screens
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
                            .disabled(!hasChanges || isSaving || command.isEmpty || content.isEmpty)
                            .opacity((!hasChanges || isSaving || command.isEmpty || content.isEmpty) ? 0.6 : 1)
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
                                saveCursorPosition()
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
                                PlaceholderMenuView(sections: placeholderSections) { placeholder in
                                    insertPlaceholderAtSavedPosition(placeholder.symbol)
                                    showPlaceholderMenu = false
                                }
                            }
                        }

                        TextEditor(text: $content)
                            .font(DSTypography.code)
                            .frame(minHeight: 200, maxHeight: 400)
                            .padding(DSSpacing.sm)
                            .background(DSColors.textBackground)
                            .cornerRadius(DSRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm)
                                    .stroke(DSColors.border, lineWidth: 1)
                            )
                            .onChange(of: content) { _ in
                                checkForChanges()
                            }
                            .onTapGesture {
                                focusedField = .content
                            }

                        Text("Use {{field}} or {{field:default}} for dynamic fields that prompt for input")
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
                        // Section Header
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

                        // Section Items
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