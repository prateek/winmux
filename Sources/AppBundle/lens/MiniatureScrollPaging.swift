import AppKit

struct MiniatureScrollPaging {
    private var delta: CGFloat = 0
    private var turned = false

    mutating func turn(delta incoming: CGFloat, phase: NSEvent.Phase, momentum: NSEvent.Phase) -> Int? {
        guard momentum.isEmpty else { return nil }
        if phase.isEmpty { return incoming == 0 ? nil : (incoming < 0 ? 1 : -1) }
        if phase.contains(.began) { delta = 0; turned = false }
        guard !turned else { return nil }
        delta += incoming
        guard abs(delta) >= 1 else { return nil }
        turned = true
        return delta < 0 ? 1 : -1
    }
}
