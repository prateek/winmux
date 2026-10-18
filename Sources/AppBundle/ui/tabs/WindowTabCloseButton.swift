import SwiftUI

struct WindowTabCloseButton: View {
    let title: String
    let foreground: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 20, height: 20)
                .background(Circle().fill(foreground.opacity(isHovered ? 0.18 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close \(title)")
        .onHover { isHovered = $0 }
        .padding(.trailing, 5)
    }
}
