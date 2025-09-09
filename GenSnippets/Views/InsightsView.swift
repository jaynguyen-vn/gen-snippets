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
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
            .padding(20)
            
            // Tab Selection
            Picker("", selection: $selectedTab) {
                Text("Most Used").tag(0)
                Text("Recently Used").tag(1)
                Text("Never Used").tag(2)
                Text("Statistics").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
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
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            snippetsViewModel.fetchSnippets()
        }
    }
    
    // MARK: - Most Used View
    private var mostUsedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let mostUsed = usageTracker.getMostUsedSnippets(limit: 20)
            
            if mostUsed.isEmpty {
                emptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Usage Data",
                    message: "Start using snippets to see statistics here"
                )
            } else {
                ForEach(mostUsed, id: \.snippetId) { item in
                    if let snippet = snippetsViewModel.snippets.first(where: { $0.id == item.snippetId }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snippet.command)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                
                                if let description = snippet.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text("\(item.usage.usageCount) uses")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                
                                Text("Last: \(item.usage.formattedLastUsed)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Recently Used View
    private var recentlyUsedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let recentlyUsed = usageTracker.getRecentlyUsedSnippets(limit: 20)
            
            if recentlyUsed.isEmpty {
                emptyStateView(
                    icon: "clock",
                    title: "No Recent Usage",
                    message: "Your recently used snippets will appear here"
                )
            } else {
                ForEach(recentlyUsed, id: \.snippetId) { item in
                    if let snippet = snippetsViewModel.snippets.first(where: { $0.id == item.snippetId }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snippet.command)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                
                                if let description = snippet.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                    Text(item.usage.formattedLastUsed)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                
                                Text("\(item.usage.usageCount) total uses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Never Used View
    private var neverUsedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let allSnippets = snippetsViewModel.snippets
            let neverUsed = allSnippets.filter { snippet in
                usageTracker.getUsageCount(for: snippet.id) == 0
            }
            
            if neverUsed.isEmpty {
                emptyStateView(
                    icon: "star.fill",
                    title: "All Snippets Used",
                    message: "Great! You're using all your snippets"
                )
            } else {
                Text("\(neverUsed.count) unused snippet\(neverUsed.count > 1 ? "s" : "")")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                ForEach(neverUsed) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippet.command)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            
                            if let description = snippet.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        Text("Never used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - Statistics View
    private var statisticsView: some View {
        VStack(spacing: 20) {
            let allSnippets = snippetsViewModel.snippets
            let usedSnippets = allSnippets.filter { snippet in
                usageTracker.getUsageCount(for: snippet.id) > 0
            }
            let totalUsage = allSnippets.reduce(0) { sum, snippet in
                sum + usageTracker.getUsageCount(for: snippet.id)
            }
            
            // Overview Cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Snippets",
                    value: "\(allSnippets.count)",
                    icon: "doc.text",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Usage",
                    value: "\(totalUsage)",
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Used Snippets",
                    value: "\(usedSnippets.count)/\(allSnippets.count)",
                    icon: "checkmark.circle.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Usage Rate",
                    value: allSnippets.isEmpty ? "0%" : "\(Int(Double(usedSnippets.count) / Double(allSnippets.count) * 100))%",
                    icon: "percent",
                    color: .purple
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Top Performers
            if !usageTracker.getMostUsedSnippets(limit: 5).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Performers")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    ForEach(usageTracker.getMostUsedSnippets(limit: 5), id: \.snippetId) { item in
                        if let snippet = snippetsViewModel.snippets.first(where: { $0.id == item.snippetId }) {
                            HStack {
                                Text(snippet.command)
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                // Usage bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.1))
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: geometry.size.width * min(Double(item.usage.usageCount) / Double(totalUsage), 1.0))
                                    }
                                }
                                .frame(width: 100, height: 20)
                                
                                Text("\(item.usage.usageCount)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}