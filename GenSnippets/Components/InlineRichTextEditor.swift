import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Lets host views insert an image attachment into the editor at the caret (so there's a visible
/// "Add Image" affordance, not only paste/drag). Holds a weak ref to the live NSTextView.
final class InlineRichTextController {
    weak var textView: NSTextView?

    /// Insert an image from the clipboard at the caret. No-op if the clipboard has no image.
    func insertImageFromClipboard() {
        guard let image = InlineRichTextController.imageFromPasteboard() else { return }
        insert(image)
    }

    /// Pick image file(s) and insert them at the caret.
    func insertImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif, .webP, .heic, .tiff]
        panel.message = "Select image file(s)"
        panel.prompt = "Insert"
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) { insert(image) }
            }
        }
    }

    /// Insert literal placeholder text ({time}, {{field}}, …) at the caret. Picks up the editor's
    /// typing attributes (font/color) and fires the delegate so the binding + height update.
    func insertPlaceholder(_ text: String) {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        tv.insertText(text, replacementRange: tv.selectedRange())
    }

    private func insert(_ image: NSImage) {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        // Use a fileWrapper-backed attachment so it survives RTFD serialization (not just on-screen).
        let attributed = RichContentService.shared.attachmentString(for: image)
        // insertText handles undo + fires the delegate's textDidChange (binding update) + advances caret
        tv.insertText(attributed, replacementRange: tv.selectedRange())
    }

    static func imageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return image
        }
        if let pngData = pasteboard.data(forType: .png) { return NSImage(data: pngData) }
        if let tiffData = pasteboard.data(forType: .tiff) { return NSImage(data: tiffData) }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL],
           let url = urls.first {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

/// Preview-only sizing for inline images. A pasted screenshot can be thousands of pixels and would
/// dwarf the text, so the editor renders each image's DISPLAY copy at a scaled-down logical size.
/// The full-resolution bytes live in the attachment's `fileWrapper`, which is what gets serialized
/// and pasted on expansion — so this only softens the in-editor preview.
///
/// It drives layout through the image's own `size`, NOT `attachmentBounds`/`bounds`. That matters on
/// recent macOS: NSTextView defaults to TextKit 2, which ignores a plain attachment's `attachmentBounds`
/// override — but it always honors the image's intrinsic size.
enum InlineImageSizing {
    /// Absolute display ceiling so a wide window can't blow the image up to full editor width.
    static let maxWidth: CGFloat = 360
    static let maxHeight: CGFloat = 200

    /// Scale `native` to fit `maxWidth` (capped by `self.maxWidth`) × `maxHeight`, keeping aspect ratio.
    static func displaySize(native: CGSize, maxWidth: CGFloat) -> CGSize {
        guard native.width > 0, native.height > 0 else { return native }
        let capW = min(maxWidth, self.maxWidth)
        var w = native.width, h = native.height
        if w > capW { h *= capW / w; w = capW }
        if h > maxHeight { w *= maxHeight / h; h = maxHeight }
        return CGSize(width: w.rounded(), height: h.rounded())
    }

    /// PNG-backed fileWrapper for an image, so full-resolution bytes survive (re)serialization.
    private static func makeFileWrapper(for image: NSImage) -> FileWrapper? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let wrapper = FileWrapper(regularFileWithContents: png)
        wrapper.preferredFilename = "\(UUID().uuidString).png"
        return wrapper
    }

    /// Fit each inline image's display copy to `maxWidth`. Guarantees every image attachment carries a
    /// full-res fileWrapper (synthesizing one from a bare image if needed) plus a scaled `image` for
    /// display. Native size is always recomputed from the fileWrapper, so re-runs converge (idempotent)
    /// and a resize can grow the image back. Returns true if storage was mutated.
    @discardableResult
    static func normalize(_ storage: NSTextStorage, maxWidth: CGFloat) -> Bool {
        struct Plan { let range: NSRange; let attachment: NSTextAttachment; let wrapper: FileWrapper; let display: NSImage }
        var plans: [Plan] = []

        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            guard let att = value as? NSTextAttachment else { return }

            // Source of truth for native size: the full-res fileWrapper bytes, else a bare image.
            let wrapper: FileWrapper
            if let w = att.fileWrapper, w.regularFileContents != nil {
                wrapper = w
            } else if let img = att.image, let w = makeFileWrapper(for: img) {
                wrapper = w
            } else {
                return
            }
            guard let data = wrapper.regularFileContents,
                  let nativeImage = NSImage(data: data) else { return }

            let target = displaySize(native: nativeImage.size, maxWidth: maxWidth)
            // Already fileWrapper-backed and already at the target size → nothing to do.
            if att.fileWrapper === wrapper, let cur = att.image?.size,
               abs(cur.width - target.width) < 0.5, abs(cur.height - target.height) < 0.5 {
                return
            }
            nativeImage.size = target
            plans.append(Plan(range: range, attachment: att, wrapper: wrapper, display: nativeImage))
        }

        guard !plans.isEmpty else { return false }
        storage.beginEditing()
        for p in plans {
            p.attachment.fileWrapper = p.wrapper
            p.attachment.image = p.display
            // Re-set the attribute to force TextKit to relayout at the new size.
            storage.removeAttribute(.attachment, range: p.range)
            storage.addAttribute(.attachment, value: p.attachment, range: p.range)
        }
        storage.endEditing()
        return true
    }
}

/// The editor shows its body text larger than it stores it.
///
/// A rich snippet's RTFD keeps every run's font and pastes it into the target app on expansion, so
/// what gets stored must stay the system body size every existing snippet was saved with. Only runs
/// in that exact font — the text the editor itself types — are swapped for a larger copy while on
/// screen. Runs in any other font or size, such as styled text pasted from a browser, are shown and
/// stored exactly as they are, so the swap never changes what an expansion pastes.
enum InlineEditorFont {
    /// Size written to storage.
    static let storedSize = NSFont.systemFontSize
    /// Size the same text is drawn at inside the editor.
    static let displaySize: CGFloat = 16

    static var display: NSFont { .systemFont(ofSize: displaySize) }

    /// Families the editor's own body text can arrive in. RTF has no name for the system UI font and
    /// writes it as Helvetica Neue, so that is what the body text of every saved rich snippet loads
    /// back as.
    private static let bodyFamilies = Set(
        [NSFont.systemFont(ofSize: storedSize).familyName, "Helvetica Neue"].compactMap { $0 }
    )

    /// Storage → screen. A run with no font is treated as body text: left alone, AppKit would draw it
    /// in 12pt Helvetica, so a plain snippet would load smaller than anything the user types into it.
    static func forDisplay(_ stored: NSAttributedString) -> NSAttributedString {
        resize(stored, from: storedSize, to: displaySize, fillingMissing: true)
    }

    /// Screen → storage.
    static func forStorage(_ shown: NSAttributedString) -> NSAttributedString {
        resize(shown, from: displaySize, to: storedSize, fillingMissing: false)
    }

    private static func resize(_ attr: NSAttributedString, from: CGFloat, to: CGFloat, fillingMissing: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attr)
        let full = NSRange(location: 0, length: result.length)

        // Collect first — the same rule storableCopy follows for attachments.
        var changes: [(range: NSRange, font: NSFont)] = []
        result.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            guard let font = value as? NSFont else {
                if fillingMissing { changes.append((range, .systemFont(ofSize: to))) }
                return
            }
            guard let family = font.familyName, bodyFamilies.contains(family), font.pointSize == from else { return }
            // The descriptor carries the run's weight and traits, so bold stays bold.
            changes.append((range, NSFont(descriptor: font.fontDescriptor, size: to) ?? .systemFont(ofSize: to)))
        }
        for change in changes {
            result.addAttribute(.font, value: change.font, range: change.range)
        }
        return result
    }
}

/// Seamless inline rich-text editor (text + inline images in one document), backed by NSTextView.
/// Produces an `NSAttributedString` the host serializes to RTFD. macOS 11.5-safe (no @FocusState /
/// TextKit 2 / 12+ SwiftUI APIs). Image paste & drag-drop become inline `NSTextAttachment`s via
/// `importsGraphics`.
struct InlineRichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var controller: InlineRichTextController? = nil
    /// Reports the laid-out content height so the host can auto-grow the editor to fit its content.
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder   // outer SwiftUI container draws the single border
        scrollView.autohidesScrollers = true
        // Opaque background so the editor doesn't composite over sibling SwiftUI views.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        // Force layer-backing so the hosted AppKit view clips/composites correctly inside a SwiftUI
        // ScrollView (otherwise it leaves "ghost" duplicate renders of sibling content while scrolling).
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        controller?.textView = textView
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true          // keep attributes + attachments
        textView.importsGraphics = true     // paste / drop images as inline attachments
        textView.allowsImageEditing = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.wantsLayer = true
        textView.delegate = context.coordinator
        textView.font = InlineEditorFont.display
        // Adaptive text colors so content follows light/dark like the rest of the UI.
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: InlineEditorFont.display
        ]
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(InlineEditorFont.forDisplay(attributedText))

        context.coordinator.textView = textView
        context.coordinator.lastSynced = attributedText
        // Re-clamp inline images when the editor is resized (column drag / window resize) so an image
        // never overflows a narrower editor.
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.editorFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView)

        context.coordinator.applyAdaptiveTextColor(in: textView)
        context.coordinator.normalizeImages(in: textView)
        context.coordinator.reportHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Keep the coordinator pointed at the current struct (SwiftUI re-creates it per render).
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage else { return }
        controller?.textView = textView
        context.coordinator.textView = textView

        // Don't clobber the user's edits / caret while they're typing. Only push an external
        // change (e.g. initial load, programmatic reset) when the view isn't being edited and
        // the content actually differs. Compared against the last value synced in either direction,
        // not the storage: the storage holds the enlarged display copy, which never equals the binding.
        let coordinator = context.coordinator
        if !coordinator.isEditing, coordinator.lastSynced.map({ !$0.isEqual(to: attributedText) }) ?? true {
            coordinator.lastSynced = attributedText
            let selected = textView.selectedRange()
            storage.setAttributedString(InlineEditorFont.forDisplay(attributedText))
            // Best-effort caret restore within new bounds.
            let loc = min(selected.location, storage.length)
            textView.setSelectedRange(NSRange(location: loc, length: 0))
            context.coordinator.applyAdaptiveTextColor(in: textView)
            context.coordinator.normalizeImages(in: textView)
        }
        context.coordinator.reportHeight(for: textView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineRichTextEditor
        weak var textView: NSTextView?
        var isEditing = false
        /// The binding's value as of the last sync, at storage size.
        var lastSynced: NSAttributedString?
        private var isNormalizing = false
        private var lastReportedHeight: CGFloat = 0
        private var lastWidth: CGFloat = 0

        init(_ parent: InlineRichTextEditor) { self.parent = parent }

        deinit { NotificationCenter.default.removeObserver(self) }

        func textDidBeginEditing(_ notification: Notification) { isEditing = true }
        func textDidEndEditing(_ notification: Notification) { isEditing = false }

        /// Force the loaded text to the adaptive label color. Setting `textView.textColor` before
        /// content doesn't recolor runs added later by `setAttributedString` (uncolored runs fall back
        /// to a static dark color), so apply it across the whole range after load. `labelColor` is a
        /// dynamic color → it tracks the theme; `storableCopy` strips it again before saving.
        func applyAdaptiveTextColor(in textView: NSTextView) {
            guard let storage = textView.textStorage, storage.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor,
                                 range: NSRange(location: 0, length: storage.length))
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            // Newly pasted/dropped images arrive as plain attachments → convert to preview-sized ones.
            normalizeImages(in: textView)
            publish(storage)
            reportHeight(for: textView)
        }

        /// Hand the edited document to the binding at storage size. `forStorage` returns a fresh copy,
        /// so downstream never holds the live storage.
        private func publish(_ storage: NSTextStorage) {
            let stored = InlineEditorFont.forStorage(storage)
            lastSynced = stored
            parent.attributedText = stored
        }

        @objc func editorFrameChanged(_ note: Notification) {
            guard let tv = note.object as? NSTextView else { return }
            // Only react to WIDTH changes. A height-only change (e.g. the manual resize drag) needs no
            // image re-fit or re-measure, and doing that work per drag tick caused visible flicker.
            let width = tv.bounds.width
            guard abs(width - lastWidth) > 0.5 else { return }
            lastWidth = width
            if normalizeImages(in: tv), let storage = tv.textStorage {
                // Persist the image change so updateNSView doesn't restore the old layout.
                publish(storage)
            }
            reportHeight(for: tv)
        }

        /// Fit inline images to the current editor width. Guarded against the re-entrant `textDidChange`
        /// its own storage edit would otherwise trigger. Returns true if storage was mutated.
        @discardableResult
        func normalizeImages(in textView: NSTextView) -> Bool {
            guard !isNormalizing, let storage = textView.textStorage else { return false }
            isNormalizing = true
            defer { isNormalizing = false }
            let inset = textView.textContainerInset.width
            let pad = textView.textContainer?.lineFragmentPadding ?? 0
            let available = textView.bounds.width - 2 * (inset + pad)
            let maxWidth = available > 1 ? available : InlineImageSizing.maxWidth
            return InlineImageSizing.normalize(storage, maxWidth: maxWidth)
        }

        /// Measure the laid-out content height and hand it to the host (debounced on change).
        func reportHeight(for textView: NSTextView) {
            guard let lm = textView.layoutManager, let tc = textView.textContainer else { return }
            lm.ensureLayout(for: tc)
            let total = lm.usedRect(for: tc).height + 2 * textView.textContainerInset.height
            guard abs(total - lastReportedHeight) > 0.5 else { return }
            lastReportedHeight = total
            DispatchQueue.main.async { [weak self] in
                self?.parent.onContentHeightChange?(total)
            }
        }
    }
}

/// Editor "field": an attached toolbar (Add Image / Add File) on top of the inline rich-text area,
/// wrapped in one bordered container (Slack/Notes style). The host owns file storage via `onAddFile`.
struct InlineRichTextField: View {
    @Binding var attributedText: NSAttributedString
    let controller: InlineRichTextController
    let onAddFile: () -> Void
    var onChange: (() -> Void)? = nil
    /// Auto-grows with content between `minHeight` and `autoMaxHeight`; the drag handle can override
    /// up to `manualMaxHeight`.
    var minHeight: CGFloat = 120
    var autoMaxHeight: CGFloat = 360
    var manualMaxHeight: CGFloat = 900

    @State private var contentHeight: CGFloat = 0
    /// User-chosen height set by dragging the resize handle. `nil` = auto-grow with content.
    @State private var manualHeight: CGFloat? = nil
    @State private var isDragging = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var showPlaceholderMenu = false

    /// Drives the editor frame: a manual override if set, otherwise content height clamped to range.
    private var editorHeight: CGFloat {
        if let manual = manualHeight {
            return min(max(manual, minHeight), manualMaxHeight)
        }
        return min(max(contentHeight, minHeight), autoMaxHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DSSpacing.sm) {
                Menu {
                    Button("Paste from Clipboard") { controller.insertImageFromClipboard() }
                    Button("Choose File…") { controller.insertImageFromFile() }
                } label: {
                    InlineEditorChipLabel(title: "Add Image", icon: "photo.badge.plus")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()

                Button(action: onAddFile) {
                    InlineEditorChipLabel(title: "Add File", icon: "doc.badge.plus")
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showPlaceholderMenu.toggle() }) {
                    InlineEditorChipLabel(title: "Insert", icon: "curlybraces")
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showPlaceholderMenu) {
                    PlaceholderMenuView(sections: PlaceholderCatalog.sections) { placeholder in
                        controller.insertPlaceholder(placeholder.symbol)
                        showPlaceholderMenu = false
                        onChange?()
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.surfaceSecondary)

            Divider()

            InlineRichTextEditor(
                attributedText: $attributedText,
                controller: controller,
                onContentHeightChange: { contentHeight = $0 }
            )
            .frame(height: editorHeight)
            // No animation while dragging (it would lag the handle) or once a manual height is set.
            .animation(manualHeight == nil && !isDragging ? DSAnimation.easeOut : nil, value: editorHeight)
            .onChange(of: attributedText) { _ in onChange?() }

            resizeHandle
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .stroke(DSColors.border, lineWidth: 1)
        )
    }

    /// Drag to set a custom editor height; double-click to return to auto-grow.
    private var resizeHandle: some View {
        ZStack {
            Rectangle().fill(DSColors.surfaceSecondary)
            Image(systemName: "equal")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DSColors.textTertiary)
        }
        .frame(height: 14)
        .frame(maxWidth: .infinity)
        .overlay(Divider(), alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            // Global coordinate space: the handle moves as the editor grows, so a local-space
            // translation would feed back on itself and jitter. Global translation is stable.
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartHeight = editorHeight
                    }
                    manualHeight = dragStartHeight + value.translation.height
                }
                .onEnded { _ in isDragging = false }
        )
        .onTapGesture(count: 2) { manualHeight = nil }   // reset to auto-grow
        .onHover { hovering in
            if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
        }
        .help("Drag to resize · double-click to auto-fit")
    }
}

/// "ⓘ" affordance placed next to the Content label. Opens a structured guide of WHAT a snippet's
/// content can hold and HOW to add each kind — replaces the old verbose caption under the editor.
struct ContentHelpButton: View {
    @State private var show = false

    var body: some View {
        Button(action: { show.toggle() }) {
            Image(systemName: "info.circle")
                .font(.system(size: DSIconSize.sm))
                .foregroundColor(DSColors.textTertiary)
        }
        .buttonStyle(PlainButtonStyle())
        .help("What can I add?")
        .popover(isPresented: $show) { ContentHelpPopover() }
    }
}

private struct ContentHelpPopover: View {
    private struct Row: Identifiable { let id = UUID(); let icon: String; let title: String; let detail: String }
    private let rows: [Row] = [
        Row(icon: "textformat", title: "Text", detail: "Just type."),
        Row(icon: "photo", title: "Images", detail: "Paste or drag inline, or use Add Image."),
        Row(icon: "doc", title: "Files", detail: "Use Add File — they paste after the document."),
        Row(icon: "curlybraces", title: "Dynamic tokens", detail: "Use Insert — {time}, {uuid}, {{field}}… resolve on paste.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What you can add")
                .font(DSTypography.captionMedium)
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.xs)

            DSDivider()

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        Image(systemName: row.icon)
                            .font(.system(size: DSIconSize.sm))
                            .foregroundColor(DSColors.accent)
                            .frame(width: 18, alignment: .center)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.title)
                                .font(DSTypography.captionMedium)
                                .foregroundColor(DSColors.textPrimary)
                            Text(row.detail)
                                .font(DSTypography.caption)
                                .foregroundColor(DSColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(DSSpacing.md)

            DSDivider()

            HStack(alignment: .top, spacing: DSSpacing.xs) {
                Image(systemName: "info.circle")
                    .font(.system(size: DSIconSize.xs))
                    .foregroundColor(DSColors.textTertiary)
                Text("{cursor} positions the caret in text-only snippets.")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
        }
        .frame(width: 320)
        .background(DSColors.controlBackground)
    }
}

/// Accent "chip" label used by the inline editor's toolbar affordances (Add Image, etc.).
struct InlineEditorChipLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: DSIconSize.xs, weight: .medium))
            Text(title)
                .font(DSTypography.captionMedium)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(DSColors.accent.opacity(0.12))
        .foregroundColor(DSColors.accent)
        .cornerRadius(DSRadius.xs)
    }
}
