import Foundation

struct ThumbnailAppearance {
    let opacity: Double
    let saturation: Double
    let brightness: Double
    let badge: String?

    init(frozen: Bool, look: String, capturedAt: Date?, now: Date) {
        opacity = frozen && look == "dimmed" ? 0.5 : 1
        saturation = frozen && look == "age-badge" ? 0.35 : 1
        brightness = frozen && look == "age-badge" ? 0.85 : 1
        if frozen && look == "pause-badge" { badge = "pause" }
        else if frozen && look == "age-badge", let capturedAt { badge = "\(Int(max(0, now.timeIntervalSince(capturedAt))))s" }
        else { badge = nil }
    }
}
