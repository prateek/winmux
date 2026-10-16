import AppKit

@MainActor
final class LensStartupPreparation {
    typealias GridDraw = @MainActor @Sendable () -> Void
    typealias GridPreparation = @MainActor @Sendable () async -> GridDraw?
    private let clock: any Clock<Duration>
    private var prepared = false
    private var realGridPrepared = false
    private var pendingWindowIds: Set<UInt32>?
    private var realGridTask: Task<Void, Never>?
    private var generation = 0
    var needsRealGridPreparation: Bool { prepared && !realGridPrepared }

    init(clock: any Clock<Duration> = ContinuousClock()) { self.clock = clock }

    @discardableResult
    func scheduleRealGrid(windowIds: Set<UInt32>, isIdle: @escaping @MainActor @Sendable () -> Bool,
                          prepare: @escaping GridPreparation) -> Bool {
        guard needsRealGridPreparation, !windowIds.isEmpty, isIdle(), pendingWindowIds != windowIds else { return false }
        generation += 1
        let ticket = generation
        pendingWindowIds = windowIds
        realGridTask?.cancel()
        let clock = self.clock
        realGridTask = Task { @MainActor [weak self] in
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            guard let self, ticket == self.generation else { return }
            guard isIdle() else { self.pendingWindowIds = nil; self.realGridTask = nil; return }
            let draw = await prepare()
            guard !Task.isCancelled, ticket == self.generation else { return }
            self.pendingWindowIds = nil
            self.realGridTask = nil
            guard isIdle(), let draw else { return }
            self.realGridPrepared = true
            draw()
        }
        return true
    }

    static func gridModel(size: CGSize, existingItems: [SwitcherPaletteItem], workspaces: [MiniatureWorkspace]) -> LensSession {
        if !existingItems.isEmpty {
            return model(presentation: "grid", size: size, existingItems: existingItems, workspaces: workspaces)
        }
        let shapes = [CGSize(width: 1600, height: 1000), CGSize(width: 900, height: 650),
                      CGSize(width: 600, height: 900), CGSize(width: 360, height: 180)]
        let images = shapes.compactMap { shape -> CGImage? in
            let width = 582, height = Int(CGFloat(width) * shape.height / shape.width)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()
        }
        let icon = NSImage(named: NSImage.applicationIconName)
        let counts = [4, 5, 3, 2]
        var items: [SwitcherPaletteItem] = []
        for (section, count) in counts.enumerated() {
            let workspace = String(section + 1)
            for _ in 0..<count {
                let index = items.count
                let shape = shapes[index % shapes.count]
                let thumbnail = WindowThumbnail()
                if index != 1, !images.isEmpty { thumbnail.accept(images[index % images.count]) }
                let tile = TileEntry(icon: icon, title: "Window", appName: "Application", picture: thumbnail,
                    aspect: shape.width / shape.height, realSize: shape,
                    badges: TileBadges(workspaceLabel: workspace, onFocusedWorkspace: section == 0), frozen: section != 0)
                items.append(SwitcherPaletteItem(id: UInt32(index + 1), title: tile.title, appName: tile.appName,
                    icon: icon, workspaceName: workspace, isFocused: index == 0, tile: tile))
            }
        }
        let workspaces = counts.indices.map { index in
            MiniatureWorkspace(name: String(index + 1), title: "Workspace \(index + 1)", source: CGRect(origin: .zero, size: size), current: index == 0)
        }
        return model(presentation: "grid", size: size, existingItems: items, workspaces: workspaces)
    }

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
