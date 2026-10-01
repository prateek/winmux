// Throwaway harness for "Task: confirm the grid backdrop keeps Electron and Metal windows live".
// Derived from ../14-thumbnail-harness/main.swift (same capture call and the same changed-pixel measure).
// Build: swiftc -O -parse-as-library -framework ScreenCaptureKit -framework AppKit main.swift -o harness
// Modes: list | cover <alpha 0..1> <fill 0|1|2> <opaque 0|1> <windowID>...
// fill 0: the black is the window background colour. 1: NSVisualEffectView (behind-window blur) with a black layer over it.
// 2: clear window background with the same black layer and no blur.| cover <alpha 0..1> <blur 0|1> <opaque 0|1> <windowID>...
// A cover run puts one full-screen cover over the main display and measures every listed window under it.
// The process exits after 45 s whatever happens, which removes the cover.
import AppKit
import ScreenCaptureKit

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e6 }

func fetchContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
}

func appWindows(_ c: SCShareableContent) -> [SCWindow] {
    let regular = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
    return c.windows.filter {
        $0.windowLayer == 0 && $0.frame.width >= 100 && $0.frame.height >= 100
            && ($0.isOnScreen || !($0.title ?? "").isEmpty) && regular.contains($0.owningApplication?.processID ?? -1)
    }
}

func config(width: Int, height: Int) -> SCStreamConfiguration {
    let cfg = SCStreamConfiguration()
    cfg.width = width
    cfg.height = height
    cfg.showsCursor = false
    cfg.ignoreShadowsSingleWindow = true
    return cfg
}

func capture(_ w: SCWindow) async throws -> [UInt8] {
    let cfg = config(width: 320, height: max(1, Int(320 * w.frame.height / w.frame.width)))
    return rgba(try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg))
}

// Mean brightness (0-255) of the composited display, cover included: how dark the screen really is.
func displayLuma(_ d: SCDisplay) async throws -> Double {
    let cfg = config(width: 320, height: max(1, 320 * d.height / d.width))
    let px = rgba(try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: d, excludingWindows: []), configuration: cfg))
    var sum = 0
    for i in stride(from: 0, to: px.count, by: 4) { sum += Int(px[i]) + Int(px[i+1]) + Int(px[i+2]) }
    return Double(sum) / Double(px.count / 4 * 3)
}

func rgba(_ img: CGImage, w: Int = 320) -> [UInt8] {
    let h = max(1, img.height * w / max(1, img.width))
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}

func diff(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return -1 }
    var d = 0
    for i in stride(from: 0, to: a.count, by: 4) where abs(Int(a[i]) - Int(b[i])) + abs(Int(a[i+1]) - Int(b[i+1])) + abs(Int(a[i+2]) - Int(b[i+2])) > 12 { d += 1 }
    return Double(d) / Double(a.count / 4)
}

@MainActor func makeCover(alpha: Double, fill: Int, opaque: Bool) -> NSWindow {
    let win = NSWindow(contentRect: NSScreen.screens[0].frame, styleMask: .borderless, backing: .buffered, defer: false)
    win.isOpaque = opaque
    win.level = .floating
    win.hasShadow = false
    win.ignoresMouseEvents = true
    win.appearance = NSAppearance(named: .darkAqua)
    if fill > 0 {
        win.backgroundColor = .clear
        let fx = fill == 1 ? NSVisualEffectView(frame: win.contentLayoutRect) : NSView(frame: win.contentLayoutRect)
        if let fx = fx as? NSVisualEffectView {
            fx.blendingMode = .behindWindow
            fx.material = .hudWindow
            fx.state = .active
        }
        let dim = NSView(frame: fx.bounds)
        dim.autoresizingMask = [.width, .height]
        dim.wantsLayer = true
        dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(alpha).cgColor
        fx.addSubview(dim)
        win.contentView = fx
    } else {
        win.backgroundColor = opaque ? .black : NSColor.black.withAlphaComponent(alpha)
    }
    win.orderFrontRegardless()
    return win
}

func cover(alpha: Double, fill: Int, opaque: Bool, ids: [CGWindowID]) async throws {
    let c = try await fetchContent()
    let ws = ids.compactMap { id in c.windows.first { $0.windowID == id } }
    guard ws.count == ids.count, let display = c.displays.first else { print("error: window or display not found"); return }
    let names = ws.map { "\($0.owningApplication?.applicationName ?? "?")#\($0.windowID)" }
    print(String(format: "cell alpha=%.2f fill=%@ isOpaque=%@", alpha, ["window background", "blur + layer", "layer, no blur"][fill], opaque ? "yes" : "no"))
    for (w, n) in zip(ws, names) { print("target \(n) frame=\(w.frame) onScreen=\(w.isOnScreen)") }

    func pairs(_ label: String, gap: Double) async throws -> [Double] {
        var a: [[UInt8]] = []
        for w in ws { a.append(try await capture(w)) }
        try await Task.sleep(for: .seconds(gap))
        var out: [Double] = []
        for (i, w) in ws.enumerated() {
            let d = diff(a[i], try await capture(w))
            out.append(d)
            print(String(format: "%@ %@: changed=%.3f", names[i], label, d))
        }
        return out
    }

    let base = try await pairs("visible", gap: 2)
    print(String(format: "display luma uncovered: %.1f", try await displayLuma(display)))

    let win = await MainActor.run { makeCover(alpha: alpha, fill: fill, opaque: opaque) }
    let t0 = now()
    try await Task.sleep(for: .seconds(0.5))
    let frame = await MainActor.run { "\(win.frame) isOpaque=\(win.isOpaque) visible=\(win.isVisible) occlusionVisible=\(win.occlusionState.contains(.visible))" }
    print("cover frame=\(frame)")
    print(String(format: "display luma covered: %.1f", try await displayLuma(display)))
    try await Task.sleep(for: .seconds(max(0, 1 - (now() - t0) / 1000)))
    let early = try await pairs("covered 1-3s", gap: 2)
    try await Task.sleep(for: .seconds(max(0, 8 - (now() - t0) / 1000)))
    let late = try await pairs("covered 8-10s", gap: 2)

    var last: [[UInt8]] = []
    for w in ws { last.append(try await capture(w)) }
    await MainActor.run { win.orderOut(nil) }
    let t1 = now()
    var resumed = [Double?](repeating: nil, count: ws.count)
    var samples = 0
    while now() - t1 < 3000, resumed.contains(where: { $0 == nil }) {
        for (i, w) in ws.enumerated() where resumed[i] == nil {
            let px = try await capture(w)
            if diff(last[i], px) > base[i] * 0.5 { resumed[i] = now() - t1 }
        }
        samples += 1
    }
    for (i, n) in names.enumerated() {
        let live = { (d: Double) in d > base[i] * 0.5 ? "live" : (d < 0.002 ? "frozen" : "partial") }
        let r = resumed[i].map { String(format: "%.0f ms", $0) } ?? "none within 3000 ms"
        print("\(n) verdict: 1-3s \(live(early[i])), 8-10s \(live(late[i])); first changed frame after uncover: \(r) (\(samples) polls)")
    }
    _ = try await pairs("uncovered", gap: 1)
}

func list() async throws {
    for w in appWindows(try await fetchContent()) {
        print("\(w.windowID)\t\(w.owningApplication?.applicationName ?? "?")\t\(w.isOnScreen)\t\(w.frame)\t\(w.title ?? "")")
    }
}

@main struct Harness {
    static func main() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 45) { print("error: hard timeout, exiting to drop the cover"); exit(3) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        for s in NSScreen.screens { print("screen: \(s.localizedName) \(s.frame) scale=\(s.backingScaleFactor)") }
        Task {
            var code: Int32 = 0
            do {
                if args.count > 5, args[1] == "cover", let alpha = Double(args[2]), let fill = Int(args[3]), (0...2).contains(fill) {
                    try await cover(alpha: alpha, fill: fill, opaque: args[4] == "1", ids: args[5...].compactMap { CGWindowID($0) })
                } else {
                    try await list()
                }
            } catch { print("error: \(error)"); code = 1 }
            exit(code)
        }
        app.run()
    }
}
