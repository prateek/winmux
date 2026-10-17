import AppKit

struct MiniatureWorkspace {
    let name: String
    let title: String
    let source: CGRect
    let current: Bool
}

struct MiniatureWindow {
    let workspace: String
    let frame: CGRect
    let tray: Bool
    let frozen: Bool
    let accessory: Bool
    let floating: Bool
    let window: Window
    var tab: MiniatureTabSnapshot? = nil

    func with(frozen: Bool, tray: Bool) -> Self {
        Self(workspace: workspace, frame: frame, tray: tray, frozen: frozen, accessory: accessory, floating: floating, window: window, tab: tab)
    }
}

extension LensSession {
    var miniatureLayout: MiniatureLayout {
        let visible = miniatureWorkspaces.filter { settings.miniatures.currentWorkspace != "hide" || !$0.current }
        let aspect = miniatureWorkspaces.first.map { $0.source.width / max(1, $0.source.height) } ?? 1.6
        return MiniatureLayout(workspaces: visible.map(\.name), size: miniatureSize, aspect: aspect, fit: settings.miniatures.fit)
    }

    func miniatureCells(on page: Int, layout: MiniatureLayout? = nil) -> [MiniatureLayout.Cell] {
        (layout ?? miniatureLayout).cells(on: page).map { cell in
            guard settings.miniatures.currentWorkspace == "enlarge", miniatureWorkspaces.first(where: { $0.name == cell.workspace })?.current == true else { return cell }
            let frame = cell.frame.insetBy(dx: -cell.frame.width * 0.02, dy: -cell.frame.height * 0.02)
            return MiniatureLayout.Cell(workspace: cell.workspace, frame: frame, tray: CGRect(x: frame.minX, y: frame.maxY + 4, width: frame.width, height: cell.tray.height))
        }
    }

    var miniatureFrames: [UInt32: CGRect] { miniatureFrames(layout: miniatureLayout) }

    func miniatureFrames(layout: MiniatureLayout) -> [UInt32: CGRect] {
        var frames: [UInt32: CGRect] = [:]
        for page in 0 ..< layout.pageCount {
            for cell in miniatureCells(on: page, layout: layout) {
                guard let workspace = miniatureWorkspaces.first(where: { $0.name == cell.workspace }) else { continue }
                let windows = items.compactMap(\.miniature).filter { $0.workspace == cell.workspace }
                var trayIndex = 0
                for entry in windows {
                    let frame: CGRect
                    if entry.tray {
                        let trayCount = max(1, windows.filter(\.tray).count)
                        let width = min(52, cell.tray.width / CGFloat(trayCount))
                        frame = CGRect(x: cell.tray.minX + CGFloat(trayIndex) * width, y: cell.tray.minY, width: max(1, width - 4), height: cell.tray.height)
                        trayIndex += 1
                    } else {
                        let source = entry.tab?.frame ?? entry.frame
                        var scaled = MiniatureLayout.scale(source, from: workspace.source, to: cell.frame)
                        if let tab = entry.tab {
                            // Fan only the tabs this Lens draws; a missing active tab gives the front to the first one drawn
                            let drawn = windows.compactMap(\.tab).filter { $0.group == tab.group }.map(\.index).sorted()
                            scaled = MiniatureLayout.fan(scaled, count: drawn.count, index: drawn.firstIndex(of: tab.index) ?? 0,
                                                         activeIndex: drawn.firstIndex(of: tab.activeIndex) ?? -1, cellWidth: cell.frame.width)
                        }
                        if entry.tab == nil && entry.accessory && settings.accessoryWindow == "enlarged" {
                            scaled.size.width = max(scaled.width, min(120, cell.frame.width))
                            scaled.size.height = max(scaled.height, min(64, cell.frame.height))
                            scaled.origin.x = min(max(cell.frame.minX, scaled.minX), max(cell.frame.minX, cell.frame.maxX - scaled.width))
                            scaled.origin.y = min(max(cell.frame.minY, scaled.minY), max(cell.frame.minY, cell.frame.maxY - scaled.height))
                        }
                        frame = scaled
                    }
                    frames[entry.window.windowId] = frame.offsetBy(dx: 0, dy: CGFloat(page) * miniatureSize.height)
                }
            }
        }
        return frames
    }

    func miniatureHitTest(at point: CGPoint) -> UInt32? {
        let layout = miniatureLayout
        let page = min(miniaturePage, layout.pageCount - 1)
        let frames = miniatureFrames(layout: layout)
        let point = CGPoint(x: point.x, y: point.y + CGFloat(page) * miniatureSize.height)
        let matches = Set(results.map(\.id))
        let drawn = miniatureCells(on: page, layout: layout).flatMap { cell in
            miniatureDrawOrder(items.filter { $0.miniature?.workspace == cell.workspace && matches.contains($0.id) })
        }
        return drawn.reversed().first { frames[$0.id]?.contains(point) == true }?.id
    }

    func hoverMiniature(at point: CGPoint, pointerLocation: CGPoint) {
        hover(miniatureHitTest(at: point), at: pointerLocation)
    }

    func miniatureOpacity(_ id: UInt32) -> Double { results.contains { $0.id == id } ? 1 : 0.18 }

    func moveMiniatureSelection(_ direction: MiniatureLayout.Direction) {
        guard let id = selectedId else { return }
        let matches = Set(results.map(\.id))
        let target: UInt32?
        if settings.miniatures.arrowKeys == "by-workspace", let workspace = items.first(where: { $0.id == id })?.miniature?.workspace {
            let ordered = miniatureLayout.workspaces
            let frames = miniatureFrames
            let within = items.filter { $0.miniature?.workspace == workspace && matches.contains($0.id) }.sorted {
                let lhs = frames[$0.id] ?? .zero, rhs = frames[$1.id] ?? .zero
                // The tray comes after the windows on the workspace
                if $0.miniature?.tray != $1.miniature?.tray { return $1.miniature?.tray == true }
                return lhs.minX == rhs.minX ? (lhs.minY == rhs.minY ? $0.id < $1.id : lhs.minY < rhs.minY) : lhs.minX < rhs.minX
            }
            if direction == .left || direction == .right {
                let index = within.firstIndex { $0.id == id } ?? 0
                let next = index + (direction == .right ? 1 : -1)
                target = within.indices.contains(next) ? within[next].id : nil
            } else {
                let index = ordered.firstIndex(of: workspace) ?? 0
                let candidates = direction == .down ? Array(ordered.dropFirst(index + 1)) : Array(ordered.prefix(index).reversed())
                target = candidates.lazy.compactMap { name in
                    self.items.first { $0.miniature?.workspace == name && matches.contains($0.id) }?.id
                }.first
            }
        } else {
            let group = items.first(where: { $0.id == id })?.miniature?.tab?.group
            let tabs = group.map { group in Set(items.filter { $0.miniature?.tab?.group == group }.map(\.id)) } ?? []
            target = MiniatureLayout.nearest(from: id, direction: direction, frames: miniatureFrames, matches: matches, adjacentTabs: tabs)
        }
        if let target { hover(target); revealMiniatureSelection() }
    }

    func revealMiniatureSelection() {
        guard let id = selectedId, let workspace = items.first(where: { $0.id == id })?.miniature?.workspace,
              let page = miniatureLayout.page(for: workspace) else { return }
        miniaturePage = page
    }

    func turnMiniaturePage(_ delta: Int) {
        // An empty page or the same selection sends no selection event.
        reanchorPointer()
        miniaturePage = miniatureLayout.turnedPage(miniaturePage, delta: delta)
        let names = Set(miniatureLayout.cells(on: miniaturePage).map(\.workspace))
        if let entry = results.first(where: { names.contains($0.miniature?.workspace ?? "") }) { hover(entry.id) }
    }

    func refreshVisibleThumbnails(lens: Int, request: (Window, Int, CGSize) -> Void) {
        let names = Set(miniatureLayout.cells(on: miniaturePage).map(\.workspace))
        let frames = miniatureFrames
        for item in items {
            guard let entry = item.miniature, !entry.frozen, names.contains(entry.workspace) else { continue }
            if let frame = frames[item.id] { request(entry.window, lens, thumbnailDemand(frame.size)) }
        }
    }
}

extension LensSession {
    func miniatureLandingFrame(in cell: MiniatureLayout.Cell) -> CGRect? {
        guard let source = miniatureLanding, let workspace = miniatureWorkspaces.first(where: { $0.current }) else { return nil }
        return MiniatureLayout.scale(source, from: workspace.source, to: cell.frame)
    }
}

func miniatureIsFrozen(tray: Bool, fullscreen: Bool, workspaceVisible: Bool, parked: Bool) -> Bool {
    tray || fullscreen || !workspaceVisible || parked
}

func appendingRetainedMiniatureWorkspaces(_ ordered: [MiniatureWorkspace], retained: [MiniatureWorkspace]) -> [MiniatureWorkspace] {
    var snapshots = ordered
    for workspace in retained where !snapshots.contains(where: { $0.name == workspace.name }) {
        snapshots.append(MiniatureWorkspace(name: workspace.name, title: "Previous \(workspace.title)", source: workspace.source, current: false))
    }
    return snapshots
}

func miniatureDrawOrder(_ items: [SwitcherPaletteItem]) -> [SwitcherPaletteItem] {
    var groupOrder: [ObjectIdentifier: Int] = [:]
    for (index, item) in items.enumerated() {
        if let tab = item.miniature?.tab, groupOrder[tab.group] == nil { groupOrder[tab.group] = index }
    }
    return items.enumerated().sorted { lhs, rhs in
        let a = lhs.element.miniature, b = rhs.element.miniature
        if (a?.floating == true) != (b?.floating == true) { return b?.floating == true }
        let leftOrder = a?.tab.flatMap { groupOrder[$0.group] } ?? lhs.offset
        let rightOrder = b?.tab.flatMap { groupOrder[$0.group] } ?? rhs.offset
        if leftOrder != rightOrder { return leftOrder > rightOrder }
        if let leftTab = a?.tab, let rightTab = b?.tab, leftTab.group == rightTab.group {
            return leftTab.depth > rightTab.depth
        }
        return lhs.offset > rhs.offset
    }.map(\.element)
}

@MainActor
func miniatureColumnLanding(_ placement: ResolvedColumnPlacement, in rect: CGRect, horizontalGap: CGFloat,
                            verticalGap: CGFloat) -> CGRect {
    let range = placement.verticalRange.orDie("Floating placements use floating window geometry")
    var frame = ColumnState.frame(slot: placement.slot, widths: placement.widths, in: rect, gap: horizontalGap)
    let topGap = range.lowerBound > 0 ? verticalGap / 2 : 0
    let bottomGap = range.upperBound < 1 ? verticalGap / 2 : 0
    frame.origin.y += rect.height * range.lowerBound + topGap
    frame.size.height = rect.height * (range.upperBound - range.lowerBound) - topGap - bottomGap
    return frame
}
