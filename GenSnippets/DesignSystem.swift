import SwiftUI

// MARK: - Design System
/// Centralized design tokens for GenSnippets app
/// This file contains all design constants to ensure visual consistency

// MARK: - Color Palette
struct DSColors {

    // MARK: Background Colors
    static let windowBackground = Color(NSColor.windowBackgroundColor)
    static let controlBackground = Color(NSColor.controlBackgroundColor)
    static let textBackground = Color(NSColor.textBackgroundColor)

    /// Elevated surface (cards, panels)
    static let surface = Color(NSColor.controlBackgroundColor)

    /// Secondary surface with subtle elevation
    static let surfaceSecondary = Color.primary.opacity(0.03)

    /// Hover state background
    static let hoverBackground = Color.primary.opacity(0.06)

    /// Selected state background
    static let selectedBackground = Color.accentColor.opacity(0.12)

    // MARK: Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.7)
    static let textPlaceholder = Color.secondary.opacity(0.5)

    // MARK: Accent Colors
    static let accent = Color.accentColor
    static let accentHover = Color.accentColor.opacity(0.85)
    static let accentPressed = Color.accentColor.opacity(0.7)

    // MARK: Status Colors
    static let success = Color.green
    static let successBackground = Color.green.opacity(0.12)

    static let error = Color.red
    static let errorBackground = Color.red.opacity(0.12)

    static let warning = Color.orange
    static let warningBackground = Color.orange.opacity(0.12)

    static let info = Color.blue
    static let infoBackground = Color.blue.opacity(0.12)

    // MARK: Border Colors
    static let border = Color.secondary.opacity(0.15)
    static let borderSubtle = Color.secondary.opacity(0.08)
    static let borderFocused = Color.accentColor.opacity(0.5)

    // MARK: Shadow Colors
    static let shadowLight = Color.black.opacity(0.06)
    static let shadowMedium = Color.black.opacity(0.1)
    static let shadowDark = Color.black.opacity(0.15)

    // MARK: Gradient
    static let gradientPrimary = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography
struct DSTypography {

    // MARK: Display
    static let displayLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let displaySmall = Font.system(size: 20, weight: .semibold, design: .rounded)

    // MARK: Headings
    static let heading1 = Font.system(size: 18, weight: .semibold, design: .default)
    static let heading2 = Font.system(size: 16, weight: .semibold, design: .default)
    static let heading3 = Font.system(size: 14, weight: .medium, design: .default)

    // MARK: Body
    static let bodyLarge = Font.system(size: 14, weight: .regular, design: .default)
    static let body = Font.system(size: 13, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: Labels
    static let label = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)
    static let labelTiny = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: Caption
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: Monospace (for code/commands)
    static let codeLarge = Font.system(size: 14, weight: .medium, design: .monospaced)
    static let code = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)

    // MARK: Section Headers
    static let sectionHeader = Font.system(size: 12, weight: .semibold, design: .default)
}

// MARK: - Spacing
struct DSSpacing {
    /// 2pt
    static let xxxs: CGFloat = 2
    /// 4pt
    static let xxs: CGFloat = 4
    /// 6pt
    static let xs: CGFloat = 6
    /// 8pt
    static let sm: CGFloat = 8
    /// 12pt
    static let md: CGFloat = 12
    /// 16pt
    static let lg: CGFloat = 16
    /// 20pt
    static let xl: CGFloat = 20
    /// 24pt
    static let xxl: CGFloat = 24
    /// 32pt
    static let xxxl: CGFloat = 32
    /// 40pt
    static let huge: CGFloat = 40
    /// 48pt
    static let massive: CGFloat = 48
}

// MARK: - Corner Radius
struct DSRadius {
    /// 2pt - Tiny elements
    static let xxs: CGFloat = 2
    /// 4pt - Small elements (badges, tags)
    static let xs: CGFloat = 4
    /// 6pt - Buttons, inputs
    static let sm: CGFloat = 6
    /// 8pt - Cards, panels
    static let md: CGFloat = 8
    /// 10pt - Larger cards
    static let lg: CGFloat = 10
    /// 12pt - Dialogs, sheets
    static let xl: CGFloat = 12
    /// 16pt - Large containers
    static let xxl: CGFloat = 16
    /// Full rounded (capsule)
    static let full: CGFloat = 9999
}

// MARK: - Shadows / Elevation
struct DSShadow {

    struct Level {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// No shadow
    static let none = Level(color: .clear, radius: 0, x: 0, y: 0)

    /// Subtle shadow for hover states
    static let xs = Level(color: DSColors.shadowLight, radius: 2, x: 0, y: 1)

    /// Light shadow for cards
    static let sm = Level(color: DSColors.shadowLight, radius: 4, x: 0, y: 2)

    /// Medium shadow for floating elements
    static let md = Level(color: DSColors.shadowMedium, radius: 8, x: 0, y: 4)

    /// Strong shadow for dropdowns, popovers
    static let lg = Level(color: DSColors.shadowMedium, radius: 12, x: 0, y: 6)

    /// Maximum shadow for modals
    static let xl = Level(color: DSColors.shadowDark, radius: 20, x: 0, y: 10)
}

// MARK: - Animation
struct DSAnimation {

    // MARK: Durations
    static let instant: Double = 0.1
    static let fast: Double = 0.15
    static let normal: Double = 0.2
    static let slow: Double = 0.3
    static let slower: Double = 0.4

    // MARK: Spring Animations
    static let springQuick = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let springNormal = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.9)

    // MARK: Easing
    static let easeOut = Animation.easeOut(duration: normal)
    static let easeInOut = Animation.easeInOut(duration: normal)
}

// MARK: - Icon Sizes
struct DSIconSize {
    /// 10pt
    static let xxs: CGFloat = 10
    /// 12pt
    static let xs: CGFloat = 12
    /// 14pt
    static let sm: CGFloat = 14
    /// 16pt
    static let md: CGFloat = 16
    /// 18pt
    static let lg: CGFloat = 18
    /// 20pt
    static let xl: CGFloat = 20
    /// 24pt
    static let xxl: CGFloat = 24
    /// 32pt
    static let huge: CGFloat = 32
}

// MARK: - Layout Constants
struct DSLayout {

    // MARK: Sidebar
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 220
    static let sidebarMaxWidth: CGFloat = 300

    // MARK: Snippet List
    static let snippetListMinWidth: CGFloat = 250
    static let snippetListIdealWidth: CGFloat = 300
    static let snippetListMaxWidth: CGFloat = 400

    // MARK: Detail View
    static let detailMinWidth: CGFloat = 400

    // MARK: Modal Sizes
    static let sheetWidth: CGFloat = 480
    static let sheetHeightSmall: CGFloat = 300
    static let sheetHeightMedium: CGFloat = 400
    static let sheetHeightLarge: CGFloat = 500

    // MARK: Row Heights
    static let categoryRowHeight: CGFloat = 36
    static let snippetRowHeight: CGFloat = 72
    static let settingRowHeight: CGFloat = 48
}


// MARK: - Component Styles

// MARK: Button Styles
struct DSButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost
    }

    enum Size {
        case small
        case medium
        case large

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return DSSpacing.sm
            case .medium: return DSSpacing.lg
            case .large: return DSSpacing.xl
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return DSSpacing.xxs
            case .medium: return DSSpacing.sm
            case .large: return DSSpacing.md
            }
        }

        var font: Font {
            switch self {
            case .small: return DSTypography.labelSmall
            case .medium: return DSTypography.label
            case .large: return DSTypography.bodyLarge
            }
        }
    }

    let variant: Variant
    let size: Size
    let isFullWidth: Bool

    init(_ variant: Variant = .primary, size: Size = .medium, fullWidth: Bool = false) {
        self.variant = variant
        self.size = size
        self.isFullWidth = fullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DSAnimation.springQuick, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? DSColors.accentPressed : DSColors.accent
        case .secondary:
            return isPressed ? DSColors.hoverBackground : Color.clear
        case .tertiary:
            return isPressed ? DSColors.hoverBackground : DSColors.surfaceSecondary
        case .destructive:
            return isPressed ? DSColors.error.opacity(0.85) : DSColors.error
        case .ghost:
            return isPressed ? DSColors.hoverBackground : Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .secondary, .tertiary, .ghost:
            return DSColors.textPrimary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:
            return DSColors.border
        default:
            return .clear
        }
    }
}

// MARK: Toggle Style
struct DSToggleStyle: ToggleStyle {
    var size: CGFloat = 42

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? DSColors.accent : DSColors.hoverBackground)
                    .frame(width: size, height: size * 0.57)

                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.48, height: size * 0.48)
                    .shadow(color: DSShadow.xs.color, radius: DSShadow.xs.radius, x: 0, y: DSShadow.xs.y)
                    .offset(x: configuration.isOn ? size * 0.21 : -size * 0.21)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(DSAnimation.springQuick, value: configuration.isOn)
    }
}

// MARK: Card Style
struct DSCardStyle: ViewModifier {
    enum Elevation {
        case flat
        case raised
        case floating
    }

    let elevation: Elevation
    let padding: CGFloat

    init(_ elevation: Elevation = .raised, padding: CGFloat = DSSpacing.lg) {
        self.elevation = elevation
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(DSColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(DSColors.borderSubtle, lineWidth: 1)
            )
            .shadow(
                color: shadowLevel.color,
                radius: shadowLevel.radius,
                x: shadowLevel.x,
                y: shadowLevel.y
            )
    }

    private var shadowLevel: DSShadow.Level {
        switch elevation {
        case .flat: return DSShadow.none
        case .raised: return DSShadow.sm
        case .floating: return DSShadow.md
        }
    }
}

// MARK: Input Field Style
struct DSInputStyle: ViewModifier {
    let isFocused: Bool

    init(focused: Bool = false) {
        self.isFocused = focused
    }

    func body(content: Content) -> some View {
        content
            .font(DSTypography.body)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(DSColors.textBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(isFocused ? DSColors.borderFocused : DSColors.border, lineWidth: 1)
            )
    }
}

// MARK: List Row Style
struct DSListRowStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(backgroundColor)
            )
            .animation(DSAnimation.easeOut, value: isSelected)
            .animation(DSAnimation.easeOut, value: isHovered)
    }

    private var backgroundColor: Color {
        if isSelected {
            return DSColors.selectedBackground
        } else if isHovered {
            return DSColors.hoverBackground
        }
        return Color.clear
    }
}

// MARK: Badge Style
struct DSBadgeStyle: ViewModifier {
    enum Variant {
        case neutral
        case primary
        case success
        case warning
        case error
    }

    let variant: Variant

    func body(content: Content) -> some View {
        content
            .font(DSTypography.captionMedium)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxxs)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
    }

    private var backgroundColor: Color {
        switch variant {
        case .neutral: return DSColors.surfaceSecondary
        case .primary: return DSColors.accent.opacity(0.15)
        case .success: return DSColors.successBackground
        case .warning: return DSColors.warningBackground
        case .error: return DSColors.errorBackground
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .neutral: return DSColors.textSecondary
        case .primary: return DSColors.accent
        case .success: return DSColors.success
        case .warning: return DSColors.warning
        case .error: return DSColors.error
        }
    }
}


// MARK: - View Extensions

extension View {

    // MARK: Card
    func dsCard(_ elevation: DSCardStyle.Elevation = .raised, padding: CGFloat = DSSpacing.lg) -> some View {
        modifier(DSCardStyle(elevation, padding: padding))
    }

    // MARK: Input
    func dsInput(focused: Bool = false) -> some View {
        modifier(DSInputStyle(focused: focused))
    }

    // MARK: List Row
    func dsListRow(selected: Bool, hovered: Bool = false) -> some View {
        modifier(DSListRowStyle(isSelected: selected, isHovered: hovered))
    }

    // MARK: Badge
    func dsBadge(_ variant: DSBadgeStyle.Variant = .neutral) -> some View {
        modifier(DSBadgeStyle(variant: variant))
    }

    // MARK: Shadow
    func dsShadow(_ level: DSShadow.Level) -> some View {
        self.shadow(color: level.color, radius: level.radius, x: level.x, y: level.y)
    }
}


// MARK: - Reusable Components

/// Section header with uppercase styling
struct DSSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DSTypography.sectionHeader)
            .foregroundColor(DSColors.textSecondary)
            .textCase(.uppercase)
    }
}

/// Empty state placeholder
struct DSEmptyState: View {
    let icon: String
    let title: String
    let description: String
    let action: (() -> Void)?
    let actionLabel: String?

    init(
        icon: String,
        title: String,
        description: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: DSIconSize.huge))
                .foregroundColor(DSColors.textTertiary)

            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.heading2)
                    .foregroundColor(DSColors.textPrimary)

                Text(description)
                    .font(DSTypography.body)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                }
                .buttonStyle(DSButtonStyle(.primary, size: .medium))
            }
        }
        .padding(DSSpacing.xxl)
    }
}

/// Close button for sheets
struct DSCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DSColors.hoverBackground)
                    .frame(width: 28, height: 28)

                Image(systemName: "xmark")
                    .font(.system(size: DSIconSize.xs, weight: .medium))
                    .foregroundColor(DSColors.textSecondary)
            }
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
}

/// Icon button (for toolbar actions)
struct DSIconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let isDestructive: Bool

    init(
        icon: String,
        size: CGFloat = DSIconSize.md,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.isDestructive = isDestructive
        self.action = action
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(isDestructive ? DSColors.error : DSColors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .fill(isHovered ? DSColors.hoverBackground : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Keyboard shortcut badge
struct DSShortcutBadge: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: DSSpacing.xxxs) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(DSTypography.captionMedium)
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.horizontal, DSSpacing.xxs)
                    .padding(.vertical, DSSpacing.xxxs)
                    .background(
                        RoundedRectangle(cornerRadius: DSRadius.xs)
                            .fill(DSColors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.xs)
                            .stroke(DSColors.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }
}

/// Divider with optional label
struct DSDivider: View {
    let label: String?

    init(_ label: String? = nil) {
        self.label = label
    }

    var body: some View {
        if let label = label {
            HStack(spacing: DSSpacing.md) {
                Rectangle()
                    .fill(DSColors.border)
                    .frame(height: 1)

                Text(label)
                    .font(DSTypography.caption)
                    .foregroundColor(DSColors.textTertiary)

                Rectangle()
                    .fill(DSColors.border)
                    .frame(height: 1)
            }
        } else {
            Rectangle()
                .fill(DSColors.border)
                .frame(height: 1)
        }
    }
}

// MARK: - Glassmorphism Effects

/// Visual Effect Blur for macOS
struct DSVisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

/// Glassmorphism style modifier for modals and floating panels
struct DSGlassmorphism: ViewModifier {
    enum Style {
        case light
        case medium
        case heavy
        case ultraThin

        var material: NSVisualEffectView.Material {
            switch self {
            case .ultraThin: return .hudWindow
            case .light: return .popover
            case .medium: return .menu
            case .heavy: return .sidebar
            }
        }

        var overlayOpacity: Double {
            switch self {
            case .ultraThin: return 0.3
            case .light: return 0.5
            case .medium: return 0.6
            case .heavy: return 0.75
            }
        }
    }

    let style: Style
    let cornerRadius: CGFloat

    init(_ style: Style = .medium, cornerRadius: CGFloat = DSRadius.xl) {
        self.style = style
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    DSVisualEffectBlur(material: style.material, blendingMode: .behindWindow)

                    // Subtle gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

/// Modal background with glassmorphism
struct DSModalBackground: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = DSRadius.xl) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base vibrancy
                    DSVisualEffectBlur(material: .popover, blendingMode: .behindWindow)

                    // Subtle color tint
                    Color(NSColor.windowBackgroundColor)
                        .opacity(0.85)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DSColors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
    }
}

/// Frosted card style with subtle blur
struct DSFrostedCard: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(cornerRadius: CGFloat = DSRadius.md, padding: CGFloat = DSSpacing.lg) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    DSVisualEffectBlur(material: .contentBackground, blendingMode: .withinWindow)

                    Color(NSColor.controlBackgroundColor)
                        .opacity(0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DSColors.borderSubtle, lineWidth: 1)
            )
    }
}

// MARK: - Glassmorphism View Extensions

extension View {
    /// Apply glassmorphism effect
    func dsGlass(_ style: DSGlassmorphism.Style = .medium, cornerRadius: CGFloat = DSRadius.xl) -> some View {
        modifier(DSGlassmorphism(style, cornerRadius: cornerRadius))
    }

    /// Apply modal background with glass effect
    func dsModalBackground(cornerRadius: CGFloat = DSRadius.xl) -> some View {
        modifier(DSModalBackground(cornerRadius: cornerRadius))
    }

    /// Apply frosted card style
    func dsFrostedCard(cornerRadius: CGFloat = DSRadius.md, padding: CGFloat = DSSpacing.lg) -> some View {
        modifier(DSFrostedCard(cornerRadius: cornerRadius, padding: padding))
    }
}


// MARK: - Preview Provider
#if DEBUG
struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DSSpacing.xl) {
            // Typography
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Display Large").font(DSTypography.displayLarge)
                Text("Heading 1").font(DSTypography.heading1)
                Text("Body Text").font(DSTypography.body)
                Text("Code Sample").font(DSTypography.code)
                Text("Caption").font(DSTypography.caption)
            }

            Divider()

            // Buttons
            HStack(spacing: DSSpacing.md) {
                Button("Primary") {}
                    .buttonStyle(DSButtonStyle(.primary))

                Button("Secondary") {}
                    .buttonStyle(DSButtonStyle(.secondary))

                Button("Destructive") {}
                    .buttonStyle(DSButtonStyle(.destructive))
            }

            Divider()

            // Badges
            HStack(spacing: DSSpacing.sm) {
                Text("Neutral").dsBadge(.neutral)
                Text("Primary").dsBadge(.primary)
                Text("Success").dsBadge(.success)
                Text("Warning").dsBadge(.warning)
            }

            Divider()

            // Components
            DSShortcutBadge(keys: ["Cmd", "Ctrl", "S"])

            DSEmptyState(
                icon: "doc.text",
                title: "No Snippets",
                description: "Create your first snippet to get started",
                action: {},
                actionLabel: "Create Snippet"
            )
        }
        .padding(DSSpacing.xxl)
        .frame(width: 500, height: 600)
    }
}
#endif
