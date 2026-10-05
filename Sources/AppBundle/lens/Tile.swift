import AppKit

enum TileKind: String, CaseIterable, Sendable {
    case card, picture, text

    static func resolve(configured: String?, override: String?, presentation: String) -> Self {
        if presentation == "miniatures" { return .picture }
        return (override ?? configured).flatMap(Self.init(rawValue:)) ?? (presentation == "list" ? .text : .card)
    }
}

struct TileBadges: Equatable {
    var workspaceNumber: Int?
    var onFocusedWorkspace: Bool
    var floating = false
    var minimized = false
    var hidden = false

    func chips(enabled: Bool) -> [String] {
        guard enabled else { return [] }
        return [!onFocusedWorkspace ? workspaceNumber.map(String.init) : nil,
                floating ? "floating" : nil, minimized ? "minimized" : nil, hidden ? "hidden" : nil].compactMap { $0 }
    }
}

struct TileMetrics {
    let scale: CGFloat
    init(visibleHeight: CGFloat) { scale = max(1, visibleHeight) / 1080 }
    var padding: CGFloat { 10 * scale }
    var gap: CGFloat { 8 * scale }
    var radius: CGFloat { 14 * scale }
    var barHeight: CGFloat { 28 * scale }
    var icon: CGFloat { 26 * scale }
    var titleFont: CGFloat { 17 * scale }
    var appFont: CGFloat { 14 * scale }
    var chipFont: CGFloat { 12 * scale }
    var chipVerticalPadding: CGFloat { 2 * scale }
    var chipHorizontalPadding: CGFloat { 7 * scale }
    var chipRadius: CGFloat { 6 * scale }
    var pictureRadius: CGFloat { 7 * scale }
    var selectionScale: CGFloat { 1.045 }
    var selectionRing: CGFloat { 2.5 * scale }
    var textHeight: CGFloat { 46 * scale }
    var textWidth: CGFloat { 330 * scale }
    var textRadius: CGFloat { 10 * scale }
    var listPictureHeight: CGFloat { 74 * scale }
    var listPictureWidth: CGFloat { 96 * scale }
    var miniatureRadius: CGFloat { 5 * scale }
    var miniatureIcon: CGFloat { 22 * scale }
    var miniatureRing: CGFloat { 4 * scale }
    var stripGap: CGFloat { 14 * scale }
    var rowGap: CGFloat { 14 * scale }
    var rowHorizontalPadding: CGFloat { 12 * scale }
    var rowVerticalPadding: CGFloat { 6 * scale }
    var chipGap: CGFloat { 5 * scale }
    var labelVerticalPadding: CGFloat { 3 * scale }
    var labelHorizontalPadding: CGFloat { 8 * scale }
    var pictureIcon: CGFloat { 30 * scale }
    var pictureIconInset: CGFloat { 6 * scale }
    var miniatureIconInset: CGFloat { 4 * scale }
    var miniaturePictureRadius: CGFloat { 4 * scale }
    var adornmentGap: CGFloat { 4 * scale }
    var pictureShadowRadius: CGFloat { 9 * scale }
    var pictureShadowY: CGFloat { 6 * scale }
    var iconShadowRadius: CGFloat { 2 * scale }
    var iconShadowY: CGFloat { 2 * scale }
    var selectionShadowRadius: CGFloat { 20 * scale }
    var selectionShadowY: CGFloat { 18 * scale }
    var miniatureShadowRadius: CGFloat { 15 * scale }
    var miniatureShadowY: CGFloat { 10 * scale }
    var accessoryPictureFloor: CGFloat { 28 * scale }

    func pictureHeight(rowHeight: CGFloat, accessory: Bool, actualSize: Bool, monitorHeightFraction: CGFloat) -> CGFloat {
        accessory && actualSize ? min(rowHeight, max(accessoryPictureFloor, rowHeight * monitorHeightFraction)) : rowHeight
    }

    func width(kind: TileKind, aspect: CGFloat, rowHeight: CGFloat) -> CGFloat {
        if kind == .text { return textWidth }
        let picture = max(70 * scale, max(0.01, aspect) * rowHeight)
        let titleFloor = kind == .card ? min(200 * scale, max(1.2 * rowHeight, 110 * scale)) : 0
        return max(picture, titleFloor) + 2 * padding
    }

    func height(kind: TileKind, rowHeight: CGFloat) -> CGFloat {
        kind == .text ? textHeight : rowHeight + 2 * padding + (kind == .card ? barHeight + gap : 0)
    }

    func fittedPicture(aspect: CGFloat, in size: CGSize) -> CGSize {
        let aspect = max(0.01, aspect)
        let height = min(size.height, size.width / aspect)
        return CGSize(width: max(1, height * aspect), height: max(1, height))
    }

    func stripRowHeight(aspects: [CGFloat], kind: TileKind, availableWidth: CGFloat) -> CGFloat {
        let capacity = min(9, aspects.count)
        guard capacity > 0, kind != .text else { return 190 * scale }
        let available = max(1, availableWidth * 0.9 - 88 * scale)
        for height in stride(from: 190, through: 40, by: -6) {
            let widths = aspects.map { width(kind: kind, aspect: $0, rowHeight: CGFloat(height) * scale) }
            var widest: CGFloat = 0
            for start in 0 ... (widths.count - capacity) {
                let total = widths[start ..< start + capacity].reduce(CGFloat.zero, +)
                widest = max(widest, total + CGFloat(capacity - 1) * stripGap)
            }
            if widest <= available { return CGFloat(height) * scale }
        }
        return 36 * scale
    }
}

struct TileEntry {
    var icon: NSImage?
    var title: String
    var appName: String
    var picture: WindowThumbnail?
    var aspect: CGFloat = 4 / 3
    var badges = TileBadges(workspaceNumber: nil, onFocusedWorkspace: true)
    var frozen = false
    var accessory = false
    var monitorHeightFraction: CGFloat = 1
    var appCount: Int?
}
