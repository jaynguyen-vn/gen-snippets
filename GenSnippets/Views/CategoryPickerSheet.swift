import SwiftUI

struct CategoryPickerSheet: View {
    let categories: [Category]
    let snippetCount: Int
    let onSelect: (String?) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var selectedCategoryId: String?

    private var filteredCategories: [Category] {
        let validCategories = categories.filter { $0.id != "all-snippets" }
        if searchText.isEmpty {
            return validCategories
        }
        return validCategories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(snippetCount == 1 ? "Move Snippet" : "Move \(snippetCount) Snippets")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            // Search field
            VStack(alignment: .leading, spacing: 6) {
                Text("Search")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search categories...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            // Category list
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Category")
                    .font(.headline)
                    .foregroundColor(.secondary)

                if filteredCategories.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))

                        Text("No categories found")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredCategories) { category in
                                CategoryPickerRow(
                                    category: category,
                                    isSelected: selectedCategoryId == category.id,
                                    onSelect: {
                                        selectedCategoryId = category.id
                                    }
                                )
                            }
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
            }

            // Buttons
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(isPrimary: false))
                .keyboardShortcut(.escape)

                Spacer()

                Button("Move") {
                    if let categoryId = selectedCategoryId {
                        let targetId = categoryId == "uncategory" ? nil : categoryId
                        onSelect(targetId)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .keyboardShortcut(.return)
                .disabled(selectedCategoryId == nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 450)
    }
}

struct CategoryPickerRow: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .accentColor)

                Text(category.name)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
