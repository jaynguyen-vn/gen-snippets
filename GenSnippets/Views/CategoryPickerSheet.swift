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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(snippetCount == 1 ? "Move Snippet" : "Move \(snippetCount) Snippets")
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
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                // Search field
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Search")
                        .font(DSTypography.label)
                        .foregroundColor(DSColors.textSecondary)

                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: DSIconSize.sm))
                            .foregroundColor(DSColors.textTertiary)

                        TextField("Search categories...", text: $searchText)
                            .font(DSTypography.body)
                            .textFieldStyle(PlainTextFieldStyle())

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: DSIconSize.sm))
                                    .foregroundColor(DSColors.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(DSColors.textBackground)
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(DSColors.borderSubtle, lineWidth: 1)
                    )
                }

                // Category list
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Select Category")
                        .font(DSTypography.label)
                        .foregroundColor(DSColors.textSecondary)

                    if filteredCategories.isEmpty {
                        VStack(spacing: DSSpacing.md) {
                            Spacer()
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: DSIconSize.huge))
                                .foregroundColor(DSColors.textTertiary)

                            Text("No categories found")
                                .font(DSTypography.body)
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DSSpacing.xxxs) {
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
                            .padding(DSSpacing.xxs)
                        }
                        .background(DSColors.textBackground)
                        .cornerRadius(DSRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                .stroke(DSColors.borderSubtle, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            // Buttons
            HStack(spacing: DSSpacing.md) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .keyboardShortcut(.escape)

                Spacer()

                Button("Move") {
                    if let categoryId = selectedCategoryId {
                        let targetId = categoryId == "uncategory" ? nil : categoryId
                        onSelect(targetId)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
                .disabled(selectedCategoryId == nil)
                .opacity(selectedCategoryId == nil ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 420, height: 480)
        .background(DSColors.windowBackground)
    }
}

struct CategoryPickerRow: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "folder")
                    .font(.system(size: DSIconSize.sm))
                    .foregroundColor(isSelected ? .white : DSColors.accent)

                Text(category.name)
                    .font(DSTypography.body)
                    .foregroundColor(isSelected ? .white : DSColors.textPrimary)

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
