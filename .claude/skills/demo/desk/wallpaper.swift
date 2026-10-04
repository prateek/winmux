// wallpaper.swift <image>: make it the desktop picture on every screen.
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
for screen in NSScreen.screens { try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true]) }
