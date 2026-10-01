// Swift caller for the spike: typed Swift values -> JSON -> Rust -> Nickel, in-process (C ABI)
// and through a helper process (`spike config serve`). Enum-valued fields carry a leading `'`.
import Foundation

struct App: Codable { let bundleId: String; let name: String; let pid: Int }
struct Frame: Codable { let x: Double; let y: Double; let w: Double; let h: Double }
struct Window: Codable {
    let id: Int; let title: String; let app: App; let `class`: String
    let workspace: String; let project: String; let frame: Frame; let lastFocusedSeq: Int
}
struct Workspace: Codable { let name: String; let project: String }
struct Ctx: Codable { let focused: Window?; let workspace: Workspace; let profile: String }
struct Col: Codable { let index: Int; let empty: Bool; let windows: [Int] }

let apps = [("com.apple.mail", "Mail"), ("com.mitchellh.ghostty", "Ghostty"),
            ("com.google.Chrome", "Google Chrome"), ("com.tinyspeck.slackmacgap", "Slack"),
            ("com.microsoft.VSCode", "Code")]
func window(_ i: Int) -> Window {
    let (b, n) = apps[i % apps.count]
    return Window(id: 1000 + i, title: "Window \(i) — some document title",
                  app: App(bundleId: b, name: n, pid: 400 + i % 5),
                  class: i % 7 == 0 ? "'floating" : "'tiling", workspace: "\(i % 4)",
                  project: i % 2 == 0 ? "winmux" : "dotfiles",
                  frame: Frame(x: 10.5 * Double(i), y: 20, w: 800, h: 600), lastFocusedSeq: 5000 - i)
}
let windows = (0..<50).map(window)
let ctx = Ctx(focused: window(2), workspace: Workspace(name: "2", project: "winmux"), profile: "'ultrawide")
let cols = [Col(index: 1, empty: false, windows: [1000]), Col(index: 2, empty: false, windows: []),
            Col(index: 3, empty: false, windows: [1003])]

struct Each<W: Encodable, R: Encodable>: Encodable { let fn: String; let each: [W]; let rest: [R] }
struct Place: Encodable {
    let fn = "columns.place"; let args: [AnyEncodable]
}
struct AnyEncodable: Encodable {
    let enc: (Encoder) throws -> Void
    init<T: Encodable>(_ v: T) { enc = v.encode }
    func encode(to e: Encoder) throws { try enc(e) }
}
let encoder = JSONEncoder()
func lensRequest() -> String {
    String(decoding: try! encoder.encode(Each(fn: "filters.here", each: windows, rest: [ctx])), as: UTF8.self)
}
func placeRequest() -> String {
    String(decoding: try! encoder.encode(Place(args: [AnyEncodable(window(4)), AnyEncodable(ctx), AnyEncodable(cols)])), as: UTF8.self)
}

func time(_ label: String, _ n: Int, _ body: () -> String) {
    let t0 = DispatchTime.now().uptimeNanoseconds
    let first = body()
    let cold = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1000
    var samples: [Double] = []
    for _ in 0..<n {
        let t = DispatchTime.now().uptimeNanoseconds
        _ = body()
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - t) / 1000)
    }
    samples.sort()
    print(String(format: "%-44@ first %8.1f µs  median %8.1f µs  p99 %8.1f µs", label as NSString,
                 cold, samples[n / 2], samples[n * 99 / 100]))
    print("   -> \(first.prefix(110))")
}

let dir = CommandLine.arguments[1]

// In-process through the C ABI.
var err: UnsafeMutablePointer<CChar>? = nil
let t0 = DispatchTime.now().uptimeNanoseconds
guard let engine = wm_load("\(dir)/config.ncl", &err) else { fatalError(String(cString: err!)) }
print(String(format: "in-process load: %.1f ms", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6))
func callInProcess(_ req: String) -> String {
    let r = wm_call(engine, req)!
    defer { wm_free_string(r) }
    return String(cString: r)
}
time("in-process: Lens open (encode + 50 calls)", 200) { callInProcess(lensRequest()) }
time("in-process: place (encode + 1 call)", 1000) { callInProcess(placeRequest()) }
time("encode only: Lens request", 1000) { lensRequest() }

// Helper process over pipes.
let p = Process()
p.executableURL = URL(fileURLWithPath: CommandLine.arguments[2])
p.arguments = [dir, "serve"]
let inPipe = Pipe(), outPipe = Pipe()
p.standardInput = inPipe; p.standardOutput = outPipe
let t1 = DispatchTime.now().uptimeNanoseconds
try! p.run()
let reader = outPipe.fileHandleForReading
var buffer = Data()
func callHelper(_ req: String) -> String {
    inPipe.fileHandleForWriting.write((req + "\n").data(using: .utf8)!)
    while true {
        if let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            return String(decoding: line, as: UTF8.self)
        }
        buffer.append(reader.availableData)
    }
}
_ = callHelper(placeRequest())
print(String(format: "helper spawn + load + first call: %.1f ms", Double(DispatchTime.now().uptimeNanoseconds - t1) / 1e6))
time("helper: Lens open (encode + pipe + 50 calls)", 200) { callHelper(lensRequest()) }
time("helper: place (encode + pipe + 1 call)", 1000) { callHelper(placeRequest()) }
p.terminate()
wm_free(engine)
