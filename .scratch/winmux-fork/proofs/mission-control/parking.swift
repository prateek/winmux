import AppKit
import ScreenCaptureKit

@_silgen_name("_AXUIElementGetWindow")
func windowID(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct Frame: Codable {
    let id: UInt32
    let app: String
    let title: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var parked: Bool { x >= 1900 || y >= 1040 || x + width <= 2 }
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func windows() -> [UInt32: AXUIElement] {
    var result: [UInt32: AXUIElement] = [:]
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        for window in attribute(element, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
            var id: UInt32 = 0
            if windowID(window, &id) == .success { result[id] = window }
        }
    }
    return result
}

func frames() -> [Frame] {
    let targets: Set<String> = ["Zed", "Ghostty", "Safari", "Notes", "TextEdit", "Finder", "Preview", "Calculator", "Updater"]
    let handles = windows()
    return (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], 0) as? [[String: Any]] ?? []).compactMap { row in
        guard let app = row[kCGWindowOwnerName as String] as? String, targets.contains(app),
              let bounds = row[kCGWindowBounds as String] as? [String: Double],
              let id = row[kCGWindowNumber as String] as? UInt32,
              handles[id] != nil else { return nil }
        return Frame(id: id, app: app, title: row[kCGWindowName as String] as? String ?? "",
                     x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
    }.sorted { $0.id < $1.id }
}

func write(_ frames: [Frame], to path: String) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(frames).write(to: URL(fileURLWithPath: path))
}

func set(_ window: AXUIElement, point: CGPoint, size: CGSize?) {
    if var size {
        let error = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
        print("size", error.rawValue)
    }
    var point = point
    let error = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &point)!)
    print("position", error.rawValue)
}

func dump(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 10 else { return }
    let names = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXPositionAttribute, kAXSizeAttribute]
    print(String(repeating: " ", count: depth), names.map { String(describing: attribute(element, $0)) }.joined(separator: " | "))
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { dump(child, depth: depth + 1) }
}

@main @MainActor struct Probe {
    static func main() async throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        switch args[1] {
        case "ax":
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!
            dump(AXUIElementCreateApplication(app.processIdentifier))
        case "save": try write(frames(), to: args[2])
        case "apply":
            let saved = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
            let handles = windows()
            let option = args[3]
            let started = Date()
            for frame in saved.sorted(by: { !$0.parked && $1.parked }) {
                guard let window = handles[frame.id] else { print("missing", frame.id); continue }
                let minimize = option == "minimize" && frame.parked
                let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, minimize ? kCFBooleanTrue : kCFBooleanFalse)
                print("minimized", frame.id, minimize, error.rawValue)
                if minimize { continue }
                var point = CGPoint(x: frame.x, y: frame.y)
                var size = CGSize(width: frame.width, height: frame.height)
                if frame.parked {
                    if option == "offscreen" { point = CGPoint(x: 1950, y: 1110) }
                    if option == "small" { size = CGSize(width: 80, height: 80) }
                    if option == "show" { point = CGPoint(x: 62, y: 42) }
                }
                print(frame.id, frame.app, frame.parked ? "parked" : "visible")
                set(window, point: point, size: size)
            }
            print("apply seconds", Date().timeIntervalSince(started))
            try await Task.sleep(for: .seconds(2))
            try write(frames(), to: args[4])
        case "capture":
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let id = UInt32(args[2])!
            guard let window = content.windows.first(where: { $0.windowID == id }) else {
                print("window absent from SCShareableContent", id)
                exit(2)
            }
            print("SCWindow", id, window.frame)
            let config = SCScreenshotConfiguration()
            config.showsCursor = false; config.ignoreShadows = true; config.includeChildWindows = false
            let result = try await SCScreenshotManager.captureScreenshot(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
            guard let image = result.sdrImage else { fatalError("no image") }
            let rep = NSBitmapImageRep(cgImage: image)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
            print("image", image.width, image.height)
        default: fatalError("save <json> | apply <json> <baseline|offscreen|small|minimize|show> <actual-json> | capture <id> <png> | ax")
        }
    }
}
