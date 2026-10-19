import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let apps = ["Zed": "/Applications/Zed.app", "Ghostty": "/Applications/Ghostty.app",
            "Safari": "/Applications/Safari.app", "Notes": "/System/Applications/Notes.app",
            "TextEdit": "/System/Applications/TextEdit.app", "Finder": "/System/Library/CoreServices/Finder.app",
            "Preview": "/System/Applications/Preview.app", "Calculator": "/System/Applications/Calculator.app",
            "Updater": NSHomeDirectory() + "/desk/Updater"]
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, path) in apps {
    let image = NSWorkspace.shared.icon(forFile: path)
    image.size = NSSize(width: 64, height: 64)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon-\(name.lowercased()).png"))
}
