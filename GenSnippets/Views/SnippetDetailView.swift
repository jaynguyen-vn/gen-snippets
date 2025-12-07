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

    // Rich content editing states (multi-file)
    @State private var selectedContentType: RichContentType
    @State private var richContentItems: [RichContentItem]
    @State private var urlString: String

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

        // Initialize rich content states (multi-file)
        self._selectedContentType = State(initialValue: snippet.actualContentType)
        self._richContentItems = State(initialValue: snippet.allRichContentItems)

        // For URL, extract from items or legacy data
        if snippet.actualContentType == .url {
            let urlData = snippet.allRichContentItems.first?.data ?? snippet.richContentData ?? snippet.content
            self._urlString = State(initialValue: urlData)
        } else {
            self._urlString = State(initialValue: "")
        }
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

                            // Content Type Badge (for non-plainText)
                            if snippet.actualContentType != .plainText {
                                HStack(spacing: DSSpacing.xxs) {
                                    Image(systemName: snippet.actualContentType.systemImage)
                                        .font(.system(size: DSIconSize.xs))
                                    Text(snippet.actualContentType.displayName)
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

                    // Content Type Picker
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Content Type")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        HStack(spacing: DSSpacing.sm) {
                            ForEach(RichContentType.allCases, id: \.self) { type in
                                ContentTypeButton(
                                    type: type,
                                    isSelected: selectedContentType == type
                                ) {
                                    if selectedContentType != type {
                                        selectedContentType = type
                                        hasChanges = true
                                        // Reset editing states when changing type
                                        richContentItems = []
                                    }
                                }
                            }
                        }
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

                            // Only show for plain text
                            if selectedContentType == .plainText {
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
                        }

                        // Content view based on selected type
                        switch selectedContentType {
                        case .plainText:
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

                        case .image:
                            richContentImageView

                        case .url:
                            editableURLView

                        case .file:
                            editableFileView
                        }
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

        // Handle rich content based on selected type
        var finalContent = content
        var finalItems: [RichContentItem]? = nil
        let finalContentType: RichContentType? = selectedContentType == .plainText ? nil : selectedContentType

        switch selectedContentType {
        case .plainText:
            finalContent = content

        case .image:
            if !richContentItems.isEmpty {
                finalItems = richContentItems
                let count = richContentItems.count
                finalContent = count == 1 ? "[Image]" : "[\(count) Images]"
            }

        case .url:
            finalItems = [RichContentService.shared.createURLItem(urlString: urlString)]
            finalContent = urlString

        case .file:
            if !richContentItems.isEmpty {
                finalItems = richContentItems
                let count = richContentItems.count
                if count == 1, let name = richContentItems.first?.fileName {
                    finalContent = "[File: \(name)]"
                } else {
                    finalContent = "[\(count) Files]"
                }
            }
        }

        snippetsViewModel.updateSnippet(
            snippet.id,
            command: command,
            content: finalContent,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId,
            contentType: finalContentType,
            richContentItems: finalItems
        )

        let updatedSnippet = Snippet(
            _id: snippet.id,
            command: command,
            content: finalContent,
            description: description.isEmpty ? nil : description,
            categoryId: snippet.categoryId,
            userId: snippet.userId,
            isDeleted: snippet.isDeleted,
            createdAt: snippet.createdAt,
            updatedAt: Date().description,
            contentType: finalContentType,
            richContentItems: finalItems
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

    // MARK: - Rich Content Views (Multi-file)
    @State private var hasImageInClipboard = false

    @ViewBuilder
    private var richContentImageView: some View {
        VStack(spacing: DSSpacing.md) {
            // Show existing images
            if !richContentItems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: DSSpacing.md) {
                    ForEach(Array(richContentItems.enumerated()), id: \.element.id) { index, item in
                        if let image = RichContentService.shared.loadImage(from: item.data) {
                            VStack(spacing: 0) {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 80)
                                        .clipped()
                                        .cornerRadius(DSRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                                .stroke(DSColors.border, lineWidth: 1)
                                        )

                                    Button(action: {
                                        print("[SnippetDetailView] Removing item at index \(index): \(item.id)")
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            if index < richContentItems.count {
                                                richContentItems.remove(at: index)
                                                hasChanges = true
                                            }
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 22, height: 22)
                                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .contentShape(Circle())
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(4)
                                }
                                .frame(width: 108, height: 88)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            // Add more buttons
            HStack(spacing: DSSpacing.md) {
                Button(action: { pasteImageFromClipboard() }) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(DSButtonStyle(hasImageInClipboard ? .primary : .secondary, size: .small))

                Button(action: { selectImageFromFile() }) {
                    Label("Add Image", systemImage: "photo.badge.plus")
                }
                .buttonStyle(DSButtonStyle(.secondary, size: .small))

                if !richContentItems.isEmpty {
                    Button(action: {
                        richContentItems.removeAll()
                        hasChanges = true
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(.destructive, size: .small))
                }
            }

            if richContentItems.isEmpty {
                // Empty state - clickable to paste
                Button(action: { pasteImageFromClipboard() }) {
                    VStack(spacing: DSSpacing.sm) {
                        Image(systemName: hasImageInClipboard ? "doc.on.clipboard.fill" : "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                            .foregroundColor(hasImageInClipboard ? DSColors.accent : DSColors.textTertiary)
                        Text(hasImageInClipboard ? "Click to paste from clipboard" : "No images - paste or add from file")
                            .font(DSTypography.body)
                            .foregroundColor(hasImageInClipboard ? DSColors.accent : DSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(hasImageInClipboard ? DSColors.accent.opacity(0.1) : DSColors.textBackground)
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(hasImageInClipboard ? DSColors.accent : DSColors.border, lineWidth: hasImageInClipboard ? 2 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("\(richContentItems.count) image(s) - All images will be pasted when triggered")
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
        .onAppear { startClipboardMonitoring() }
        .onDisappear { stopClipboardMonitoring() }
    }

    @State private var clipboardTimer: Timer?

    private func startClipboardMonitoring() {
        checkClipboardForImage()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                checkClipboardForImage()
            }
        }
    }

    private func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private func removeItem(_ item: RichContentItem) {
        richContentItems.removeAll { $0.id == item.id }
        hasChanges = true
    }

    private func checkClipboardForImage() {
        let pasteboard = NSPasteboard.general
        // Check for various image types including screenshots
        let hasImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
        let hasTIFF = pasteboard.data(forType: .tiff) != nil
        let hasPNG = pasteboard.data(forType: .png) != nil
        let hasFileURL = pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]])

        hasImageInClipboard = hasImage || hasTIFF || hasPNG || hasFileURL
    }

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general
        var pastedImage: NSImage? = nil

        // Method 1: Direct NSImage read
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            pastedImage = image
        }

        // Method 2: Try PNG data (screenshots often use this)
        if pastedImage == nil, let pngData = pasteboard.data(forType: .png) {
            pastedImage = NSImage(data: pngData)
        }

        // Method 3: Try TIFF data
        if pastedImage == nil, let tiffData = pasteboard.data(forType: .tiff) {
            pastedImage = NSImage(data: tiffData)
        }

        // Method 4: Try file URL (for copied image files)
        if pastedImage == nil,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL],
           let url = urls.first {
            pastedImage = NSImage(contentsOf: url)
        }

        // Process the image
        if let image = pastedImage {
            if let item = RichContentService.shared.createImageItem(from: image, fileName: "Pasted Image") {
                richContentItems.append(item)
                hasChanges = true
            }
        }
    }

    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif, .webP, .heic, .tiff]
        panel.message = "Select image file(s)"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    if let item = RichContentService.shared.createImageItem(from: image, fileName: url.lastPathComponent) {
                        richContentItems.append(item)
                    }
                }
            }
            hasChanges = true
        }
    }

    @ViewBuilder
    private var richContentURLView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "link")
                    .font(.system(size: 24))
                    .foregroundColor(DSColors.accent)

                Text(snippet.richContentData ?? content)
                    .font(DSTypography.code)
                    .foregroundColor(DSColors.accent)
                    .lineLimit(2)

                Spacer()

                if let urlString = snippet.richContentData ?? content.nilIfEmpty,
                   let url = URL(string: urlString) {
                    Button("Open") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(DSButtonStyle(.secondary, size: .small))
                }
            }
            .padding(DSSpacing.md)
            .background(DSColors.textBackground)
            .cornerRadius(DSRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(DSColors.border, lineWidth: 1)
            )

            Text("This URL will be pasted as a link when the command is triggered")
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
    }

    @ViewBuilder
    private var richContentFileView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DSColors.accent)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    if let path = snippet.richContentData {
                        let url = URL(fileURLWithPath: path)
                        Text(url.lastPathComponent)
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textPrimary)
                        Text(url.deletingLastPathComponent().path)
                            .font(DSTypography.caption)
                            .foregroundColor(DSColors.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text("File not available")
                            .font(DSTypography.body)
                            .foregroundColor(DSColors.textTertiary)
                    }
                }

                Spacer()

                if let path = snippet.richContentData {
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(DSButtonStyle(.secondary, size: .small))
                }
            }
            .padding(DSSpacing.md)
            .background(DSColors.textBackground)
            .cornerRadius(DSRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(DSColors.border, lineWidth: 1)
            )

            Text("This file will be pasted when the command is triggered")
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
    }

    // MARK: - Editable Rich Content Views

    @ViewBuilder
    private var editableURLView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundColor(DSColors.accent)

                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(DSTypography.code)
                    .onChange(of: urlString) { _ in
                        hasChanges = true
                    }

                if let url = URL(string: urlString), !urlString.isEmpty {
                    Button("Open") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(DSButtonStyle(.secondary, size: .small))
                }
            }

            Text("Enter a URL to paste as a clickable link")
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
    }

    @ViewBuilder
    private var editableFileView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Show existing files
            if !richContentItems.isEmpty {
                VStack(spacing: DSSpacing.xs) {
                    ForEach(richContentItems) { item in
                        HStack(spacing: DSSpacing.md) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DSColors.accent)

                            Text(item.fileName ?? "File")
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Button(action: { removeItem(item) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DSColors.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(DSSpacing.sm)
                        .background(DSColors.textBackground)
                        .cornerRadius(DSRadius.xs)
                    }
                }
                .frame(maxHeight: 150)
            }

            // Add more buttons
            HStack(spacing: DSSpacing.md) {
                Button(action: { selectNewFile() }) {
                    Label("Add File(s)", systemImage: "doc.badge.plus")
                }
                .buttonStyle(DSButtonStyle(.secondary, size: .small))

                if !richContentItems.isEmpty {
                    Button(action: {
                        richContentItems.removeAll()
                        hasChanges = true
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(.destructive, size: .small))
                }
            }

            if richContentItems.isEmpty {
                Button(action: { selectNewFile() }) {
                    VStack(spacing: DSSpacing.sm) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(DSColors.accent)
                        Text("Click to select file(s)")
                            .font(DSTypography.body)
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(DSColors.textBackground)
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(DSColors.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("\(richContentItems.count) file(s) - All files will be pasted when triggered")
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textTertiary)
        }
    }

    private func selectNewFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select file(s)"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            let snippetId = snippet.id
            for url in panel.urls {
                if let item = RichContentService.shared.createFileItem(from: url, for: snippetId) {
                    richContentItems.append(item)
                }
            }
            hasChanges = true
        }
    }
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