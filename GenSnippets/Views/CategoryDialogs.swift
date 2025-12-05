import SwiftUI

// MARK: - Add Category Sheet
struct AddCategorySheet: View {
    @ObservedObject var viewModel: CategoryViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var description = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Category")
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

            // Form
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    HStack {
                        Text("Name")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        Text("*")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.error)
                    }

                    TextField("Category name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DSTypography.body)
                        .onChange(of: name) { _ in
                            errorMessage = ""
                        }
                }

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Description (Optional)")
                        .font(DSTypography.label)
                        .foregroundColor(DSColors.textSecondary)

                    TextField("Category description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DSTypography.body)
                }

                if !errorMessage.isEmpty {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: DSIconSize.sm))
                        Text(errorMessage)
                            .font(DSTypography.caption)
                    }
                    .foregroundColor(DSColors.error)
                    .padding(DSSpacing.sm)
                    .background(DSColors.errorBackground)
                    .cornerRadius(DSRadius.sm)
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            Spacer()

            // Action Buttons
            HStack(spacing: DSSpacing.md) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Category") {
                    addCategory()
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 420, height: 320)
        .background(DSColors.windowBackground)
    }

    private func addCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            errorMessage = "Category name cannot be empty"
            return
        }

        if viewModel.categories.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A category with this name already exists"
            return
        }

        viewModel.createCategory(
            name: trimmedName,
            description: description.isEmpty ? nil : description
        )

        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Edit Category Sheet
struct EditCategorySheet: View {
    @ObservedObject var viewModel: CategoryViewModel
    let category: Category
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var description = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Category")
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

            // Form
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    HStack {
                        Text("Name")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.textSecondary)

                        Text("*")
                            .font(DSTypography.label)
                            .foregroundColor(DSColors.error)
                    }

                    TextField("Category name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DSTypography.body)
                        .onChange(of: name) { _ in
                            errorMessage = ""
                        }
                }

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Description (Optional)")
                        .font(DSTypography.label)
                        .foregroundColor(DSColors.textSecondary)

                    TextField("Category description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(DSTypography.body)
                }

                if !errorMessage.isEmpty {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: DSIconSize.sm))
                        Text(errorMessage)
                            .font(DSTypography.caption)
                    }
                    .foregroundColor(DSColors.error)
                    .padding(DSSpacing.sm)
                    .background(DSColors.errorBackground)
                    .cornerRadius(DSRadius.sm)
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)

            Spacer()

            // Action Buttons
            HStack(spacing: DSSpacing.md) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DSButtonStyle(.secondary))
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save Changes") {
                    updateCategory()
                }
                .buttonStyle(DSButtonStyle(.primary))
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.lg)
            .background(DSColors.surfaceSecondary)
        }
        .frame(width: 420, height: 320)
        .background(DSColors.windowBackground)
        .onAppear {
            name = category.name
            description = category.description ?? ""
        }
    }

    private func updateCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            errorMessage = "Category name cannot be empty"
            return
        }

        if viewModel.categories.contains(where: {
            $0._id != category.id && $0.name.lowercased() == trimmedName.lowercased()
        }) {
            errorMessage = "A category with this name already exists"
            return
        }

        viewModel.updateCategory(
            category.id,
            name: trimmedName,
            description: description.isEmpty ? nil : description
        )

        presentationMode.wrappedValue.dismiss()
    }
}
