import AppKit

@MainActor
enum LensPresentationPreparation {
    static func run(content: () -> Void, frame: () -> Void, layout: () -> Void) {
        content()
        frame()
        layout()
    }
}

@MainActor
final class LensStartupPreparation {
    private var prepared = false
    static func model(presentation: String, size: CGSize) -> LensSession {
        var settings = LensConfig()
        settings.presentation = presentation
        let thumbnail = WindowThumbnail()
        if let context = CGContext(data: nil, width: 160, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
            if let image = context.makeImage() { thumbnail.accept(image) }
        }
        let icon = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        let items = (1...4).map { index in
            var tile = TileEntry(icon: icon, title: "Window", appName: "Application", picture: index.isMultiple(of: 2) ? thumbnail : nil)
            if index.isMultiple(of: 2) {
                tile.badges = TileBadges(workspaceLabel: "2", onFocusedWorkspace: false)
            }
            return SwitcherPaletteItem(id: UInt32(index), title: tile.title, appName: tile.appName,
                icon: icon, workspaceName: "1", isFocused: index == 1, tile: tile)
        }
        let model = LensSession(name: "<startup>", settings: settings, items: items, search: "")
        model.miniatureSize = size
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Workspace", source: CGRect(origin: .zero, size: size), current: true)]
        return model
    }

    func run(_ render: (String) -> Void) {
        guard !prepared else { return }
        prepared = true
        for presentation in ["strip", "list", "miniatures"] { render(presentation) }
    }
}
