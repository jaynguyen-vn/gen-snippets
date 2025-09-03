import SwiftUI
import Combine

struct ThreeColumnView: View {
    @StateObject private var categoryViewModel = CategoryViewModel()
    @StateObject private var snippetsViewModel = LocalSnippetsViewModel()
    
    @State private var selectedSnippet: Snippet?
    @State private var searchText = ""
    @State private var showAddCategorySheet = false
    @State private var showDeleteCategoryAlert = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var showAddSnippetSheet = false
    @State private var showExportImportSheet = false
    @State private var showDeleteSnippetAlert = false
    @State private var snippetToDelete: Snippet?
    
    @State private var sidebarWidth: CGFloat = 220
    @State private var snippetListWidth: CGFloat = 300
    
    // Bulk operations
    @State private var isMultiSelectMode = false
    @State private var selectedSnippetIds = Set<String>()
    @State private var showDeleteMultipleAlert = false
    @State private var showStatusBarIcon = true
    @State private var currentToast: Toast?
    @State private var showInsightsSheet = false
    
    var filteredSnippets: [Snippet] {
        let categoryFiltered = snippetsViewModel.snippets.filter { snippet in
            if let selectedCategory = categoryViewModel.selectedCategory {
                if selectedCategory.id == "all-snippets" {
                    // Show all snippets when "All" category is selected
                    return true
                } else if selectedCategory.id == "uncategory" {
                    return snippet.categoryId == nil || snippet.categoryId == ""
                } else {
                    return snippet.categoryId == selectedCategory.id
                }
            }
            return true
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { snippet in
                snippet.command.localizedCaseInsensitiveContains(searchText) ||
                snippet.content.localizedCaseInsensitiveContains(searchText) ||
                (snippet.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HSplitView {
                    // Category Sidebar
                    categoryListView
                        .frame(minWidth: 180, idealWidth: sidebarWidth, maxWidth: 300)
                    
                    // Snippet List
                    snippetListView
                        .frame(minWidth: 250, idealWidth: snippetListWidth, maxWidth: 400)
                    
                    // Detail View
                    detailView
                        .frame(minWidth: 400)
                }
            }
            
            // Status Bar with shortcuts
            StatusBarView()
        }
        .toast($currentToast)
        .onAppear {
            categoryViewModel.fetchCategories()
            snippetsViewModel.fetchSnippets()
            // Load saved preference for status bar icon
            showStatusBarIcon = UserDefaults.standard.object(forKey: "showStatusBarIcon") as? Bool ?? true
            print("[ThreeColumnView] Status bar icon state on appear: \(showStatusBarIcon)")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshData"))) { _ in
            // Refresh data after import
            categoryViewModel.fetchCategories()
            snippetsViewModel.fetchSnippets()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAllData"))) { _ in
            // Refresh data after clearing all data
            selectedSnippet = nil
            selectedSnippetIds.removeAll()
            categoryViewModel.fetchCategories()
            snippetsViewModel.fetchSnippets()
            
            // Show toast notification
            currentToast = Toast(type: .success, message: "All data has been cleared", duration: 2.0)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StatusBarIconChanged"))) { _ in
            // Update UI when status bar icon state changes
            showStatusBarIcon = UserDefaults.standard.object(forKey: "showStatusBarIcon") as? Bool ?? true
            print("[ThreeColumnView] Status bar icon state changed to: \(showStatusBarIcon)")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SnippetUsageUpdated"))) { _ in
            // Force refresh snippets to update UI
            snippetsViewModel.fetchSnippets()
        }
        // Keyboard shortcuts
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Command+N for new snippet
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
                    showAddSnippetSheet = true
                    return nil
                }
                // Command+Shift+N for new category
                if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "N" {
                    showAddCategorySheet = true
                    return nil
                }
                // Command+F for search focus
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                    // Focus search field
                    return nil
                }
                // Escape to exit multi-select mode
                if event.keyCode == 53 && isMultiSelectMode {
                    isMultiSelectMode = false
                    selectedSnippetIds.removeAll()
                    return nil
                }
                return event
            }
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(viewModel: categoryViewModel)
        }
        .sheet(item: $categoryToEdit) { category in
            EditCategorySheet(viewModel: categoryViewModel, category: category)
        }
        .sheet(isPresented: $showAddSnippetSheet) {
            AddSnippetSheet(
                snippetsViewModel: snippetsViewModel,
                categoryId: (categoryViewModel.selectedCategory?.id != "uncategory" && categoryViewModel.selectedCategory?.id != "all-snippets") ? categoryViewModel.selectedCategory?.id : nil
            )
        }
        .sheet(isPresented: $showExportImportSheet) {
            ExportImportView()
                .onDisappear {
                    // Refresh data after import
                    categoryViewModel.fetchCategories()
                    snippetsViewModel.fetchSnippets()
                }
        }
        .sheet(isPresented: $showInsightsSheet) {
            InsightsView()
        }
        .alert(isPresented: $showDeleteMultipleAlert) {
            Alert(
                title: Text("Delete Snippets"),
                message: Text("Are you sure you want to delete \(selectedSnippetIds.count) snippets? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteSelectedSnippets()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showDeleteSnippetAlert) {
            Alert(
                title: Text("Delete Snippet"),
                message: Text("Are you sure you want to delete \"\(snippetToDelete?.command ?? "")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let snippet = snippetToDelete {
                        snippetsViewModel.deleteSnippet(snippet.id)
                        // Clear selection if deleted snippet was selected
                        if selectedSnippet?.id == snippet.id {
                            selectedSnippet = nil
                        }
                        currentToast = Toast(type: .success, message: "Snippet deleted successfully", duration: 2.0)
                        snippetToDelete = nil
                    }
                },
                secondaryButton: .cancel {
                    snippetToDelete = nil
                }
            )
        }
    }
    
    private func deleteSelectedSnippets() {
        let count = selectedSnippetIds.count
        snippetsViewModel.deleteMultipleSnippets(selectedSnippetIds)
        selectedSnippetIds.removeAll()
        isMultiSelectMode = false
        
        // Show success toast
        currentToast = Toast(type: .success, message: "\(count) snippet\(count > 1 ? "s" : "") deleted successfully", duration: 2.0)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Category List View
    private var categoryListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Categories")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status Bar Icon Toggle
                Button(action: {
                    showStatusBarIcon.toggle()
                    UserDefaults.standard.set(showStatusBarIcon, forKey: "showStatusBarIcon")
                    print("[ThreeColumnView] Toggling status bar icon to: \(showStatusBarIcon)")
                    if showStatusBarIcon {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowMenuBarIcon"), object: nil)
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("HideMenuBarIcon"), object: nil)
                    }
                }) {
                    Image(systemName: showStatusBarIcon ? "eye" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundColor(showStatusBarIcon ? .blue : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(showStatusBarIcon ? "Hide from Menu Bar" : "Show in Menu Bar")
                
                Button(action: {
                    showExportImportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Export/Import Data")
                
                Button(action: {
                    showAddCategorySheet = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add Category (⌘⇧N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Category List
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(categoryViewModel.categories) { category in
                        CategoryRowView(
                            category: category,
                            isSelected: categoryViewModel.selectedCategory?.id == category.id,
                            snippetCount: getSnippetCount(for: category),
                            onSelect: {
                                categoryViewModel.selectCategory(category)
                                // Get first snippet of the new category
                                let categorySnippets = getSnippetsForCategory(category)
                                selectedSnippet = categorySnippets.first
                            },
                            onEdit: (category.id != "uncategory" && category.id != "all-snippets") ? {
                                categoryToEdit = category
                            } : nil,
                            onDelete: (category.id != "uncategory" && category.id != "all-snippets") ? {
                                print("[ThreeColumnView] Delete button clicked for category: \(category.name)")
                                categoryToDelete = category
                                showDeleteCategoryAlert = true
                                print("[ThreeColumnView] showDeleteCategoryAlert set to true, categoryToDelete: \(category.name)")
                            } : nil
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert(isPresented: $showDeleteCategoryAlert) {
            Alert(
                title: Text("Delete Category"),
                message: Text("Are you sure you want to delete \"\(categoryToDelete?.name ?? "")\"? All snippets in this category will be moved to Uncategory."),
                primaryButton: .destructive(Text("Delete")) {
                    print("[ThreeColumnView] User confirmed delete for category: \(categoryToDelete?.name ?? "unknown")")
                    if let category = categoryToDelete {
                        categoryViewModel.deleteCategory(category.id)
                        // Reset the state
                        categoryToDelete = nil
                    }
                },
                secondaryButton: .cancel {
                    print("[ThreeColumnView] User cancelled delete")
                    categoryToDelete = nil
                }
            )
        }
    }
    
    // MARK: - Snippet List View
    private var snippetListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Search
            VStack(spacing: 12) {
                HStack {
                    Text("Snippets")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Insights button
                    Button(action: {
                        showInsightsSheet = true
                    }) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("View Insights")
                    
                    if isMultiSelectMode {
                        Button(action: {
                            if selectedSnippetIds.isEmpty {
                                // Select all
                                selectedSnippetIds = Set(filteredSnippets.map { $0.id })
                            } else {
                                // Deselect all
                                selectedSnippetIds.removeAll()
                            }
                        }) {
                            Text(selectedSnippetIds.isEmpty ? "Select All" : "Deselect All")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if !selectedSnippetIds.isEmpty {
                                showDeleteMultipleAlert = true
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(selectedSnippetIds.isEmpty)
                        
                        Button(action: {
                            isMultiSelectMode = false
                            selectedSnippetIds.removeAll()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: {
                            isMultiSelectMode = true
                        }) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Select Multiple")
                        
                        Button(action: {
                            showAddSnippetSheet = true
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Add Snippet (⌘N)")
                    }
                }
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search snippets...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Snippet List
            if filteredSnippets.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: searchText.isEmpty ? "doc.text.below.ecg" : "doc.text.magnifyingglass")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        Text(searchText.isEmpty ? "No snippets yet" : "No results found")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(searchText.isEmpty ? "Create your first snippet to get started" : "Try adjusting your search terms")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    if searchText.isEmpty {
                        Button(action: {
                            showAddSnippetSheet = true
                        }) {
                            Label("Create Snippet", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(ModernButtonStyle(isPrimary: true))
                        .padding(.top, 8)
                    } else {
                        Button(action: {
                            searchText = ""
                        }) {
                            Label("Clear Search", systemImage: "xmark.circle")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(ModernButtonStyle(isPrimary: false))
                        .padding(.top, 8)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredSnippets) { snippet in
                            if isMultiSelectMode {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedSnippetIds.contains(snippet.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedSnippetIds.contains(snippet.id) ? .accentColor : .secondary)
                                        .animation(.easeInOut(duration: 0.2), value: selectedSnippetIds.contains(snippet.id))
                                        .onTapGesture {
                                            if selectedSnippetIds.contains(snippet.id) {
                                                selectedSnippetIds.remove(snippet.id)
                                            } else {
                                                selectedSnippetIds.insert(snippet.id)
                                            }
                                        }
                                    
                                    SnippetRowView(
                                        snippet: snippet,
                                        isSelected: false,
                                        categoryName: getCategoryName(for: snippet),
                                        showCategory: categoryViewModel.selectedCategory?.id == "all-snippets",
                                        onSelect: {
                                            if selectedSnippetIds.contains(snippet.id) {
                                                selectedSnippetIds.remove(snippet.id)
                                            } else {
                                                selectedSnippetIds.insert(snippet.id)
                                            }
                                        },
                                        onDelete: {
                                            deleteSnippet(snippet)
                                        }
                                    )
                                }
                            } else {
                                SnippetRowView(
                                    snippet: snippet,
                                    isSelected: selectedSnippet?.id == snippet.id,
                                    categoryName: getCategoryName(for: snippet),
                                    showCategory: categoryViewModel.selectedCategory?.id == "all-snippets",
                                    onSelect: {
                                        selectedSnippet = snippet
                                    },
                                    onDelete: {
                                        deleteSnippet(snippet)
                                    }
                                )
                                .contextMenu {
                                    Button(action: {
                                        duplicateSnippet(snippet)
                                    }) {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        copySnippetToClipboard(snippet)
                                    }) {
                                        Label("Copy Content", systemImage: "doc.on.clipboard")
                                    }
                                    
                                    Button(action: {
                                        copyCommandToClipboard(snippet)
                                    }) {
                                        Label("Copy Command", systemImage: "text.alignleft")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        deleteSnippet(snippet)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Detail View
    private var detailView: some View {
        VStack(spacing: 0) {
            if let snippet = selectedSnippet {
                SnippetDetailView(
                    snippet: snippet,
                    snippetsViewModel: snippetsViewModel,
                    categoryName: getCategoryName(for: snippet),
                    onUpdate: { updatedSnippet in
                        selectedSnippet = updatedSnippet
                    },
                    onDelete: {
                        selectedSnippet = nil
                    }
                )
                .id(snippet.id) // Force view to recreate when snippet changes
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "text.cursor")
                        .font(.system(size: 72))
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Text("No Snippet Selected")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Select a snippet to view and edit its details")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showAddSnippetSheet = true
                    }) {
                        Label("New Snippet", systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(ModernButtonStyle(isPrimary: true))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func getSnippetCount(for category: Category) -> Int {
        getSnippetsForCategory(category).count
    }
    
    private func getSnippetsForCategory(_ category: Category) -> [Snippet] {
        snippetsViewModel.snippets.filter { snippet in
            if category.id == "all-snippets" {
                // Return all snippets for "All" category
                return true
            } else if category.id == "uncategory" {
                return snippet.categoryId == nil || snippet.categoryId == ""
            } else {
                return snippet.categoryId == category.id
            }
        }
    }
    
    private func getCategoryName(for snippet: Snippet) -> String {
        if snippet.categoryId == nil || snippet.categoryId == "" {
            return "Uncategory"
        }
        return categoryViewModel.categories.first { $0.id == snippet.categoryId }?.name ?? "Uncategory"
    }
    
    private func duplicateSnippet(_ snippet: Snippet) {
        let duplicatedCommand = "\(snippet.command) (copy)"
        snippetsViewModel.createSnippet(
            command: duplicatedCommand,
            content: snippet.content,
            description: snippet.description.map { "\($0) (copy)" },
            categoryId: snippet.categoryId
        )
        
        // Show success toast
        currentToast = Toast(type: .success, message: "Snippet duplicated successfully", duration: 2.0)
    }
    
    private func copySnippetToClipboard(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.content, forType: .string)
        
        // Show success toast
        currentToast = Toast(type: .info, message: "Content copied to clipboard", duration: 2.0)
    }
    
    private func copyCommandToClipboard(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.command, forType: .string)
        
        // Show success toast
        currentToast = Toast(type: .info, message: "Command copied to clipboard", duration: 2.0)
    }
    
    private func deleteSnippet(_ snippet: Snippet) {
        snippetToDelete = snippet
        showDeleteSnippetAlert = true
    }
}

// MARK: - Category Row View
struct CategoryRowView: View {
    let category: Category
    let isSelected: Bool
    let snippetCount: Int
    var onSelect: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: category.id == "all-snippets" ? "tray.full" : "folder")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .secondary)
            
            Text(category.name)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
            
            if isHovering && category.id != "uncategory" && category.id != "all-snippets" {
                HStack(spacing: 4) {
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(isSelected ? .white : .secondary)
                    }
                    
                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(isSelected ? .white : .secondary)
                    }
                }
            } else {
                Text("\(snippetCount)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Snippet Row View
struct SnippetRowView: View {
    let snippet: Snippet
    let isSelected: Bool
    let categoryName: String?
    let showCategory: Bool
    let onSelect: () -> Void
    var onDelete: (() -> Void)?
    
    @StateObject private var usageTracker = UsageTracker.shared
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.command)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    // Usage stats
                    if let usage = usageTracker.getUsage(for: snippet.id), usage.usageCount > 0 {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 10))
                                Text("\(usage.usageCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .blue.opacity(0.8))
                            
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.5))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(usage.formattedLastUsed)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Show delete button on hover or category badge
                if isHovering, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .red.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete snippet")
                } else if showCategory, let categoryName = categoryName {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        )
                }
            }
            
            if let description = snippet.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            } else {
                Text(snippet.content)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}