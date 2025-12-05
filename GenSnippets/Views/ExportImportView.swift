import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportImportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var alertType: AlertType = .none
    @State private var errorMessage = ""
    @State private var exportedFileURL: URL?
    @State private var successMessage = ""

    private let localStorageService = LocalStorageService.shared

    enum AlertType {
        case none
        case exportSuccess
        case importSuccess
        case error
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Data Management")
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
            VStack(spacing: DSSpacing.xxl) {
                // Export Section
                DataActionCard(
                    icon: "square.and.arrow.up",
                    iconColor: DSColors.info,
                    title: "Export Data",
                    description: "Export all your categories and snippets to a JSON file for backup or transfer.",
                    buttonTitle: "Export to File",
                    buttonAction: exportData
                )

                // Import Section
                DataActionCard(
                    icon: "square.and.arrow.down",
                    iconColor: DSColors.success,
                    title: "Import Data",
                    description: "Import categories and snippets from a previously exported JSON file.",
                    buttonTitle: "Import from File",
                    buttonAction: importData
                )

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)
        }
        .frame(width: 520, height: 420)
        .background(DSColors.windowBackground)
        .alert(isPresented: .constant(alertType != .none)) {
            switch alertType {
            case .exportSuccess:
                return Alert(
                    title: Text("Export Successful"),
                    message: Text("Your data has been exported successfully to:\n\(exportedFileURL?.lastPathComponent ?? "")"),
                    primaryButton: .default(Text("Open in Finder")) {
                        if let url = exportedFileURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                        alertType = .none
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    },
                    secondaryButton: .default(Text("OK")) {
                        alertType = .none
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            case .importSuccess:
                return Alert(
                    title: Text("Import Successful"),
                    message: Text(successMessage),
                    dismissButton: .default(Text("OK")) {
                        alertType = .none
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            case .error:
                return Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK")) {
                        alertType = .none
                    }
                )
            case .none:
                return Alert(title: Text(""))
            }
        }
    }

    private func exportData() {
        if let fileURL = localStorageService.exportData() {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            savePanel.nameFieldStringValue = "GenSnippets_Export_\(dateFormatter.string(from: Date())).json"
            savePanel.message = "Choose location to save your GenSnippets data"

            if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
                do {
                    let data = try Data(contentsOf: fileURL)
                    try data.write(to: destinationURL)
                    exportedFileURL = destinationURL
                    try? FileManager.default.removeItem(at: fileURL)
                    alertType = .exportSuccess
                } catch {
                    errorMessage = "Failed to save export file: \(error.localizedDescription)"
                    alertType = .error
                }
            }
        } else {
            errorMessage = "Failed to export data"
            alertType = .error
        }
    }

    private func importData() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select GenSnippets export file to import"

        if openPanel.runModal() == .OK, let fileURL = openPanel.url {
            if localStorageService.importData(from: fileURL) {
                let categories = localStorageService.loadCategories()
                let snippets = localStorageService.loadSnippets()
                successMessage = "Successfully imported:\n\(categories.count) categories\n\(snippets.count) snippets"
                NotificationCenter.default.post(name: NSNotification.Name("RefreshData"), object: nil)
                alertType = .importSuccess
            } else {
                errorMessage = "Failed to import data. Please check the file format."
                alertType = .error
            }
        }
    }
}

// MARK: - Data Action Card
struct DataActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let buttonTitle: String
    let buttonAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DSSpacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: DSIconSize.xl))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.heading2)
                    .foregroundColor(DSColors.textPrimary)

                Text(description)
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Button
            Button(action: buttonAction) {
                Text(buttonTitle)
            }
            .buttonStyle(DSButtonStyle(.primary, size: .medium))
            .focusable(false)
        }
        .padding(DSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .fill(isHovered ? DSColors.hoverBackground : DSColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColors.borderSubtle, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(DSAnimation.easeOut) {
                isHovered = hovering
            }
        }
    }
}
