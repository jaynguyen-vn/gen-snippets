import SwiftUI
import AppKit

@available(macOS 12.0, *)
struct ModernSnippetSearchView: View {
    @StateObject private var viewModel = SnippetsViewModel()
    @State private var searchText = ""
    @State private var selectedSnippet: Snippet?
    @State private var selectedIndex = 0
    @State private var hoveredSnippetId: String?
    @State private var copiedSnippetId: String?
    @State private var isSearchFocused: Bool = true
    @FocusState private var textFieldFocused: Bool
    
    var filteredSnippets: [Snippet] {
        if searchText.isEmpty {
            return viewModel.snippets
        } else {
            return viewModel.snippets.filter { snippet in
                snippet.command.localizedCaseInsensitiveContains(searchText) ||
                (snippet.description ?? "").localizedCaseInsensitiveContains(searchText) ||
                snippet.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func copySnippetToClipboard(_ snippet: Snippet) {
        // Show copied feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            copiedSnippetId = snippet.id
        }
        
        // Close window and return to previous app
        NSApp.keyWindow?.close()
        SnippetSearchWindowController.returnToPreviousApp()
        
        // Insert snippet text directly into the focused app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TextReplacementService.shared.insertSnippetDirectly(snippet)
        }
    }
    
    private func selectNextSnippet() {
        guard !filteredSnippets.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, filteredSnippets.count - 1)
        selectedSnippet = filteredSnippets[selectedIndex]
    }
    
    private func selectPreviousSnippet() {
        guard !filteredSnippets.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        selectedSnippet = filteredSnippets[selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider().opacity(0.5)
            mainContent
        }
        .frame(width: 860, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.loadLocalSnippets()
            if let first = filteredSnippets.first {
                selectedSnippet = first
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveDownInSnippetList"))) { _ in
            selectNextSnippet()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveUpInSnippetList"))) { _ in
            selectPreviousSnippet()
        }
        .onChange(of: searchText) { _ in
            selectedIndex = 0
            if let first = filteredSnippets.first {
                selectedSnippet = first
            }
        }
    }
    
    private var searchHeader: some View {
        HStack(spacing: 12) {
            searchField
            Spacer()
            resultCount
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var searchField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                
                ModernSearchTextField(
                    text: $searchText,
                    placeholder: "Search snippets...",
                    isFocused: $isSearchFocused
                ) {
                    if let snippet = selectedSnippet {
                        copySnippetToClipboard(snippet)
                    }
                }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
    }
    
    private var resultCount: some View {
        Group {
            if !searchText.isEmpty {
                Text("\(filteredSnippets.count) result\(filteredSnippets.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
    
    private var mainContent: some View {
        HStack(spacing: 0) {
            snippetList
            Divider().opacity(0.3)
            snippetDetail
        }
    }
    
    private var snippetList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredSnippets.enumerated()), id: \.element.id) { index, snippet in
                        ModernSnippetRow(
                            snippet: snippet,
                            isSelected: selectedSnippet?.id == snippet.id,
                            isHovered: hoveredSnippetId == snippet.id,
                            isCopied: copiedSnippetId == snippet.id
                        )
                        .id(snippet.id)
                        .onTapGesture(count: 2) {
                            // Double-click to select and insert
                            selectedSnippet = snippet
                            selectedIndex = index
                            copySnippetToClipboard(snippet)
                        }
                        .onTapGesture {
                            selectedSnippet = snippet
                            selectedIndex = index
                        }
                        .onHover { isHovered in
                            if isHovered {
                                hoveredSnippetId = snippet.id
                            } else if hoveredSnippetId == snippet.id {
                                hoveredSnippetId = nil
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: selectedSnippet?.id) { newValue in
                if let id = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 340)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var snippetDetail: some View {
        VStack(spacing: 0) {
            if let snippet = selectedSnippet {
                ModernSnippetContent(
                    snippet: snippet,
                    category: nil
                ) {
                    copySnippetToClipboard(snippet)
                }
            } else {
                EmptyStateView()
            }
        }
        .frame(minWidth: 460)
    }
}

struct ModernSnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool
    let isHovered: Bool
    let isCopied: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            snippetIcon
            snippetInfo
            Spacer()
            copiedIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundStyle)
        .overlay(overlayStyle)
        .padding(.horizontal, 8)
    }
    
    private var snippetIcon: some View {
        ZStack {
            Circle()
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.15)
                        : Color.primary.opacity(0.05)
                )
                .frame(width: 32, height: 32)
            
            Text(String(snippet.command.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(
                    isSelected
                        ? Color.accentColor
                        : Color.primary.opacity(0.5)
                )
        }
    }
    
    private var snippetInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snippet.command)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if let description = snippet.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var copiedIndicator: some View {
        Group {
            if isCopied {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Inserted")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.08)
                    : isHovered
                        ? Color.primary.opacity(0.03)
                        : Color.clear
            )
    }
    
    private var overlayStyle: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear,
                lineWidth: 1
            )
    }
}

struct ModernSnippetContent: View {
    let snippet: Snippet
    let category: Category?
    let onCopy: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            content
        }
    }
    
    private var header: some View {
        HStack(spacing: 16) {
            snippetTitle
            Spacer()
            copyButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var snippetTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet.command)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                if let category = category {
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 4, height: 4)
                    
                    Text(category.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                if let description = snippet.description, !description.isEmpty {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3, height: 3)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: 6) {
                Image(systemName: "text.insert")
                    .font(.system(size: 13))
                Text("Insert")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(snippet.content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
                    .padding(20)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            
            VStack(spacing: 6) {
                Text("No snippet selected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("Select a snippet from the list or press ↑↓ to navigate")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// Modern Search TextField
struct ModernSearchTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.delegate = context.coordinator
        
        // Auto-focus when window opens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if isFocused {
                textField.window?.makeFirstResponder(textField)
                textField.becomeFirstResponder()
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        if isFocused && nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.selectText(nil)
                if let editor = nsView.currentEditor() {
                    editor.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ModernSearchTextField
        
        init(_ parent: ModernSearchTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                NotificationCenter.default.post(name: NSNotification.Name("MoveDownInSnippetList"), object: nil)
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                NotificationCenter.default.post(name: NSNotification.Name("MoveUpInSnippetList"), object: nil)
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let window = NSApp.keyWindow {
                    window.close()
                    SnippetSearchWindowController.returnToPreviousApp()
                }
                return true
            }
            return false
        }
    }
}

// Preview
@available(macOS 12.0, *)
struct ModernSnippetSearchView_Previews: PreviewProvider {
    static var previews: some View {
        ModernSnippetSearchView()
    }
}