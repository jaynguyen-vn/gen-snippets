import SwiftUI
import AppKit

struct ShareExportSheet: View {
    enum ExportType {
        case category(Category)
        case snippets(Set<String>)
    }

    enum ViewState {
        case preview
        case success
        case error(String)
    }

    let exportType: ExportType
    @Environment(\.presentationMode) var presentationMode

    @State private var viewState: ViewState = .preview
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var snippetPreviews: [SnippetPreview] = []

    private let shareService = ShareService.shared
    private let sheetWidth: CGFloat = 460
    private let sheetHeight: CGFloat = 480

    private var title: String {
        switch exportType {
        case .category:
            return "Share Category"
        case .snippets(let ids):
            return ids.count == 1 ? "Share Snippet" : "Share \(ids.count) Snippets"
        }
    }

    private var categoryName: String? {
        switch exportType {
        case .category(let category):
            return category.name
        case .snippets:
            return nil
        }
    }

    private var snippetCount: Int {
        snippetPreviews.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
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

            // Content
            Group {
                switch viewState {
                case .preview:
                    previewView
                case .success:
                    successView
                case .error(let message):
                    errorView(message)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewState.isSuccess)

            // Footer
            footerView
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
        .onAppear {
            loadSnippetPreviews()
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            // Export summary
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("Export Preview")
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.textSecondary)

                VStack(spacing: DSSpacing.sm) {
                    if let name = categoryName {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: DSIconSize.sm))
                                .foregroundColor(DSColors.accent)

                            Text(name)
                                .font(DSTypography.body)
                                .foregroundColor(DSColors.textPrimary)

                            Spacer()
                        }
                    }

                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: DSIconSize.sm))
                            .foregroundColor(snippetCount == 0 ? DSColors.warning : DSColors.textSecondary)

                        Text("\(snippetCount) snippet\(snippetCount == 1 ? "" : "s")")
                            .font(DSTypography.body)
                            .foregroundColor(snippetCount == 0 ? DSColors.warning : DSColors.textPrimary)

                        Spacer()

                        if snippetCount == 0 {
                            Text("Nothing to export")
                                .font(DSTypography.caption)
                                .foregroundColor(DSColors.warning)
                        }
                    }
                }
                .padding(DSSpacing.md)
                .background(DSColors.textBackground)
                .cornerRadius(DSRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .stroke(snippetCount == 0 ? DSColors.warning.opacity(0.5) : DSColors.borderSubtle, lineWidth: 1)
                )
            }

            // Snippet list preview
            if snippetCount > 0 {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Snippets to Export")
                        .font(DSTypography.label)
                        .foregroundColor(DSColors.textSecondary)

                    ScrollView {
                        LazyVStack(spacing: DSSpacing.xxs) {
                            ForEach(snippetPreviews) { snippet in
                                HStack {
                                    Text(snippet.command)
                                        .font(DSTypography.code)
                                        .foregroundColor(DSColors.accent)

                                    Spacer()

                                    if snippet.hasRichContent {
                                        Image(systemName: "photo")
                                            .font(.system(size: DSIconSize.xs))
                                            .foregroundColor(DSColors.textTertiary)
                                    }
                                }
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xs)
                            }
                        }
                        .padding(DSSpacing.xxs)
                    }
                    .frame(maxHeight: 140)
                    .background(DSColors.textBackground)
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(DSColors.borderSubtle, lineWidth: 1)
                    )
                }
            }

            // Info text
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: DSIconSize.sm))
                    .foregroundColor(DSColors.info)

                Text("The exported file can be shared with others. They can import it using the Import button in GenSnippets.")
                    .font(DSTypography.bodySmall)
                    .foregroundColor(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.lg)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(DSColors.success)

            VStack(spacing: DSSpacing.xs) {
                Text("Export Successful")
                    .font(DSTypography.heading2)
                    .foregroundColor(DSColors.textPrimary)

                Text("\(snippetCount) snippet\(snippetCount == 1 ? "" : "s") exported")
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.lg)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DSColors.error)

            VStack(spacing: DSSpacing.xs) {
                Text("Export Failed")
                    .font(DSTypography.heading2)
                    .foregroundColor(DSColors.textPrimary)

                Text(message)
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                viewState = .preview
            }
            .buttonStyle(DSButtonStyle(.secondary, size: .small))

            Spacer()
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.lg)
    }

    // MARK: - Footer View

    private var footerView: some View {
        VStack(spacing: 0) {
            DSDivider()
            HStack(spacing: DSSpacing.md) {
                switch viewState {
                case .success:
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(DSButtonStyle(.secondary))
                    .keyboardShortcut(.escape)

                    Spacer()

                    if let url = exportedFileURL {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(DSButtonStyle(.primary))
                    }

                case .error:
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(DSButtonStyle(.secondary))
                    .keyboardShortcut(.escape)

                    Spacer()

                case .preview:
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(DSButtonStyle(.secondary))
                    .focusable(false)
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Export...") {
                        exportToFile()
                    }
                    .buttonStyle(DSButtonStyle(.primary))
                    .keyboardShortcut(.return)
                    .disabled(isExporting || snippetCount == 0)
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
    }

    // MARK: - Data Loading

    private func loadSnippetPreviews() {
        let allSnippets = LocalStorageService.shared.loadSnippets()

        switch exportType {
        case .category(let category):
            let categorySnippets = allSnippets.filter { $0.categoryId == category.id }
            snippetPreviews = categorySnippets.map {
                SnippetPreview(id: $0.id, command: $0.command, hasRichContent: $0.hasRichContent)
            }
        case .snippets(let ids):
            let selectedSnippets = allSnippets.filter { ids.contains($0.id) }
            snippetPreviews = selectedSnippets.map {
                SnippetPreview(id: $0.id, command: $0.command, hasRichContent: $0.hasRichContent)
            }
        }
    }

    // MARK: - Export Logic

    private func exportToFile() {
        isExporting = true

        // Generate export data
        let shareData: ShareExportData
        switch exportType {
        case .category(let category):
            shareData = shareService.exportCategory(category)
        case .snippets(let ids):
            shareData = shareService.exportSnippets(ids)
        }

        // Generate filename
        let filename = shareService.generateExportFilename(
            categoryName: shareData.categoryName,
            snippetCount: shareData.snippets.count
        )

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = filename
        savePanel.message = "Choose where to save the shared snippets"
        savePanel.canCreateDirectories = true

        savePanel.begin { result in
            isExporting = false

            if result == .OK, let url = savePanel.url {
                do {
                    let tempURL = try shareService.writeToFile(shareData, filename: filename)
                    try FileManager.default.moveItem(at: tempURL, to: url)
                    exportedFileURL = url
                    withAnimation {
                        viewState = .success
                    }
                } catch {
                    withAnimation {
                        viewState = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Types

private struct SnippetPreview: Identifiable {
    let id: String
    let command: String
    let hasRichContent: Bool
}

extension ShareExportSheet.ViewState {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
