import AppKit
import ScreenCaptureKit

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e6 }

func fetchContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
}

func appWindows(_ c: SCShareableContent) -> [SCWindow] {
    return c.windows.filter { $0.owningApplication?.applicationName == "NeutralDemo" && $0.windowLayer == 0 && $0.frame.width >= 100 && $0.frame.height >= 100 }
}

func capture(_ w: SCWindow, width: Int?) async throws -> CGImage {
    let cfg = SCScreenshotConfiguration()
    let scale = Double(NSScreen.screens.first?.backingScaleFactor ?? 2)
    let nw = Int(w.frame.width * scale), nh = Int(w.frame.height * scale)
    if let width {
        cfg.width = width
        cfg.height = max(1, Int(Double(width) * w.frame.height / w.frame.width))
    } else {
        cfg.width = nw; cfg.height = nh
    }
    cfg.showsCursor = false
    cfg.ignoreShadows = true
    cfg.includeChildWindows = false
    cfg.dynamicRange = .sdr
    return try await SCScreenshotManager.captureScreenshot(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg).sdrImage!
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
    let ws = appWindows(c).sorted { $0.windowID < $1.windowID }
    print("distinct owned app windows: \(ws.count)")
    guard ws.count == 50 else { print("Wait for exactly 50 owned windows before benchmarking"); return }
    for w in ws { print("  \(w.windowID) \(w.owningApplication?.applicationName ?? "?") onScreen=\(w.isOnScreen) \(Int(w.frame.width))x\(Int(w.frame.height)) \(w.title ?? "")") }
    guard let first = ws.first else { return }
    t = now(); _ = try await capture(first, width: 320); print(String(format: "first capture (cold): %.1f ms", now() - t))
    for width in [320, nil] as [Int?] {
        for inFlight in [1, 2] {
            for rep in 0..<3 {
                let r = await runBatch(ws, width: width, inFlight: inFlight)
                print(String(format: "width=%@ inFlight=%d rep=%d total=%.1f ms fails=%d per: %@",
                             width.map(String.init) ?? "native", inFlight, rep, r.total, r.fails, stats(r.per)))
            }
        }
    }
}

@main struct Harness {
    static func main() {
        guard CGPreflightScreenCaptureAccess() else { print("No existing capture grant; not requesting permission"); return }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        for s in NSScreen.screens { print("screen: \(s.frame.size) scale=\(s.backingScaleFactor)") }
        Task {
            do {
                try await bench()
            } catch { print("error: \(error)") }
            exit(0)
        }
        app.run()
    }
}
