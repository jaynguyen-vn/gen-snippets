import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShareImportSheet: View {
    @ObservedObject var categoryViewModel: CategoryViewModel
    @ObservedObject var snippetsViewModel: LocalSnippetsViewModel
    @Environment(\.presentationMode) var presentationMode

    enum ImportStep: Int, CaseIterable {
        case selectFile = 1
        case preview = 2
        case selectCategory = 3
        case resolvingConflicts = 4
        case importing = 5
        case complete = 6

        var title: String {
            switch self {
            case .selectFile: return "Select File"
            case .preview: return "Preview"
            case .selectCategory: return "Category"
            case .resolvingConflicts: return "Conflicts"
            case .importing: return "Importing"
            case .complete: return "Complete"
            }
        }

        var totalSteps: Int { 4 } // Don't count importing and complete as separate steps
    }

    @State private var currentStep: ImportStep = .selectFile
    @State private var shareData: ShareExportData?
    @State private var selectedFileName: String?
    @State private var conflicts: [SnippetConflictInfo] = []
    @State private var currentConflictIndex = 0
    @State private var resolutions: [String: ConflictResolution] = [:]
    @State private var selectedCategoryId: String? = nil
    @State private var importResult: ShareImportResult?
    @State private var errorMessage: String?
    @State private var isDragging = false

    private let shareService = ShareService.shared
    private let sheetWidth: CGFloat = 460
    private let sheetHeight: CGFloat = 480

    var body: some View {
        Group {
            switch currentStep {
            case .selectFile:
                selectFileView
            case .preview:
                previewView
            case .selectCategory:
                selectCategoryView
            case .resolvingConflicts:
                conflictResolutionView
            case .importing:
                importingView
            case .complete:
                completeView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentStep)
    }

    // MARK: - Step Indicator

    private func stepIndicator(currentStep: Int, totalSteps: Int) -> some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? DSColors.accent : DSColors.borderSubtle)
                    .frame(width: 8, height: 8)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? DSColors.accent : DSColors.borderSubtle)
                        .frame(width: 24, height: 2)
                }
            }
        }
    }

    // MARK: - Select File View

    private var selectFileView: some View {
        VStack(spacing: 0) {
            // Header
            headerView(title: "Import Shared Snippets", step: 1)

            // Content
            VStack(spacing: DSSpacing.lg) {
                Spacer()

                // Drag & Drop Zone
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.lg)
                        .strokeBorder(
                            isDragging ? DSColors.accent : DSColors.borderSubtle,
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.lg)
                                .fill(isDragging ? DSColors.accent.opacity(0.05) : Color.clear)
                        )
                        .frame(height: 180)

                    VStack(spacing: DSSpacing.md) {
                        Image(systemName: isDragging ? "arrow.down.doc.fill" : "square.and.arrow.down")
                            .font(.system(size: 40))
                            .foregroundColor(isDragging ? DSColors.accent : DSColors.textTertiary)

                        VStack(spacing: DSSpacing.xs) {
                            Text(isDragging ? "Drop file here" : "Drag & drop a file here")
                                .font(DSTypography.heading3)
                                .foregroundColor(DSColors.textPrimary)

                            Text("or click to browse")
                                .font(DSTypography.body)
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                .onTapGesture {
                    selectFile()
                }
                .onDrop(of: [.json, .fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                }

                if let error = errorMessage {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(DSColors.error)
                        Text(error)
                            .font(DSTypography.bodySmall)
                            .foregroundColor(DSColors.error)
                    }
                    .padding(DSSpacing.sm)
                    .background(DSColors.errorBackground)
                    .cornerRadius(DSRadius.sm)
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            // Footer
            footerView {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .focusable(false)
                .keyboardShortcut(.escape)

                Spacer()

                Button("Select File...") {
                    selectFile()
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
            }
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 0) {
            headerView(title: "Import Preview", step: 2)

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                if let data = shareData {
                    // File info
                    if let fileName = selectedFileName {
                        HStack(spacing: DSSpacing.sm) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: DSIconSize.sm))
                                .foregroundColor(DSColors.accent)
                            Text(fileName)
                                .font(DSTypography.body)
                                .foregroundColor(DSColors.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(DSSpacing.sm)
                        .background(DSColors.surfaceSecondary)
                        .cornerRadius(DSRadius.sm)
                    }

                    // Summary
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text("Contents")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        VStack(spacing: DSSpacing.sm) {
                            if let categoryName = data.categoryName {
                                infoRow(icon: "folder.fill", iconColor: DSColors.accent, text: "From category: \(categoryName)")
                            }

                            infoRow(icon: "doc.text.fill", iconColor: DSColors.textSecondary, text: "\(data.snippets.count) snippet\(data.snippets.count == 1 ? "" : "s")")

                            if !conflicts.isEmpty {
                                infoRow(icon: "exclamationmark.triangle.fill", iconColor: DSColors.warning, text: "\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s") to resolve", textColor: DSColors.warning)
                            }
                        }
                        .padding(DSSpacing.md)
                        .background(DSColors.textBackground)
                        .cornerRadius(DSRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                .stroke(DSColors.borderSubtle, lineWidth: 1)
                        )
                    }

                    // Snippet list preview
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Snippets")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        ScrollView {
                            LazyVStack(spacing: DSSpacing.xxs) {
                                ForEach(data.snippets, id: \.command) { snippet in
                                    HStack {
                                        Text(snippet.command)
                                            .font(DSTypography.code)
                                            .foregroundColor(DSColors.accent)

                                        Spacer()

                                        if conflicts.contains(where: { $0.command == snippet.command }) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: DSIconSize.xs))
                                                .foregroundColor(DSColors.warning)
                                        }
                                    }
                                    .padding(.horizontal, DSSpacing.sm)
                                    .padding(.vertical, DSSpacing.xs)
                                }
                            }
                            .padding(DSSpacing.xxs)
                        }
                        .frame(maxHeight: 120)
                        .background(DSColors.textBackground)
                        .cornerRadius(DSRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                .stroke(DSColors.borderSubtle, lineWidth: 1)
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            // Footer
            footerView {
                Button("Back") {
                    currentStep = .selectFile
                    shareData = nil
                    conflicts = []
                    selectedFileName = nil
                }
                .buttonStyle(DSButtonStyle(.secondary))

                Spacer()

                Button("Continue") {
                    // Pre-select default category
                    if shareData?.categoryName != nil {
                        selectedCategoryId = nil // Use original
                    } else {
                        selectedCategoryId = "uncategory"
                    }
                    currentStep = .selectCategory
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
            }
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
    }

    // MARK: - Select Category View

    private var selectCategoryView: some View {
        VStack(spacing: 0) {
            headerView(title: "Select Category", step: 3)

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("Choose where to import the snippets:")
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)

                ScrollView {
                    LazyVStack(spacing: DSSpacing.xxs) {
                        // Create new category option (from original)
                        if let categoryName = shareData?.categoryName {
                            CategoryOptionRow(
                                name: "Create new: \(categoryName)",
                                icon: "folder.badge.plus",
                                subtitle: "Will create a new category",
                                isSelected: selectedCategoryId == nil,
                                onSelect: { selectedCategoryId = nil }
                            )
                        }

                        // Uncategorized option
                        CategoryOptionRow(
                            name: "Uncategorized",
                            icon: "tray",
                            subtitle: "No category",
                            isSelected: selectedCategoryId == "uncategory",
                            onSelect: { selectedCategoryId = "uncategory" }
                        )

                        DSDivider()
                            .padding(.vertical, DSSpacing.xs)

                        // Existing categories
                        ForEach(categoryViewModel.categories.filter { $0.id != "all-snippets" && $0.id != "uncategory" }) { category in
                            CategoryOptionRow(
                                name: category.name,
                                icon: "folder",
                                subtitle: nil,
                                isSelected: selectedCategoryId == category.id,
                                onSelect: { selectedCategoryId = category.id }
                            )
                        }
                    }
                    .padding(DSSpacing.xxs)
                }
                .background(DSColors.textBackground)
                .cornerRadius(DSRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .stroke(DSColors.borderSubtle, lineWidth: 1)
                )

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            // Footer
            footerView {
                Button("Back") {
                    currentStep = .preview
                }
                .buttonStyle(DSButtonStyle(.secondary))

                Spacer()

                Button(conflicts.isEmpty ? "Import" : "Resolve \(conflicts.count) Conflict\(conflicts.count == 1 ? "" : "s")") {
                    if conflicts.isEmpty {
                        performImport()
                    } else {
                        currentConflictIndex = 0
                        currentStep = .resolvingConflicts
                    }
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
            }
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
    }

    // MARK: - Conflict Resolution View

    private var conflictResolutionView: some View {
        Group {
            if currentConflictIndex < conflicts.count {
                SnippetConflictResolutionView(
                    conflict: conflicts[currentConflictIndex],
                    currentIndex: currentConflictIndex,
                    totalConflicts: conflicts.count,
                    onResolve: { resolution in
                        resolutions[conflicts[currentConflictIndex].command] = resolution
                        if currentConflictIndex + 1 < conflicts.count {
                            currentConflictIndex += 1
                        } else {
                            performImport()
                        }
                    },
                    onCancel: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Importing View

    private var importingView: some View {
        VStack(spacing: 0) {
            headerView(title: "Importing...", step: 4, showClose: false)

            VStack(spacing: DSSpacing.lg) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.5)

                Text("Importing snippets...")
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            Spacer()
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 0) {
            headerView(title: "Import Complete", step: 4)

            VStack(spacing: DSSpacing.lg) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DSColors.success)

                if let result = importResult {
                    VStack(spacing: DSSpacing.sm) {
                        Text("Import Summary")
                            .font(DSTypography.heading2)
                            .foregroundColor(DSColors.textPrimary)

                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            if result.snippetsImported > 0 {
                                resultRow(icon: "plus.circle.fill", color: DSColors.success, text: "\(result.snippetsImported) imported")
                            }
                            if result.snippetsOverwritten > 0 {
                                resultRow(icon: "arrow.triangle.2.circlepath", color: DSColors.warning, text: "\(result.snippetsOverwritten) overwritten")
                            }
                            if result.snippetsRenamed > 0 {
                                resultRow(icon: "pencil.circle.fill", color: DSColors.info, text: "\(result.snippetsRenamed) renamed")
                            }
                            if result.snippetsSkipped > 0 {
                                resultRow(icon: "minus.circle.fill", color: DSColors.textTertiary, text: "\(result.snippetsSkipped) skipped")
                            }
                        }
                        .foregroundColor(DSColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            // Footer
            footerView {
                Spacer()

                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
            }
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .background(DSColors.windowBackground)
    }

    // MARK: - Helper Views

    private func headerView(title: String, step: Int, showClose: Bool = true) -> some View {
        VStack(spacing: DSSpacing.sm) {
            HStack {
                Text(title)
                    .font(DSTypography.displaySmall)
                    .foregroundColor(DSColors.textPrimary)

                Spacer()

                if showClose {
                    DSCloseButton {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }

            stepIndicator(currentStep: step, totalSteps: 4)
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.xl)
    }

    private func footerView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            DSDivider()
            HStack(spacing: DSSpacing.md) {
                content()
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
    }

    private func infoRow(icon: String, iconColor: Color, text: String, textColor: Color = DSColors.textPrimary) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: DSIconSize.sm))
                .foregroundColor(iconColor)

            Text(text)
                .font(DSTypography.body)
                .foregroundColor(textColor)

            Spacer()
        }
    }

    private func resultRow(icon: String, color: Color, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(DSTypography.body)
        }
    }

    // MARK: - Actions

    private func selectFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a GenSnippets shared file"

        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                processFile(url: url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.json.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        processFile(url: url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        processFile(url: url)
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        if url.pathExtension.lowercased() == "json" {
                            processFile(url: url)
                        } else {
                            errorMessage = "Please drop a .json file"
                        }
                    }
                }
            }
            return true
        }

        return false
    }

    private func processFile(url: URL) {
        do {
            let data = try shareService.parseShareFile(from: url)
            shareData = data
            selectedFileName = url.lastPathComponent
            conflicts = shareService.detectConflicts(in: data)
            errorMessage = nil
            currentStep = .preview
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let data = shareData else { return }

        currentStep = .importing

        DispatchQueue.global(qos: .userInitiated).async {
            let result = shareService.importWithResolutions(
                shareData: data,
                resolutions: resolutions,
                targetCategoryId: selectedCategoryId
            )

            DispatchQueue.main.async {
                importResult = result

                // Refresh data
                categoryViewModel.fetchCategories()
                snippetsViewModel.fetchSnippets()

                // Post notification for other views
                NotificationCenter.default.post(name: NSNotification.Name("RefreshData"), object: nil)

                currentStep = .complete
            }
        }
    }
}

// MARK: - Category Option Row

private struct CategoryOptionRow: View {
    let name: String
    let icon: String
    let subtitle: String?
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DSIconSize.sm))
                    .foregroundColor(isSelected ? .white : DSColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(DSTypography.body)
                        .foregroundColor(isSelected ? .white : DSColors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DSTypography.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : DSColors.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: DSIconSize.xs, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(DSAnimation.easeOut) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DSColors.accent
        } else if isHovered {
            return DSColors.hoverBackground
        }
        return Color.clear
    }
}
