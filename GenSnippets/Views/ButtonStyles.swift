import SwiftUI

// Legacy ModernButtonStyle - kept for backwards compatibility
// New code should use DSButtonStyle from DesignSystem.swift
struct ModernButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.label)
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DSAnimation.springQuick, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? DSColors.error.opacity(0.85) : DSColors.error
        } else if isPrimary {
            return isPressed ? DSColors.accentPressed : DSColors.accent
        } else {
            return isPressed ? DSColors.hoverBackground : DSColors.surfaceSecondary
        }
    }

    private var foregroundColor: Color {
        if isDestructive || isPrimary {
            return .white
        } else {
            return DSColors.textPrimary
        }
    }
}

