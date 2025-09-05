import SwiftUI

struct MinimalCircleButton: View {
    let symbol: String
    let accessibilityLabel: String
    let isDark: Bool
    let action: () -> Void
    @State private var hovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDark ? .white : .black)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill((isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                        .overlay(
                            Circle()
                                .stroke((isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(isDark ? 0.4 : 0.15), radius: hovering ? 4 : 2, y: 1)
                )
                .scaleEffect(hovering ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: hovering)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .onHover { hovering = $0 }
    }
}
