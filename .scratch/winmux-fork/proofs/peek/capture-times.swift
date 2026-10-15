import AppKit
import Foundation

@main
struct CaptureTimes {
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        for pair in args {
            let fields = pair.split(separator: ":")
            let name = String(fields[0]), id = UInt32(fields[1])!
            let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
            if let row = rows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id }) {
                print("source app=\(name) bounds=\(row[kCGWindowBounds as String] ?? [:])")
            }
            _ = try await WindowScreenshot.capture(id, pixelSize: CGSize(width: 1280, height: 720))
            for size in [CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080)] {
                var samples: [Double] = []
                for _ in 0..<5 {
                    let start = ContinuousClock.now
                    let image = try await WindowScreenshot.capture(id, pixelSize: size)
                    let elapsed = start.duration(to: .now).components
                    let ms = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
                    samples.append(ms)
                    print("sample app=\(name) window=\(id) output=\(image.width)x\(image.height) ms=\(String(format: "%.3f", ms))")
                }
                let sorted = samples.sorted()
                print("result app=\(name) output=\(Int(size.width))x\(Int(size.height)) count=5 median=\(String(format: "%.3f", sorted[2]))ms range=\(String(format: "%.3f", sorted[0]))–\(String(format: "%.3f", sorted[4]))ms")
            }
        }
    }
}
