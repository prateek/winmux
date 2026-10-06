import AppKit

enum TileKind: String, CaseIterable, Sendable {
    case card, picture, text

    static func resolve(configured: String?, presentation: String) -> Self {
        if presentation == "miniatures" { return .picture }
        return configured.flatMap(Self.init(rawValue:)) ?? (presentation == "list" ? .text : .card)
    }
}

struct TileBadges: Equatable {
    var workspaceLabel: String?
    var onFocusedWorkspace: Bool
    var floating = false
    var minimized = false
    var hidden = false

    func chips(enabled: Bool) -> [String] {
        guard enabled else { return [] }
        return [!onFocusedWorkspace ? workspaceLabel : nil,
                floating ? "floating" : nil, minimized ? "minimized" : nil, hidden ? "hidden" : nil].compactMap { $0 }
    }
}

struct TileMetrics {
    let scale: CGFloat
    init(visibleSize: CGSize) { scale = min(max(1, visibleSize.width) / 1920, max(1, visibleSize.height) / 1080) }
    init(scale: CGFloat) { self.scale = scale }
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
        let picture = max(70 * scale, min(3.6, max(0.3, aspect)) * rowHeight)
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


}

struct TileEntry {
    var icon: NSImage?
    var title: String
    var appName: String
    var picture: WindowThumbnail?
    var aspect: CGFloat = 4 / 3
    var realSize = CGSize(width: 800, height: 600)
    var badges = TileBadges(workspaceLabel: nil, onFocusedWorkspace: true)
    var frozen = false
    var accessory = false
    var monitorHeightFraction: CGFloat = 1
    var appCount: Int?

    var displayTitle: String { title.isEmpty ? appName : title }
    var footerAppName: String? { displayTitle == appName ? nil : appName }

    func chips(enabled: Bool, includeWorkspace: Bool = true) -> [String] {
        var badges = badges
        if !includeWorkspace { badges.onFocusedWorkspace = true }
        return badges.chips(enabled: enabled) + (appCount.map { ["\($0) windows"] } ?? [])
    }
}
