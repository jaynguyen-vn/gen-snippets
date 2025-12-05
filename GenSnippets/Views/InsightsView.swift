import SwiftUI

struct InsightsView: View {
    @StateObject private var usageTracker = UsageTracker.shared
    @StateObject private var snippetsViewModel = LocalSnippetsViewModel()
    @State private var selectedTab = 0
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Snippet Insights")
                    .font(DSTypography.displaySmall)
                    .foregroundColor(DSColors.textPrimary)

                Spacer()

                DSCloseButton {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)

            // Tab Selection
            Picker("", selection: $selectedTab) {
                Text("Most Used").tag(0)
                Text("Recently Used").tag(1)
                Text("Never Used").tag(2)
                Text("Statistics").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.bottom, DSSpacing.lg)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)

            // Content
            ScrollView {
                switch selectedTab {
                case 0:
                    mostUsedView
                case 1:
                    recentlyUsedView
                case 2:
                    neverUsedView
                case 3:
                    statisticsView
                default:
                    EmptyView()
                }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
        .background(DSColors.windowBackground)
        .onAppear {
            snippetsViewModel.fetchSnippets()
        }
    }

    // MARK: - Most Used View
    private var mostUsedView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            let mostUsed = usageTracker.getMostUsedSnippets(limit: 20)

            if mostUsed.isEmpty {
                emptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Usage Data",
                    message: "Start using snippets to see statistics here"
                )
            } else {
                ForEach(mostUsed, id: \.snippetCommand) { item in
                    if let snippet = snippetsViewModel.snippets.first(where: { $0.command == item.snippetCommand }) {
                        InsightRowView(
                            command: snippet.command,
                            description: snippet.description,
                            primaryIcon: "chart.bar.fill",
                            primaryText: "\(item.usage.usageCount) uses",
                            primaryColor: DSColors.info,
                            secondaryText: "Last: \(item.usage.formattedLastUsed)"
                        )
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.md)
            }
        }
    }

    // MARK: - Recently Used View
    private var recentlyUsedView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            let recentlyUsed = usageTracker.getRecentlyUsedSnippets(limit: 20)

            if recentlyUsed.isEmpty {
                emptyStateView(
                    icon: "clock",
                    title: "No Recent Usage",
                    message: "Your recently used snippets will appear here"
                )
            } else {
                ForEach(recentlyUsed, id: \.snippetCommand) { item in
                    if let snippet = snippetsViewModel.snippets.first(where: { $0.command == item.snippetCommand }) {
                        InsightRowView(
                            command: snippet.command,
                            description: snippet.description,
                            primaryIcon: "clock.fill",
                            primaryText: item.usage.formattedLastUsed,
                            primaryColor: DSColors.warning,
                            secondaryText: "\(item.usage.usageCount) total uses"
                        )
                    }
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.md)
            }
        }
    }

    // MARK: - Never Used View
    private var neverUsedView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            let allSnippets = snippetsViewModel.snippets
            let neverUsed = allSnippets.filter { snippet in
                usageTracker.getUsageCount(for: snippet.command) == 0
            }

            if neverUsed.isEmpty {
                emptyStateView(
                    icon: "star.fill",
                    title: "All Snippets Used",
                    message: "Great! You're using all your snippets"
                )
            } else {
                Text("\(neverUsed.count) unused snippet\(neverUsed.count > 1 ? "s" : "")")
                    .font(DSTypography.label)
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.horizontal, DSSpacing.xxl)
                    .padding(.top, DSSpacing.md)

                ForEach(neverUsed) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            Text(snippet.command)
                                .font(DSTypography.code)
                                .foregroundColor(DSColors.textPrimary)

                            if let description = snippet.description {
                                Text(description)
                                    .font(DSTypography.caption)
                                    .foregroundColor(DSColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text("Never used")
                            .font(DSTypography.captionMedium)
                            .foregroundColor(DSColors.textTertiary)
                            .padding(.horizontal, DSSpacing.sm)
                            .padding(.vertical, DSSpacing.xxs)
                            .background(DSColors.surfaceSecondary)
                            .cornerRadius(DSRadius.xs)
                    }
                    .padding(DSSpacing.md)
                    .background(DSColors.surface)
                    .cornerRadius(DSRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(DSColors.borderSubtle, lineWidth: 1)
                    )
                }
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.bottom, DSSpacing.md)
            }
        }
    }

    // MARK: - Statistics View
    private var statisticsView: some View {
        VStack(spacing: DSSpacing.xl) {
            let allSnippets = snippetsViewModel.snippets
            let usedSnippets = allSnippets.filter { snippet in
                usageTracker.getUsageCount(for: snippet.command) > 0
            }
            let totalUsage = allSnippets.reduce(0) { sum, snippet in
                sum + usageTracker.getUsageCount(for: snippet.command)
            }

            // Overview Cards
            HStack(spacing: DSSpacing.lg) {
                StatCard(
                    title: "Total Snippets",
                    value: "\(allSnippets.count)",
                    icon: "doc.text",
                    color: DSColors.info
                )

                StatCard(
                    title: "Total Usage",
                    value: "\(totalUsage)",
                    icon: "chart.bar.fill",
                    color: DSColors.success
                )

                StatCard(
                    title: "Used Snippets",
                    value: "\(usedSnippets.count)/\(allSnippets.count)",
                    icon: "checkmark.circle.fill",
                    color: DSColors.warning
                )

                StatCard(
                    title: "Usage Rate",
                    value: allSnippets.isEmpty ? "0%" : "\(Int(Double(usedSnippets.count) / Double(allSnippets.count) * 100))%",
                    icon: "percent",
                    color: Color.purple
                )
            }
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.top, DSSpacing.xl)

            DSDivider()
                .padding(.horizontal, DSSpacing.lg)

            // Top Performers
            if !usageTracker.getMostUsedSnippets(limit: 5).isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("Top Performers")
                        .font(DSTypography.heading2)
                        .foregroundColor(DSColors.textPrimary)
                        .padding(.horizontal, DSSpacing.xxl)

                    ForEach(usageTracker.getMostUsedSnippets(limit: 5), id: \.snippetCommand) { item in
                        if let snippet = snippetsViewModel.snippets.first(where: { $0.command == item.snippetCommand }) {
                            HStack(spacing: DSSpacing.md) {
                                Text(snippet.command)
                                    .font(DSTypography.code)
                                    .foregroundColor(DSColors.textPrimary)

                                Spacer()

                                // Usage bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: DSRadius.xs)
                                            .fill(DSColors.surfaceSecondary)

                                        RoundedRectangle(cornerRadius: DSRadius.xs)
                                            .fill(DSColors.accent)
                                            .frame(width: geometry.size.width * min(Double(item.usage.usageCount) / Double(totalUsage), 1.0))
                                    }
                                }
                                .frame(width: 100, height: 20)

                                Text("\(item.usage.usageCount)")
                                    .font(DSTypography.label)
                                    .foregroundColor(DSColors.textPrimary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.horizontal, DSSpacing.xxl)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: DSIconSize.huge + 16))
                .foregroundColor(DSColors.textTertiary)

            Text(title)
                .font(DSTypography.heading2)
                .foregroundColor(DSColors.textPrimary)

            Text(message)
                .font(DSTypography.body)
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.huge)
    }
}

// MARK: - Insight Row View
struct InsightRowView: View {
    let command: String
    let description: String?
    let primaryIcon: String
    let primaryText: String
    let primaryColor: Color
    let secondaryText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(command)
                    .font(DSTypography.code)
                    .foregroundColor(DSColors.textPrimary)

                if let description = description {
                    Text(description)
                        .font(DSTypography.caption)
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: primaryIcon)
                        .font(.system(size: DSIconSize.sm))
                        .foregroundColor(primaryColor)
                    Text(primaryText)
                        .font(DSTypography.label)
                        .foregroundColor(primaryColor)
                }

                Text(secondaryText)
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.surface)
        .cornerRadius(DSRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(DSColors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: DSIconSize.md))
                        .foregroundColor(color)
                }
                Spacer()
            }

            Text(value)
                .font(DSTypography.displayMedium)
                .foregroundColor(DSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(DSTypography.caption)
                .foregroundColor(DSColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSSpacing.lg)
        .background(DSColors.surface)
        .cornerRadius(DSRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .dsShadow(DSShadow.xs)
    }
}
