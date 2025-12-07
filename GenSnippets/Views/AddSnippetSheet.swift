import SwiftUI
import Combine
import UniformTypeIdentifiers

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

    // Rich content support (multi-file)
    @State private var selectedContentType: RichContentType = .plainText
    @State private var richContentItems: [RichContentItem] = []
    @State private var urlString = ""
    @State private var hasImageInClipboard = false

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
                                    selectedContentType = type
                                }
                            }
                        }
                    }

                    // Content Field (varies by type)
                    contentInputView

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
                .disabled(command.isEmpty || !isContentValid || isCreating)
                .opacity((command.isEmpty || !isContentValid || isCreating) ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 560, height: 580)
        .background(DSColors.windowBackground)
    }

    // MARK: - Validation
    private var isContentValid: Bool {
        switch selectedContentType {
        case .plainText:
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image, .file:
            return !richContentItems.isEmpty
        case .url:
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && URL(string: trimmed) != nil
        }
    }

    private func insertPlaceholder(_ placeholder: String) {
        content += placeholder
    }

    // MARK: - Content Input View
    @ViewBuilder
    private var contentInputView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text("Content")
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.textSecondary)

                Text("*")
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.error)

                Spacer()

                if selectedContentType == .plainText {
                    Text("\(content.count) characters")
                        .font(DSTypography.caption)
                        .foregroundColor(DSColors.textTertiary)

                    Button(action: { showPlaceholderMenu.toggle() }) {
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
                    .popover(isPresented: $showPlaceholderMenu) {
                        PlaceholderMenuView(sections: placeholderSections) { placeholder in
                            insertPlaceholder(placeholder.symbol)
                            showPlaceholderMenu = false
                        }
                    }
                }
            }

            switch selectedContentType {
            case .plainText:
                TextEditor(text: $content)
                    .font(DSTypography.code)
                    .frame(minHeight: 120)
                    .padding(DSSpacing.sm)
                    .background(DSColors.textBackground)
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(DSColors.border, lineWidth: 1)
                    )

                Text("Use {{field}} or {{field:default}} for dynamic fields that prompt for input")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)

            case .image:
                imageInputView

            case .url:
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(DSTypography.code)

                Text("Enter a URL to paste as a clickable link")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)

            case .file:
                fileInputView
            }
        }
    }

    // MARK: - Image Input View (Multi-file)
    @ViewBuilder
    private var imageInputView: some View {
        VStack(spacing: DSSpacing.md) {
            // Show existing images
            if !richContentItems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: DSSpacing.sm) {
                    ForEach(richContentItems) { item in
                        if let image = RichContentService.shared.loadImage(from: item.data) {
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

                                // Remove button
                                Button(action: { removeItem(item) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.red))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            // Add more buttons
            HStack(spacing: DSSpacing.md) {
                Button(action: { pasteImageFromClipboard() }) {
                    Label(hasImageInClipboard ? "Paste" : "Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(DSButtonStyle(hasImageInClipboard ? .primary : .secondary, size: .small))

                Button(action: { selectImageFromFile() }) {
                    Label("Add Image", systemImage: "photo.badge.plus")
                }
                .buttonStyle(DSButtonStyle(.secondary, size: .small))

                if !richContentItems.isEmpty {
                    Button(action: { richContentItems.removeAll() }) {
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
        }
        .onAppear { startClipboardMonitoring() }
        .onDisappear { stopClipboardMonitoring() }

        Text("\(richContentItems.count) image(s) - All images will be pasted when triggered")
            .font(DSTypography.caption)
            .foregroundColor(DSColors.textTertiary)
    }

    private func removeItem(_ item: RichContentItem) {
        richContentItems.removeAll { $0.id == item.id }
    }

    // MARK: - Clipboard Image Support
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

        // Try multiple methods to get image from clipboard

        // Method 1: Direct NSImage read
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            pastedImage = image
            print("[AddSnippetSheet] Got image via NSImage read")
        }

        // Method 2: Try PNG data (screenshots often use this)
        if pastedImage == nil, let pngData = pasteboard.data(forType: .png) {
            pastedImage = NSImage(data: pngData)
            print("[AddSnippetSheet] Got image via PNG data")
        }

        // Method 3: Try TIFF data
        if pastedImage == nil, let tiffData = pasteboard.data(forType: .tiff) {
            pastedImage = NSImage(data: tiffData)
            print("[AddSnippetSheet] Got image via TIFF data")
        }

        // Method 4: Try file URL (for copied image files)
        if pastedImage == nil,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL],
           let url = urls.first {
            pastedImage = NSImage(contentsOf: url)
            print("[AddSnippetSheet] Got image via file URL: \(url)")
        }

        // Process the image
        if let image = pastedImage {
            if let item = RichContentService.shared.createImageItem(from: image, fileName: "Pasted Image") {
                richContentItems.append(item)
                print("[AddSnippetSheet] Pasted image successfully, total: \(richContentItems.count)")
            } else {
                print("[AddSnippetSheet] Failed to create image item from pasted image")
                errorMessage = "Failed to process pasted image"
            }
        } else {
            // Log what's in the clipboard for debugging
            let types = pasteboard.types ?? []
            print("[AddSnippetSheet] No image found. Clipboard types: \(types)")
            errorMessage = "No image found in clipboard"
        }
    }

    // MARK: - File Selection using NSOpenPanel
    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true // Allow multiple selection
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
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true // Allow multiple selection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select file(s)"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            let snippetId = UUID().uuidString
            for url in panel.urls {
                if let item = RichContentService.shared.createFileItem(from: url, for: snippetId) {
                    richContentItems.append(item)
                }
            }
        }
    }

    // MARK: - File Input View (Multi-file)
    @ViewBuilder
    private var fileInputView: some View {
        VStack(spacing: DSSpacing.md) {
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
                Button(action: { selectFile() }) {
                    Label("Add File(s)", systemImage: "doc.badge.plus")
                }
                .buttonStyle(DSButtonStyle(.secondary, size: .small))

                if !richContentItems.isEmpty {
                    Button(action: { richContentItems.removeAll() }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(.destructive, size: .small))
                }
            }

            if richContentItems.isEmpty {
                // Empty state
                Button(action: { selectFile() }) {
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
        }

        Text("\(richContentItems.count) file(s) - All files will be pasted when triggered")
            .font(DSTypography.caption)
            .foregroundColor(DSColors.textTertiary)
    }

    // MARK: - Create Snippet
    private func createSnippet() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCommand.isEmpty {
            errorMessage = "Command cannot be empty"
            return
        }

        // Validate based on content type
        var finalContent = ""
        var finalItems: [RichContentItem]? = nil

        switch selectedContentType {
        case .plainText:
            finalContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if finalContent.isEmpty {
                errorMessage = "Content cannot be empty"
                return
            }

        case .image:
            if richContentItems.isEmpty {
                errorMessage = "Please add at least one image"
                return
            }
            finalItems = richContentItems
            let count = richContentItems.count
            finalContent = count == 1 ? "[Image]" : "[\(count) Images]"

        case .url:
            let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedURL.isEmpty {
                errorMessage = "URL cannot be empty"
                return
            }
            guard URL(string: trimmedURL) != nil else {
                errorMessage = "Invalid URL format"
                return
            }
            finalItems = [RichContentService.shared.createURLItem(urlString: trimmedURL)]
            finalContent = trimmedURL

        case .file:
            if richContentItems.isEmpty {
                errorMessage = "Please add at least one file"
                return
            }
            finalItems = richContentItems
            let count = richContentItems.count
            if count == 1, let name = richContentItems.first?.fileName {
                finalContent = "[File: \(name)]"
            } else {
                finalContent = "[\(count) Files]"
            }
        }

        isCreating = true
        errorMessage = ""

        snippetsViewModel.createSnippet(
            command: trimmedCommand,
            content: finalContent,
            description: description.isEmpty ? nil : description,
            categoryId: categoryId,
            contentType: selectedContentType == .plainText ? nil : selectedContentType,
            richContentItems: finalItems
        )

        presentationMode.wrappedValue.dismiss()
    }

    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Content Type Button
struct ContentTypeButton: View {
    let type: RichContentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.xxs) {
                Image(systemName: type.systemImage)
                    .font(.system(size: DSIconSize.md))
                Text(type.displayName)
                    .font(DSTypography.caption)
            }
            .frame(width: 70, height: 50)
            .background(isSelected ? DSColors.accent.opacity(0.15) : DSColors.textBackground)
            .foregroundColor(isSelected ? DSColors.accent : DSColors.textSecondary)
            .cornerRadius(DSRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(isSelected ? DSColors.accent : DSColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
