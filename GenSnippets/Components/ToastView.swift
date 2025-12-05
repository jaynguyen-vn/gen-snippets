import SwiftUI

enum ToastType {
    case success
    case error
    case info
    case warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return DSColors.success
        case .error: return DSColors.error
        case .info: return DSColors.info
        case .warning: return DSColors.warning
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success: return DSColors.successBackground
        case .error: return DSColors.errorBackground
        case .info: return DSColors.infoBackground
        case .warning: return DSColors.warningBackground
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: Double

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: Toast
    @Binding var isPresented: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(toast.type.backgroundColor)
                    .frame(width: 32, height: 32)

                Image(systemName: toast.type.icon)
                    .font(.system(size: DSIconSize.md))
                    .foregroundColor(toast.type.color)
            }

            Text(toast.message)
                .font(DSTypography.label)
                .foregroundColor(DSColors.textPrimary)

            Spacer()

            Button(action: {
                withAnimation(DSAnimation.easeOut) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: DSIconSize.xs, weight: .semibold))
                    .foregroundColor(DSColors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isHovered ? DSColors.hoverBackground : Color.clear)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(DSAnimation.easeOut) {
                    isHovered = hovering
                }
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .fill(DSColors.surface)
                .shadow(color: DSShadow.md.color, radius: DSShadow.md.radius, x: DSShadow.md.x, y: DSShadow.md.y)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColors.borderSubtle, lineWidth: 1)
        )
        .overlay(
            // Accent line on left
            HStack {
                RoundedRectangle(cornerRadius: DSRadius.xs)
                    .fill(toast.type.color)
                    .frame(width: 3)
                    .padding(.vertical, DSSpacing.sm)
                Spacer()
            }
        )
        .frame(maxWidth: 420)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                withAnimation(DSAnimation.springNormal) {
                    isPresented = false
                }
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                if let toast = toast {
                    ToastView(toast: toast, isPresented: Binding(
                        get: { self.toast != nil },
                        set: { if !$0 { self.toast = nil } }
                    ))
                    .padding(.top, DSSpacing.massive)
                    .padding(.horizontal, DSSpacing.lg)
                }

                Spacer()
            }
            .animation(DSAnimation.springNormal, value: toast)
        }
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var currentToast: Toast?

    func show(_ type: ToastType, message: String, duration: Double = 3.0) {
        DispatchQueue.main.async {
            self.currentToast = Toast(type: type, message: message, duration: duration)
        }
    }

    func showSuccess(_ message: String) {
        show(.success, message: message)
    }

    func showError(_ message: String) {
        show(.error, message: message)
    }

    func showInfo(_ message: String) {
        show(.info, message: message)
    }

    func showWarning(_ message: String) {
        show(.warning, message: message)
    }
}
