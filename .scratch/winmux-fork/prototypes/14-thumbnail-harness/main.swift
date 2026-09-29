// Throwaway harness for "Task: measure thumbnail capture on Prateek's machine".
// Build: swiftc -O -parse-as-library -framework ScreenCaptureKit -framework AppKit main.swift -o harness
// Modes: list | bench | stale <windowID> [strip]; env REPEAT=n (bench), TRANSLUCENT=1 (stale)
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

func capture(_ w: SCWindow, width: Int?) async throws -> CGImage {
    let cfg = SCStreamConfiguration()
    let scale = Double(NSScreen.screens.first?.backingScaleFactor ?? 2)
    let nw = Int(w.frame.width * scale), nh = Int(w.frame.height * scale)
    if let width {
        cfg.width = width
        cfg.height = max(1, Int(Double(width) * w.frame.height / w.frame.width))
    } else {
        cfg.width = nw; cfg.height = nh
    }
    cfg.showsCursor = false
    cfg.ignoreShadowsSingleWindow = true
    return try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg)
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

func uniform(_ a: [UInt8]) -> Double {
    guard a.count >= 4 else { return 1 }
    var same = 0
    for i in stride(from: 0, to: a.count, by: 4) where a[i] == a[0] && a[i+1] == a[1] && a[i+2] == a[2] { same += 1 }
    return Double(same) / Double(a.count / 4)
}

func stats(_ xs: [Double]) -> String {
    let s = xs.sorted()
    guard !s.isEmpty else { return "n=0" }
    let p = { (q: Double) in s[min(s.count - 1, Int(Double(s.count - 1) * q))] }
    return String(format: "n=%d min=%.1f p50=%.1f p90=%.1f max=%.1f ms", s.count, s[0], p(0.5), p(0.9), s.last!)
}

func runBatch(_ ws: [SCWindow], width: Int?, inFlight: Int) async -> (total: Double, per: [Double], fails: Int) {
    let t0 = now()
    var per: [Double] = [], fails = 0
    await withTaskGroup(of: Double?.self) { g in
        var it = ws.makeIterator(), running = 0
        func add() -> Bool {
            guard let w = it.next() else { return false }
            g.addTask { let s = now(); return (try? await capture(w, width: width)) != nil ? now() - s : nil }
            return true
        }
        while running < inFlight, add() { running += 1 }
        while let r = await g.next() {
            if let r { per.append(r) } else { fails += 1 }
            _ = add()
        }
    }
    return (now() - t0, per, fails)
}

func bench() async throws {
    var t = now()
    let c = try await fetchContent()
    print(String(format: "content fetch cold: %.1f ms (%d SCWindows)", now() - t, c.windows.count))
    for _ in 0..<3 { t = now(); _ = try await fetchContent(); print(String(format: "content fetch warm: %.1f ms", now() - t)) }
    let base = appWindows(c)
    let reps = Int(ProcessInfo.processInfo.environment["REPEAT"] ?? "1") ?? 1
    let ws = Array(repeating: base, count: reps).flatMap { $0 }
    print("app windows (x\(reps)): \(ws.count)")
    for w in ws { print("  \(w.windowID) \(w.owningApplication?.applicationName ?? "?") onScreen=\(w.isOnScreen) \(Int(w.frame.width))x\(Int(w.frame.height)) \(w.title ?? "")") }
    guard let first = ws.first else { return }
    t = now(); _ = try await capture(first, width: 320); print(String(format: "first capture (cold): %.1f ms", now() - t))
    for width in (reps > 1 ? [320] : [320, nil]) as [Int?] {
        for inFlight in (reps > 1 ? [1, 2, 4] : [1, 2, 4, 8]) {
            for rep in 0..<3 {
                let r = await runBatch(ws, width: width, inFlight: inFlight)
                print(String(format: "width=%@ inFlight=%d rep=%d total=%.1f ms fails=%d per: %@",
                             width.map(String.init) ?? "native", inFlight, rep, r.total, r.fails, stats(r.per)))
            }
        }
    }
}

@MainActor func makeOccluder(_ frameTopLeft: CGRect, leaveStrip: Bool) -> NSWindow {
    let screenH = NSScreen.screens[0].frame.height
    var r = CGRect(x: frameTopLeft.minX - 4, y: screenH - frameTopLeft.maxY - 4, width: frameTopLeft.width + 8, height: frameTopLeft.height + 8)
    if leaveStrip { r.origin.x += 5; r.size.width -= 5 } // leaves the window's leftmost pixel column uncovered
    let win = NSWindow(contentRect: r, styleMask: .borderless, backing: .buffered, defer: false)
    let translucent = ProcessInfo.processInfo.environment["TRANSLUCENT"] != nil
    win.isOpaque = !translucent
    win.backgroundColor = translucent ? NSColor.black.withAlphaComponent(0.85) : .black
    win.level = .floating
    win.hasShadow = false
    win.ignoresMouseEvents = true
    win.orderFrontRegardless()
    return win
}

func stale(_ id: CGWindowID, strip: Bool) async throws {
    func grab() async throws -> ([UInt8], String) {
        let c = try await fetchContent()
        guard let w = c.windows.first(where: { $0.windowID == id }) else { throw NSError(domain: "no window", code: 1) }
        return (rgba(try await capture(w, width: 320)), w.title ?? "")
    }
    func pair(_ label: String, gap: Double = 2.0) async throws {
        let (a, ta) = try await grab()
        try await Task.sleep(for: .seconds(gap))
        let (b, tb) = try await grab()
        print(String(format: "%@: changed=%.3f uniform=%.3f title=[%@] -> [%@]", label, diff(a, b), uniform(b), ta, tb))
    }
    let c = try await fetchContent()
    guard let w = c.windows.first(where: { $0.windowID == id }) else { print("window \(id) not found"); return }
    print("target \(id) \(w.owningApplication?.applicationName ?? "?") frame=\(w.frame) strip=\(strip)")
    try await pair("visible")
    let occ = await MainActor.run { makeOccluder(w.frame, leaveStrip: strip) }
    try await Task.sleep(for: .seconds(1))
    try await pair("occluded 1-3s")
    try await Task.sleep(for: .seconds(5))
    try await pair("occluded 8-10s")
    let (occLast, _) = try await grab()
    await MainActor.run { occ.orderOut(nil) }
    try await Task.sleep(for: .seconds(0.3))
    let (after, _) = try await grab()
    print(String(format: "uncovered +0.3s vs last occluded: changed=%.3f", diff(occLast, after)))
    try await Task.sleep(for: .seconds(1))
    try await pair("uncovered 1.3-3.3s")
}

func list() async throws {
    for w in appWindows(try await fetchContent()) {
        print("\(w.windowID)\t\(w.owningApplication?.applicationName ?? "?")\t\(w.isOnScreen)\t\(w.frame)\t\(w.title ?? "")")
    }
}

@main struct Harness {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        for s in NSScreen.screens { print("screen: \(s.localizedName) \(s.frame) scale=\(s.backingScaleFactor)") }
        Task {
            do {
                switch args.dropFirst().first {
                case "bench": try await bench()
                case "stale": try await stale(CGWindowID(args[2])!, strip: args.count > 3)
                default: try await list()
                }
            } catch { print("error: \(error)") }
            exit(0)
        }
        app.run()
    }
}
