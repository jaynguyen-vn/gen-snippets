import SwiftUI
import AppKit

@available(macOS 12.0, *)
struct SnippetSearchView: View {
    @StateObject private var viewModel = SnippetsViewModel()
    @State private var searchText = ""
    @State private var selectedSnippet: Snippet?
    @State private var selectedIndex = 0
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.content, forType: .string)
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
        HSplitView {
            // Left side - Snippets list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    SearchTextField(text: $searchText, placeholder: "Search snippets...", isFocused: $isSearchFocused) {
                        // On submit action
                        if let snippet = selectedSnippet {
                            copySnippetToClipboard(snippet)
                            // Close window and return to previous app
                            NSApp.keyWindow?.close()
                            SnippetSearchWindowController.returnToPreviousApp()
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .padding(8)
                
                Divider()
                
                // Snippets list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredSnippets.enumerated()), id: \.element.id) { index, snippet in
                                SnippetRow(
                                    snippet: snippet,
                                    isSelected: selectedSnippet?.id == snippet.id
                                )
                                .id(snippet.id)
                                .onTapGesture {
                                    selectedSnippet = snippet
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                    .onChange(of: selectedSnippet?.id) { newValue in
                        if let id = newValue {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right side - Content view
            VStack {
                if let snippet = selectedSnippet {
                    SnippetContentView(snippet: snippet)
                } else {
                    Text("Select a snippet to view its content")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            viewModel.loadLocalSnippets()
            // Select first snippet by default
            if let first = filteredSnippets.first {
                selectedSnippet = first
            }
            // Focus search field after a brief delay to ensure window is ready
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
            // Auto-select first filtered result
            selectedIndex = 0
            if let first = filteredSnippets.first {
                selectedSnippet = first
            }
        }
    }
}

struct SnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.command)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let description = snippet.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.accentColor : Color.clear
        )
        .contentShape(Rectangle())
    }
}

struct SnippetContentView: View {
    let snippet: Snippet
    @State private var showCopiedToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with command and copy button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet.command)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let description = snippet.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet.content, forType: .string)
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopiedToast = true
                    }
                    
                    // Close window and return to previous app after copying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.keyWindow?.close()
                        SnippetSearchWindowController.returnToPreviousApp()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                        Text(showCopiedToast ? "Copied!" : "Copy")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content area
            ScrollView {
                if #available(macOS 12.0, *) {
                    Text(snippet.content)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(snippet.content)
                        .font(.system(size: 13))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// Custom TextField that can be focused programmatically
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void
    
    func getWindow() -> NSWindow? {
        return NSApp.keyWindow
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
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
        // Only update text if it's different to avoid losing cursor position
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Ensure focus when isFocused is true
        if isFocused && nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.selectText(nil)
                // Move cursor to end
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
        let parent: SearchTextField
        
        init(_ parent: SearchTextField) {
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
                // Handle down arrow
                NotificationCenter.default.post(name: NSNotification.Name("MoveDownInSnippetList"), object: nil)
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                // Handle up arrow
                NotificationCenter.default.post(name: NSNotification.Name("MoveUpInSnippetList"), object: nil)
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Handle escape key - close window and return to previous app
                if let window = parent.getWindow() {
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
struct SnippetSearchView_Previews: PreviewProvider {
    static var previews: some View {
        SnippetSearchView()
    }
}