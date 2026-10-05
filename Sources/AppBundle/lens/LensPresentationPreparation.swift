import AppKit

@MainActor
final class LensStartupPreparation {
    private var prepared = false
    static func model(presentation: String, size: CGSize, existingItems: [SwitcherPaletteItem]? = nil, workspaces: [MiniatureWorkspace]? = nil) -> LensSession {
        var settings = LensConfig()
        settings.presentation = presentation
        if let existingItems, !existingItems.isEmpty {
            let model = LensSession(name: "<startup>", settings: settings, items: existingItems, search: "")
            model.miniatureSize = size
            model.miniatureWorkspaces = workspaces ?? []
            return model
        }
        let thumbnail = WindowThumbnail()
        if let context = CGContext(data: nil, width: 160, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
            if let image = context.makeImage() { thumbnail.accept(image) }
        }
        let fallback = thumbnail.image.map { NSImage(cgImage: $0, size: NSSize(width: 128, height: 128)) }
        let emptyThumbnail = WindowThumbnail()
        let items = (1...4).map { index in
            let picture = index == 1 ? nil : index == 2 ? emptyThumbnail : thumbnail
            var tile = TileEntry(icon: fallback, title: "Window", appName: "Application", picture: picture)
            if index.isMultiple(of: 2) {
                tile.badges = TileBadges(workspaceLabel: "2", onFocusedWorkspace: false)
            }
            return SwitcherPaletteItem(id: UInt32(index), title: tile.title, appName: tile.appName,
                icon: fallback, workspaceName: "1", isFocused: index == 1, tile: tile)
        }
        let model = LensSession(name: "<startup>", settings: settings, items: items, search: "")
        model.miniatureSize = size
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Workspace", source: CGRect(origin: .zero, size: size), current: true)]
        return model
    }

    /// Draws each Presentation once. `idle` is false while a Lens is open or opening: it owns the
    /// panel, so nothing is drawn. Returns whether anything was.
    @discardableResult
    func run(idle: Bool, _ render: (String) -> Void) -> Bool {
        guard idle, !prepared else { return false }
        prepared = true
        for presentation in ["strip", "list", "miniatures", "grid"] { render(presentation) }
        return true
    }
}
