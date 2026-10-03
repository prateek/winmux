import AppKit

/// Turns scroll events into page turns: one per trackpad gesture, one per burst of wheel events.
struct MiniatureScrollPaging {
    private var delta: CGFloat = 0
    private var sideways: CGFloat = 0
    private var turned = false
    private var lastWheelEvent: TimeInterval = -.infinity

    mutating func turn(delta incoming: CGFloat, sideways incomingSideways: CGFloat = 0, phase: NSEvent.Phase, momentum: NSEvent.Phase, time: TimeInterval) -> Int? {
        guard momentum.isEmpty else { return nil }
        if phase.isEmpty {
            // A wheel has no gesture phases. A smooth-scrolling wheel sends a run of small events
            // for one flick, so the events of one run turn one page.
            guard incoming != 0 else { return nil }
            defer { lastWheelEvent = time }
            return time - lastWheelEvent < 0.2 ? nil : (incoming < 0 ? 1 : -1)
        }
        if phase.contains(.began) { delta = 0; sideways = 0; turned = false }
        guard !turned else { return nil }
        delta += incoming
        sideways += incomingSideways
        guard abs(delta) >= 4, abs(delta) > abs(sideways) else { return nil }
        turned = true
        return delta < 0 ? 1 : -1
    }
}
