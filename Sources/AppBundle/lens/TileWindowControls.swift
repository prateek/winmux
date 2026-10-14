import AppKit

enum TileWindowControl: String, CaseIterable, Sendable {
    case close, minimize, fullscreen
    var command: String {
        switch self {
            case .close: "close"
            case .minimize: "macos-native-minimize"
            case .fullscreen: "macos-native-fullscreen"
        }
    }
}

struct TileControlAvailability: Equatable, Sendable {
    var close = false
    var minimize = false
    var fullscreen = false
    static let all = Self(close: true, minimize: true, fullscreen: true)
    func allows(_ control: TileWindowControl) -> Bool {
        switch control {
            case .close: close
            case .minimize: minimize
            case .fullscreen: fullscreen
        }
    }
}

func tileFittedPicture(entry: TileEntry, available: CGSize, pictureSize: CGSize?, metrics: TileMetrics,
                       presentation: String, selected: Bool, line: Bool) -> CGSize {
    guard let pictureSize else { return metrics.fittedPicture(aspect: entry.aspect, in: available) }
    if presentation == "miniatures" || presentation == "strip" && entry.accessory { return pictureSize }
    let lift = selected && !line ? metrics.selectionScale : 1
    let factor = min(1, entry.realSize.width / max(1, pictureSize.width * lift), entry.realSize.height / max(1, pictureSize.height * lift))
    return CGSize(width: pictureSize.width * factor, height: pictureSize.height * factor)
}

func tilePictureRect(entry: TileEntry, kind: TileKind, size: CGSize, pictureSize: CGSize?, metrics: TileMetrics,
                     presentation: String, selected: Bool) -> CGRect {
    let bar = kind == .card ? metrics.barHeight + metrics.gap : 0
    let available = CGSize(width: max(1, size.width - 2 * metrics.padding), height: max(1, size.height - 2 * metrics.padding - bar))
    let fitted = tileFittedPicture(entry: entry, available: available, pictureSize: pictureSize, metrics: metrics,
                                  presentation: presentation, selected: selected, line: false)
    return CGRect(x: (size.width - fitted.width) / 2,
                  y: metrics.padding + bar + (available.height - fitted.height) / 2,
                  width: fitted.width, height: fitted.height)
}

func tileControlRects(in picture: CGRect, scale: CGFloat) -> [(TileWindowControl, CGRect)] {
    guard scale > 0 else { return [] }
    let fit = min(1, picture.width / (76 * scale))
    let diameter = 16 * scale * fit
    guard diameter >= 10 else { return [] }
    let inset = 8 * scale * fit, gap = 6 * scale * fit
    return TileWindowControl.allCases.enumerated().map { index, control in
        (control, CGRect(x: picture.minX + inset + CGFloat(index) * (diameter + gap),
                         y: picture.minY + inset, width: diameter, height: diameter))
    }
}

func scaledTileRect(_ rect: CGRect, about tile: CGRect, by scale: CGFloat) -> CGRect {
    CGRect(x: tile.midX + (rect.minX - tile.midX) * scale, y: tile.midY + (rect.minY - tile.midY) * scale,
           width: rect.width * scale, height: rect.height * scale)
}
