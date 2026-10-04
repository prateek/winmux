// display.swift            print the current mode
// display.swift W H SCALE  switch to W x H points at SCALE (1 or 2)
import CoreGraphics
import Foundation

let display = CGMainDisplayID()
let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
let modes = CGDisplayCopyAllDisplayModes(display, options) as! [CGDisplayMode]
let args = CommandLine.arguments
if args.count == 4, let w = Int(args[1]), let h = Int(args[2]), let scale = Int(args[3]) {
    guard let mode = modes.first(where: { $0.width == w && $0.height == h && $0.pixelWidth == w * scale }) else {
        let offered = Set(modes.map { "\($0.width)x\($0.height)@\($0.pixelWidth / max($0.width, 1))" }).sorted()
        print("no \(w)x\(h)@\(scale) mode; offered: \(offered.joined(separator: " "))")
        exit(1)
    }
    var config: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&config)
    CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
    exit(CGCompleteDisplayConfiguration(config, .permanently) == .success ? 0 : 1)
} else if let mode = CGDisplayCopyDisplayMode(display) {
    print("\(mode.width)x\(mode.height)@\(mode.pixelWidth / max(mode.width, 1))")
}
