import Common
import Foundation

struct TilingSplitFrame {
    let physical: CGRect
    let virtual: CGRect
    let weight: CGFloat
}

func tilingSplitFrames(in rect: CGRect, virtual: CGRect, weights: [CGFloat], orientation: Orientation, gap: CGFloat) -> [TilingSplitFrame] {
    guard !weights.isEmpty else { return [] }
    let length = orientation == .h ? rect.size.width : rect.size.height
    let delta = (length - weights.reduce(0, +)) / CGFloat(weights.count)
    var offset: CGFloat = 0
    return weights.enumerated().map { index, weight in
        let weight = weight + delta
        let before = index == 0 ? 0 : gap / 2
        let after = index == weights.count - 1 ? 0 : gap / 2
        let physical = CGRect(x: rect.origin.x + (orientation == .h ? offset + before : 0),
                              y: rect.origin.y + (orientation == .v ? offset + before : 0),
                              width: orientation == .h ? weight - before - after : rect.size.width,
                              height: orientation == .v ? weight - before - after : rect.size.height)
        let virtual = CGRect(x: virtual.origin.x + (orientation == .h ? offset : 0),
                             y: virtual.origin.y + (orientation == .v ? offset : 0),
                             width: orientation == .h ? weight : rect.size.width,
                             height: orientation == .v ? weight : rect.size.height)
        offset += weight
        return TilingSplitFrame(physical: physical, virtual: virtual, weight: weight)
    }
}
