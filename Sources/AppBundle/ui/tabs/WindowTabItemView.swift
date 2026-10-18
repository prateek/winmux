import SwiftUI

struct WindowTabItemView: View {
    let tab: WindowTabItemViewModel
    let width: CGFloat
    let height: CGFloat
    let isDragSource: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 6) {
            appIcon(size: 14)

            Text(tab.title)
                .font(.system(size: 12, weight: tab.isActive ? .semibold : .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask { titleFadeMask }
        }
        .foregroundStyle(tabForegroundStyle)
        .padding(.horizontal, windowTabItemHorizontalPadding)
        .frame(width: width, height: height, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: windowTabStripInnerCornerRadius, style: .continuous)
                .fill(Color.white.opacity(tab.isActive ? GlassToken.fillActive : GlassToken.fillFaint))
        }
        .overlay {
            RoundedRectangle(cornerRadius: windowTabStripInnerCornerRadius, style: .continuous)
                .stroke(tabStrokeStyle, lineWidth: StrokeToken.control)
        }
        .opacity(isDragSource ? 0.55 : 1.0)
        .contentShape(Rectangle())
    }

    var tabForegroundStyle: Color {
        if tab.isActive { return Color.white.opacity(GlassToken.textPrimary) }
        if isDragSource { return Color.white.opacity(GlassToken.textSecondary) }
        return Color.white.opacity(isHovered ? GlassToken.textSecondary : GlassToken.textTertiary)
    }

    private var tabStrokeStyle: Color {
        if tab.isActive { return Color.white.opacity(GlassToken.strokeActive) }
        return Color.white.opacity(isHovered ? GlassToken.strokeHover : GlassToken.strokeResting)
    }
}

/// The part of the title's frame the close button covers, which the title leaves clear. The title
/// fades out before it instead of reflowing, so hovering does not move text.
func closeButtonTitleClearWidth(isActive: Bool, isHovered: Bool) -> CGFloat {
    guard isActive || isHovered else { return 0 }
    return windowTabCloseButtonSize + windowTabCloseButtonTrailingInset - windowTabItemHorizontalPadding
}

extension WindowTabItemView {
    var titleFadeMask: some View {
        let clear = closeButtonTitleClearWidth(isActive: tab.isActive, isHovered: isHovered)
        return HStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: clear > 0 ? windowTabTitleFadeGradientWidth : 0)
            Color.clear.frame(width: clear)
        }
    }
}
