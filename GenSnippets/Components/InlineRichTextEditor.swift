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

/// Seamless inline rich-text editor (text + inline images in one document), backed by NSTextView.
/// Produces an `NSAttributedString` the host serializes to RTFD. macOS 11.5-safe (no @FocusState /
/// TextKit 2 / 12+ SwiftUI APIs). Image paste & drag-drop become inline `NSTextAttachment`s via
/// `importsGraphics`.
struct InlineRichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var controller: InlineRichTextController? = nil

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
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(attributedText)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Keep the coordinator pointed at the current struct (SwiftUI re-creates it per render).
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage else { return }
        controller?.textView = textView

        // Don't clobber the user's edits / caret while they're typing. Only push an external
        // change (e.g. initial load, programmatic reset) when the view isn't being edited and
        // the content actually differs.
        if !context.coordinator.isEditing, !storage.isEqual(to: attributedText) {
            let selected = textView.selectedRange()
            storage.setAttributedString(attributedText)
            // Best-effort caret restore within new bounds.
            let loc = min(selected.location, storage.length)
            textView.setSelectedRange(NSRange(location: loc, length: 0))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineRichTextEditor
        var isEditing = false

        init(_ parent: InlineRichTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) { isEditing = true }
        func textDidEndEditing(_ notification: Notification) { isEditing = false }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            // Snapshot so downstream sees an immutable copy, not the live storage.
            parent.attributedText = NSAttributedString(attributedString: storage)
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
    var height: CGFloat = 200

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

                Spacer()
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.surfaceSecondary)

            Divider()

            InlineRichTextEditor(attributedText: $attributedText, controller: controller)
                .frame(height: height)
                .onChange(of: attributedText) { _ in onChange?() }
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .stroke(DSColors.border, lineWidth: 1)
        )
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
