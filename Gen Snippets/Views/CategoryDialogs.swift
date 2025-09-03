import SwiftUI

// MARK: - Add Category Sheet
struct AddCategorySheet: View {
    @ObservedObject var viewModel: CategoryViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var description = ""
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Category")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("*")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Category name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: name) { _ in
                            errorMessage = ""
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Category description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(isPrimary: false))
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add") {
                    addCategory()
                }
                .buttonStyle(ModernButtonStyle())
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
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
        VStack(spacing: 20) {
            Text("Edit Category")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("*")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Category name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: name) { _ in
                            errorMessage = ""
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Category description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(isPrimary: false))
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    updateCategory()
                }
                .buttonStyle(ModernButtonStyle())
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
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