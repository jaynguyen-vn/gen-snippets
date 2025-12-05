import SwiftUI
import AppKit

@available(macOS 12.0, *)
struct ModernSnippetSearchView: View {
    @StateObject private var viewModel = LocalSnippetsViewModel()
    @State private var searchText = ""
    @State private var selectedSnippet: Snippet?
    @State private var selectedSnippetId: String? = nil
    @State private var hoveredSnippetId: String?
    @State private var copiedSnippetId: String?
    @State private var isSearchFocused: Bool = true
    @FocusState private var textFieldFocused: Bool
    @State private var cachedFilteredSnippets: [Snippet] = []
    @State private var lastSearchText: String = ""
    @State private var lastSnippetsCount: Int = 0
    @State private var shouldScrollToSelection = false

    var filteredSnippets: [Snippet] {
        return cachedFilteredSnippets
    }

    private func updateFilteredSnippets() {
        if searchText == lastSearchText && viewModel.snippets.count == lastSnippetsCount {
            return
        }

        lastSearchText = searchText
        lastSnippetsCount = viewModel.snippets.count

        if searchText.isEmpty {
            cachedFilteredSnippets = viewModel.snippets
        } else {
            cachedFilteredSnippets = viewModel.snippets.filter { snippet in
                snippet.command.localizedCaseInsensitiveContains(searchText) ||
                (snippet.description ?? "").localizedCaseInsensitiveContains(searchText) ||
                snippet.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func copySnippetToClipboard(_ snippet: Snippet) {
        withAnimation(DSAnimation.springQuick) {
            copiedSnippetId = snippet.id
        }

        NSApp.keyWindow?.close()
        SnippetSearchWindowController.returnToPreviousApp()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TextReplacementService.shared.insertSnippetDirectly(snippet)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(snippet.content, forType: .string)
            }
        }
    }

    private func selectNextSnippet() {
        guard !filteredSnippets.isEmpty else { return }

        let currentIndex = filteredSnippets.firstIndex(where: { $0.id == selectedSnippetId }) ?? -1
        let nextIndex = min(currentIndex + 1, filteredSnippets.count - 1)

        if nextIndex >= 0 && nextIndex < filteredSnippets.count {
            let newSnippet = filteredSnippets[nextIndex]
            selectedSnippet = newSnippet
            selectedSnippetId = newSnippet.id
            shouldScrollToSelection = true
        }
    }

    private func selectPreviousSnippet() {
        guard !filteredSnippets.isEmpty else { return }

        let currentIndex = filteredSnippets.firstIndex(where: { $0.id == selectedSnippetId }) ?? filteredSnippets.count
        let previousIndex = max(currentIndex - 1, 0)

        if previousIndex >= 0 && previousIndex < filteredSnippets.count {
            let newSnippet = filteredSnippets[previousIndex]
            selectedSnippet = newSnippet
            selectedSnippetId = newSnippet.id
            shouldScrollToSelection = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            DSDivider()
            mainContent
        }
        .frame(width: 880, height: 600)
        .dsModalBackground(cornerRadius: DSRadius.lg)
        .onAppear {
            viewModel.loadSnippets()
            updateFilteredSnippets()
            if let first = filteredSnippets.first {
                selectedSnippet = first
                selectedSnippetId = first.id
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
            updateFilteredSnippets()
            if let first = filteredSnippets.first {
                selectedSnippet = first
                selectedSnippetId = first.id
                shouldScrollToSelection = true
            } else {
                selectedSnippet = nil
                selectedSnippetId = nil
            }
        }
        .onChange(of: viewModel.snippets) { _ in
            updateFilteredSnippets()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SnippetsUpdated"))) { notification in
            if let snippets = notification.object as? [Snippet] {
                viewModel.snippets = snippets
                updateFilteredSnippets()
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: DSSpacing.md) {
            searchField
            Spacer()
            resultCount
            keyboardHints
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.lg)
        .background(DSColors.windowBackground)
    }

    private var searchField: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DSIconSize.md))
                .foregroundColor(DSColors.textTertiary)

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
                        .font(.system(size: DSIconSize.sm))
                        .foregroundColor(DSColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(DSColors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(DSColors.borderSubtle, lineWidth: 1)
        )
        .frame(minWidth: 300)
    }

    private var resultCount: some View {
        Group {
            if !searchText.isEmpty {
                Text("\(filteredSnippets.count) result\(filteredSnippets.count == 1 ? "" : "s")")
                    .font(DSTypography.captionMedium)
                    .foregroundColor(DSColors.textTertiary)
            }
        }
    }

    private var keyboardHints: some View {
        HStack(spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.xxs) {
                DSShortcutBadge(keys: ["Enter"])
                Text("Insert")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)
            }

            HStack(spacing: DSSpacing.xxs) {
                DSShortcutBadge(keys: ["Esc"])
                Text("Close")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)
            }
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            snippetList
            Rectangle()
                .fill(DSColors.border)
                .frame(width: 1)
            snippetDetail
        }
    }

    private var snippetList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DSSpacing.xxxs) {
                    ForEach(filteredSnippets, id: \.id) { snippet in
                        ModernSnippetRow(
                            snippet: snippet,
                            isSelected: selectedSnippetId == snippet.id,
                            isHovered: hoveredSnippetId == snippet.id,
                            isCopied: copiedSnippetId == snippet.id
                        )
                        .id(snippet.id)
                        .onTapGesture(count: 2) {
                            selectedSnippet = snippet
                            selectedSnippetId = snippet.id
                            copySnippetToClipboard(snippet)
                        }
                        .onTapGesture {
                            selectedSnippet = snippet
                            selectedSnippetId = snippet.id
                        }
                        .onHover { isHovered in
                            withAnimation(DSAnimation.easeOut) {
                                if isHovered {
                                    hoveredSnippetId = snippet.id
                                } else if hoveredSnippetId == snippet.id {
                                    hoveredSnippetId = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.sm)
            }
            .onChange(of: selectedSnippet) { newValue in
                if let snippet = newValue, shouldScrollToSelection {
                    withAnimation(DSAnimation.easeInOut) {
                        proxy.scrollTo(snippet.id, anchor: .center)
                    }
                    shouldScrollToSelection = false
                }
            }
            .onAppear {
                if let id = selectedSnippet?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 360)
        .background(DSColors.surfaceSecondary)
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
                SearchEmptyStateView()
            }
        }
        .frame(minWidth: 480)
    }
}

// MARK: - Modern Snippet Row
struct ModernSnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool
    let isHovered: Bool
    let isCopied: Bool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            snippetIcon
            snippetInfo
            Spacer()
            copiedIndicator
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(backgroundStyle)
        .overlay(overlayStyle)
    }

    private var snippetIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? DSColors.accent.opacity(0.2) : DSColors.surfaceSecondary)
                .frame(width: 36, height: 36)

            Text(String(snippet.command.prefix(1)).uppercased())
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? DSColors.accent : DSColors.textSecondary)
        }
    }

    private var snippetInfo: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxxs) {
            Text(snippet.command)
                .font(DSTypography.label)
                .foregroundColor(isSelected ? DSColors.textPrimary : DSColors.textPrimary)
                .lineLimit(1)

            if let description = snippet.description, !description.isEmpty {
                Text(description)
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var copiedIndicator: some View {
        Group {
            if isCopied {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DSIconSize.xs))
                    Text("Inserted")
                        .font(DSTypography.captionMedium)
                }
                .foregroundColor(DSColors.success)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: DSRadius.md)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return DSColors.selectedBackground
        } else if isHovered {
            return DSColors.hoverBackground
        }
        return Color.clear
    }

    private var overlayStyle: some View {
        RoundedRectangle(cornerRadius: DSRadius.md)
            .stroke(isSelected ? DSColors.accent.opacity(0.4) : Color.clear, lineWidth: isSelected ? 2 : 0)
    }
}

// MARK: - Modern Snippet Content
struct ModernSnippetContent: View {
    let snippet: Snippet
    let category: Category?
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            DSDivider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: DSSpacing.lg) {
            snippetTitle
            Spacer()
            copyButton
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.xl)
        .background(DSColors.windowBackground)
    }

    private var snippetTitle: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(snippet.command)
                .font(DSTypography.heading1)
                .foregroundColor(DSColors.textPrimary)

            HStack(spacing: DSSpacing.sm) {
                if let category = category {
                    HStack(spacing: DSSpacing.xxs) {
                        Circle()
                            .fill(DSColors.accent)
                            .frame(width: 6, height: 6)
                        Text(category.name)
                            .font(DSTypography.caption)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                if let description = snippet.description, !description.isEmpty {
                    if category != nil {
                        Circle()
                            .fill(DSColors.textTertiary)
                            .frame(width: 3, height: 3)
                    }
                    Text(description)
                        .font(DSTypography.caption)
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "text.insert")
                    .font(.system(size: DSIconSize.sm))
                Text("Insert")
                    .font(DSTypography.label)
            }
        }
        .buttonStyle(DSButtonStyle(.primary, size: .medium))
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
                    .font(DSTypography.code)
                    .foregroundColor(DSColors.textPrimary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .fill(DSColors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(DSColors.borderSubtle, lineWidth: 1)
                    )
                    .padding(DSSpacing.xl)
            }
        }
        .background(DSColors.textBackground)
    }
}

// MARK: - Search Empty State View
struct SearchEmptyStateView: View {
    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(DSColors.surfaceSecondary)
                    .frame(width: 88, height: 88)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(DSColors.textTertiary)
            }

            VStack(spacing: DSSpacing.sm) {
                Text("No snippet selected")
                    .font(DSTypography.heading2)
                    .foregroundColor(DSColors.textPrimary)

                Text("Select a snippet from the list or use arrow keys to navigate")
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: DSSpacing.lg) {
                HStack(spacing: DSSpacing.xxs) {
                    DSShortcutBadge(keys: ["Up"])
                    DSShortcutBadge(keys: ["Down"])
                }
                Text("Navigate")
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.textBackground)
    }
}

// MARK: - Modern Search TextField
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
            } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
                NotificationCenter.default.post(name: NSNotification.Name("MoveDownInSnippetList"), object: nil)
                return true
            } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                NotificationCenter.default.post(name: NSNotification.Name("MoveUpInSnippetList"), object: nil)
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
