import SwiftUI

struct ModernButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? Color.red.opacity(0.8) : Color.red
        } else if isPrimary {
            return isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor
        } else {
            return isPressed ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        if isDestructive || isPrimary {
            return .white
        } else {
            return .primary
        }
    }
}

