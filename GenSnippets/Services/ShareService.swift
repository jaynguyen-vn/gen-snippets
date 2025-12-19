import Foundation

class ShareService {
    static let shared = ShareService()

    private let localStorageService = LocalStorageService.shared

    private init() {}

    // MARK: - Export

    /// Export a single category with all its snippets
    func exportCategory(_ category: Category) -> ShareExportData {
        let allSnippets = localStorageService.loadSnippets()
        let categorySnippets = allSnippets.filter { $0.categoryId == category.id }

        let shareSnippets = categorySnippets.map { snippet in
            ShareSnippet(from: snippet, categoryName: category.name)
        }

        return ShareExportData(
            categoryName: category.name,
            snippets: shareSnippets
        )
    }

    /// Export selected snippets by their IDs
    func exportSnippets(_ snippetIds: Set<String>) -> ShareExportData {
        let allSnippets = localStorageService.loadSnippets()
        let allCategories = localStorageService.loadCategories()

        // Build category lookup
        var categoryNameById: [String: String] = [:]
        for category in allCategories {
            categoryNameById[category.id] = category.name
        }

        let selectedSnippets = allSnippets.filter { snippetIds.contains($0.id) }

        let shareSnippets = selectedSnippets.map { snippet in
            let categoryName = snippet.categoryId.flatMap { categoryNameById[$0] }
            return ShareSnippet(from: snippet, categoryName: categoryName)
        }

        // If all snippets are from the same category, include the category name
        let uniqueCategories = Set(shareSnippets.compactMap { $0.categoryName })
        let categoryName = uniqueCategories.count == 1 ? uniqueCategories.first : nil

        return ShareExportData(
            categoryName: categoryName,
            snippets: shareSnippets
        )
    }

    /// Write ShareExportData to a temporary file and return the URL
    func writeToFile(_ data: ShareExportData, filename: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try jsonData.write(to: fileURL)
        return fileURL
    }

    /// Generate a filename for export
    func generateExportFilename(categoryName: String?, snippetCount: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())

        if let name = categoryName {
            let safeName = name.replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
            return "GenSnippets_\(safeName)_\(dateString).json"
        } else {
            return "GenSnippets_\(snippetCount)_snippets_\(dateString).json"
        }
    }

    // MARK: - Import

    /// Parse a share file and return the data
    func parseShareFile(from url: URL) throws -> ShareExportData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShareExportData.self, from: data)
    }

    /// Detect conflicts between imported data and existing data
    func detectConflicts(in shareData: ShareExportData) -> [SnippetConflictInfo] {
        let existingSnippets = localStorageService.loadSnippets()

        // Build command -> snippet lookup
        var existingByCommand: [String: Snippet] = [:]
        for snippet in existingSnippets {
            existingByCommand[snippet.command] = snippet
        }

        var conflicts: [SnippetConflictInfo] = []

        for shareSnippet in shareData.snippets {
            if let existingSnippet = existingByCommand[shareSnippet.command] {
                let suggestedRename = generateUniqueCommand(shareSnippet.command)
                conflicts.append(SnippetConflictInfo(
                    command: shareSnippet.command,
                    existingSnippet: existingSnippet,
                    incomingSnippet: shareSnippet,
                    suggestedRename: suggestedRename
                ))
            }
        }

        return conflicts
    }

    /// Generate a unique command by adding "(copy)" suffix
    func generateUniqueCommand(_ baseCommand: String) -> String {
        let existingSnippets = localStorageService.loadSnippets()
        let existingCommands = Set(existingSnippets.map { $0.command })

        var candidateCommand = "\(baseCommand) (copy)"
        var counter = 2

        while existingCommands.contains(candidateCommand) {
            candidateCommand = "\(baseCommand) (copy \(counter))"
            counter += 1
        }

        return candidateCommand
    }

    /// Find or create a category by name, returning the category ID
    func findOrCreateCategory(name: String) -> String {
        let existingCategories = localStorageService.loadCategories()

        // Check if category exists (case-insensitive)
        if let existing = existingCategories.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing.id
        }

        // Create new category with "(Imported)" suffix if name conflicts
        let finalName: String
        if existingCategories.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            finalName = generateUniqueCategoryName(name)
        } else {
            finalName = name
        }

        let newCategory = Category(
            _id: localStorageService.generateId(),
            name: finalName,
            description: nil,
            userId: nil,
            isDeleted: false,
            createdAt: Date().description,
            updatedAt: Date().description
        )

        _ = localStorageService.createCategory(newCategory)
        return newCategory.id
    }

    /// Generate a unique category name with "(Imported)" suffix
    func generateUniqueCategoryName(_ baseName: String) -> String {
        let existingCategories = localStorageService.loadCategories()
        let existingNames = Set(existingCategories.map { $0.name.lowercased() })

        var candidateName = "\(baseName) (Imported)"
        var counter = 2

        while existingNames.contains(candidateName.lowercased()) {
            candidateName = "\(baseName) (Imported \(counter))"
            counter += 1
        }

        return candidateName
    }

    /// Import snippets with user-specified resolutions
    /// - Parameters:
    ///   - shareData: The parsed share data
    ///   - resolutions: Map of command -> resolution for conflicting snippets
    ///   - targetCategoryId: Optional category to import all snippets into (overrides category hints)
    /// - Returns: Import result summary
    func importWithResolutions(
        shareData: ShareExportData,
        resolutions: [String: ConflictResolution],
        targetCategoryId: String?
    ) -> ShareImportResult {
        var result = ShareImportResult()

        let existingSnippets = localStorageService.loadSnippets()
        var existingByCommand: [String: Snippet] = [:]
        for snippet in existingSnippets {
            existingByCommand[snippet.command] = snippet
        }

        // Determine category ID for imported snippets
        let categoryId: String?
        if let targetId = targetCategoryId {
            categoryId = targetId == "uncategory" ? nil : targetId
        } else if let categoryName = shareData.categoryName {
            categoryId = findOrCreateCategory(name: categoryName)
        } else {
            categoryId = nil
        }

        for shareSnippet in shareData.snippets {
            if let existingSnippet = existingByCommand[shareSnippet.command] {
                // Conflict - apply resolution
                guard let resolution = resolutions[shareSnippet.command] else {
                    result.snippetsSkipped += 1
                    continue
                }

                switch resolution {
                case .skip:
                    result.snippetsSkipped += 1

                case .overwrite:
                    let updated = Snippet(
                        _id: existingSnippet.id,
                        command: shareSnippet.command,
                        content: shareSnippet.content,
                        description: shareSnippet.description,
                        categoryId: categoryId,
                        userId: nil,
                        isDeleted: false,
                        createdAt: existingSnippet.createdAt,
                        updatedAt: Date().description,
                        contentType: shareSnippet.contentType,
                        richContentItems: shareSnippet.richContentItems
                    )
                    _ = localStorageService.updateSnippet(existingSnippet.id, updated)
                    result.snippetsOverwritten += 1

                case .rename(let newCommand):
                    let newSnippet = Snippet(
                        _id: localStorageService.generateId(),
                        command: newCommand,
                        content: shareSnippet.content,
                        description: shareSnippet.description,
                        categoryId: categoryId,
                        userId: nil,
                        isDeleted: false,
                        createdAt: Date().description,
                        updatedAt: Date().description,
                        contentType: shareSnippet.contentType,
                        richContentItems: shareSnippet.richContentItems
                    )
                    _ = localStorageService.createSnippet(newSnippet)
                    result.snippetsRenamed += 1
                }
            } else {
                // No conflict - create new snippet
                let newSnippet = Snippet(
                    _id: localStorageService.generateId(),
                    command: shareSnippet.command,
                    content: shareSnippet.content,
                    description: shareSnippet.description,
                    categoryId: categoryId,
                    userId: nil,
                    isDeleted: false,
                    createdAt: Date().description,
                    updatedAt: Date().description,
                    contentType: shareSnippet.contentType,
                    richContentItems: shareSnippet.richContentItems
                )
                _ = localStorageService.createSnippet(newSnippet)
                result.snippetsImported += 1
            }
        }

        // Force save to ensure data is persisted
        localStorageService.forceSave()

        return result
    }
}
