import Foundation
import AppKit

// MARK: - Metafield Model
struct Metafield: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let defaultValue: String?
    var value: String

    init(key: String, defaultValue: String? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.value = defaultValue ?? ""
    }
}

// MARK: - Metafield Service
class MetafieldService {
    static let shared = MetafieldService()

    private static let metafieldRegex = try? NSRegularExpression(
        pattern: "\\{\\{([^}:]+)(?::([^}]*))?\\}\\}",
        options: []
    )

    private init() {}

    func containsMetafields(_ text: String) -> Bool {
        guard text.contains("{{") && text.contains("}}") else { return false }
        guard let regex = MetafieldService.metafieldRegex else { return false }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    func extractMetafields(_ text: String) -> [Metafield] {
        guard let regex = MetafieldService.metafieldRegex else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)

        var seenKeys = Set<String>()
        var metafields: [Metafield] = []

        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
            let key = String(text[keyRange]).trimmingCharacters(in: .whitespaces)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)

            var defaultValue: String? = nil
            if match.range(at: 2).location != NSNotFound,
               let defaultRange = Range(match.range(at: 2), in: text) {
                defaultValue = String(text[defaultRange])
            }
            metafields.append(Metafield(key: key, defaultValue: defaultValue))
        }
        return metafields
    }

    func replaceMetafields(_ text: String, with values: [String: String]) -> String {
        var result = text
        for (key, value) in values {
            let patterns = [
                "\\{\\{\(NSRegularExpression.escapedPattern(for: key))\\}\\}",
                "\\{\\{\(NSRegularExpression.escapedPattern(for: key)):[^}]*\\}\\}"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: NSRange(location: 0, length: result.utf16.count),
                        withTemplate: value
                    )
                }
            }
        }
        return result
    }
}

// MARK: - Metafield Input Panel
class MetafieldInputPanel: NSPanel, NSTextFieldDelegate {
    private var snippet: Snippet?
    private var metafields: [Metafield] = []
    private var textFields: [String: NSTextField] = [:]
    private var previewTextView: NSTextView!
    private var insertButton: NSButton!
    private var completionHandler: ((String?) -> Void)?
    private var eventMonitor: Any?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        self.title = ""
        self.level = .floating
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false

        // Add local monitor for Shift+Enter
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if event.keyCode == 36 && event.modifierFlags.contains(.shift) {
                // Shift+Enter pressed
                self.insertClicked()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func setup(snippet: Snippet, metafields: [Metafield], completion: @escaping (String?) -> Void) {
        self.snippet = snippet
        self.metafields = metafields
        self.completionHandler = completion
        self.textFields.removeAll()

        setupUI()
        updatePreview()
    }

    private func setupUI() {
        let panelWidth: CGFloat = 500
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 300))

        let padding: CGFloat = 16
        let fieldHeight: CGFloat = 24
        let labelWidth: CGFloat = 100
        let fieldWidth: CGFloat = panelWidth - padding * 2 - labelWidth - 8
        let spacing: CGFloat = 12

        var yOffset: CGFloat = padding

        // Buttons at bottom
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: padding, y: yOffset, width: 80, height: 28)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        insertButton = NSButton(title: "Insert", target: self, action: #selector(insertClicked))
        insertButton.bezelStyle = .rounded
        insertButton.frame = NSRect(x: panelWidth - padding - 80, y: yOffset, width: 80, height: 28)
        insertButton.keyEquivalent = "\r"
        if #available(macOS 11.0, *) {
            insertButton.hasDestructiveAction = false
            insertButton.bezelColor = .systemBlue
        }
        contentView.addSubview(insertButton)

        yOffset += 40

        // Separator
        let separator = NSBox(frame: NSRect(x: padding, y: yOffset, width: panelWidth - padding * 2, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)
        yOffset += 12

        // Preview text view with scroll (BEFORE label, since we build bottom-up)
        // Calculate preview height based on content
        let previewText = snippet?.content ?? ""
        let previewFont = NSFont.systemFont(ofSize: 12)
        let textInset: CGFloat = 6
        let availableWidth = panelWidth - padding * 2 - textInset * 2 - 10 // Account for scroll bar

        // Calculate text height
        let textStorage = NSTextStorage(string: previewText)
        textStorage.addAttribute(.font, value: previewFont, range: NSRange(location: 0, length: textStorage.length))
        let textContainer = NSTextContainer(containerSize: NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height

        // Set preview height with min/max constraints
        let minPreviewHeight: CGFloat = 60
        let maxPreviewHeight: CGFloat = 500
        let calculatedHeight = textHeight + textInset * 2 + 4 // Add padding
        let previewHeight = min(max(calculatedHeight, minPreviewHeight), maxPreviewHeight)

        let scrollView = NSScrollView(frame: NSRect(x: padding, y: yOffset, width: panelWidth - padding * 2, height: previewHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        previewTextView = NSTextView(frame: scrollView.bounds)
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.font = previewFont
        previewTextView.textContainerInset = NSSize(width: textInset, height: textInset)
        previewTextView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.documentView = previewTextView
        contentView.addSubview(scrollView)
        yOffset += previewHeight + 4

        // Preview label (above the box)
        let previewLabel = NSTextField(labelWithString: "Preview:")
        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.frame = NSRect(x: padding, y: yOffset, width: 100, height: 16)
        contentView.addSubview(previewLabel)
        yOffset += 24

        // Separator
        let separator2 = NSBox(frame: NSRect(x: padding, y: yOffset, width: panelWidth - padding * 2, height: 1))
        separator2.boxType = .separator
        contentView.addSubview(separator2)
        yOffset += 16

        // Input fields (reversed order so first field is at top)
        var firstTextField: NSTextField?
        for field in metafields.reversed() {
            let label = NSTextField(labelWithString: field.key + ":")
            label.font = NSFont.systemFont(ofSize: 13)
            label.alignment = .right
            label.frame = NSRect(x: padding, y: yOffset, width: labelWidth, height: fieldHeight)
            contentView.addSubview(label)

            let textField = NSTextField(frame: NSRect(x: padding + labelWidth + 8, y: yOffset, width: fieldWidth, height: fieldHeight))
            textField.stringValue = field.defaultValue ?? ""
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.bezelStyle = .roundedBezel
            textField.delegate = self
            textFields[field.key] = textField
            contentView.addSubview(textField)
            firstTextField = textField

            yOffset += fieldHeight + spacing
        }

        yOffset += 4

        // Adjust window size
        let totalHeight = yOffset
        contentView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: totalHeight)
        self.setContentSize(NSSize(width: panelWidth, height: totalHeight))
        self.contentView = contentView

        // Focus first text field
        if let first = firstTextField {
            self.makeFirstResponder(first)
        }
    }

    private func updatePreview() {
        guard let snippet = snippet else { return }
        var values: [String: String] = [:]
        for (key, field) in textFields {
            // If empty, show placeholder like {{key}}
            let value = field.stringValue
            values[key] = value.isEmpty ? "{{\(key)}}" : value
        }
        let preview = MetafieldService.shared.replaceMetafields(snippet.content, with: values)
        previewTextView.string = preview
    }

    private func getValues() -> [String: String] {
        var values: [String: String] = [:]
        for (key, field) in textFields {
            values[key] = field.stringValue
        }
        return values
    }

    // NSTextFieldDelegate - update preview on text change
    func controlTextDidChange(_ obj: Notification) {
        updatePreview()
    }

    @objc private func insertClicked() {
        guard let snippet = snippet else { return }
        let values = getValues()
        let processedContent = MetafieldService.shared.replaceMetafields(snippet.content, with: values)
        let handler = completionHandler
        completionHandler = nil
        close()
        handler?(processedContent)
    }

    @objc private func cancelClicked() {
        let handler = completionHandler
        completionHandler = nil
        close()
        handler?(nil)
    }

    override func cancelOperation(_ sender: Any?) {
        cancelClicked()
    }
}

// MARK: - Metafield Input Controller
class MetafieldInputController {
    static let shared = MetafieldInputController()

    private var panel: MetafieldInputPanel?
    private var previousApp: NSRunningApplication?

    private init() {}

    func savePreviousApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    func showInputDialog(for snippet: Snippet, completion: @escaping (String?) -> Void) {
        let metafields = MetafieldService.shared.extractMetafields(snippet.content)

        guard !metafields.isEmpty else {
            completion(snippet.content)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create new panel
            let panel = MetafieldInputPanel()
            panel.setup(snippet: snippet, metafields: metafields) { [weak self] result in
                self?.panel = nil
                self?.restorePreviousApp {
                    completion(result)
                }
            }
            self.panel = panel

            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let panelFrame = panel.frame
                let x = screenFrame.midX - panelFrame.width / 2
                let y = screenFrame.midY - panelFrame.height / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            // Show panel
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func restorePreviousApp(completion: @escaping () -> Void) {
        if let app = previousApp {
            previousApp = nil
            app.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                app.activate(options: .activateIgnoringOtherApps)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    completion()
                }
            }
        } else {
            previousApp = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion()
            }
        }
    }
}
