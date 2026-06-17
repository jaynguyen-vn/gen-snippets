import SwiftUI

/// Shows the file attachments added to a snippet (the "Add File" button lives in the editor toolbar
/// next to "Add Image"). Files aren't inline-representable, so they paste as file references after
/// the inline document. Renders nothing when there are no files.
struct SnippetFileAttachments: View {
    @Binding var items: [RichContentItem]   // .file items
    var onChange: (() -> Void)? = nil

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: DSSpacing.xs) {
                ForEach(items) { item in
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(DSColors.accent)
                            .frame(width: 18)
                        Text(item.fileName ?? "File")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button(action: { remove(item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DSIconSize.sm))
                                .foregroundColor(DSColors.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(DSSpacing.xs)
                    .background(DSColors.textBackground)
                    .cornerRadius(DSRadius.xs)
                }
            }
        }
    }

    private func remove(_ item: RichContentItem) {
        items.removeAll { $0.id == item.id }
        onChange?()
    }
}
