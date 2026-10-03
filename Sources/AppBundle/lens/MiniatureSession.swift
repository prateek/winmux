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
}

extension LensSession {
    var miniatureLayout: MiniatureLayout {
        let visible = miniatureWorkspaces.filter { settings.miniatures.currentWorkspace != "hide" || !$0.current }
        let aspect = miniatureWorkspaces.first.map { $0.source.width / max(1, $0.source.height) } ?? 1.6
        return MiniatureLayout(workspaces: visible.map(\.name), size: miniatureSize, aspect: aspect, fit: settings.miniatures.fit)
    }

    func miniatureCells(on page: Int) -> [MiniatureLayout.Cell] {
        miniatureLayout.cells(on: page).map { cell in
            guard settings.miniatures.currentWorkspace == "enlarge", miniatureWorkspaces.first(where: { $0.name == cell.workspace })?.current == true else { return cell }
            let frame = cell.frame.insetBy(dx: -cell.frame.width * 0.02, dy: -cell.frame.height * 0.02)
            return MiniatureLayout.Cell(workspace: cell.workspace, frame: frame, tray: CGRect(x: frame.minX, y: frame.maxY + 4, width: frame.width, height: cell.tray.height))
        }
    }

    var miniatureFrames: [UInt32: CGRect] {
        var frames: [UInt32: CGRect] = [:]
        let layout = miniatureLayout
        for page in 0 ..< layout.pageCount {
            for cell in miniatureCells(on: page) {
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
                        var scaled = MiniatureLayout.scale(entry.frame, from: workspace.source, to: cell.frame)
                        if entry.accessory && settings.accessoryWindow == "enlarged" {
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

    func miniatureOpacity(_ id: UInt32) -> Double { results.contains { $0.id == id } ? 1 : 0.18 }

    func moveMiniatureSelection(_ direction: MiniatureLayout.Direction) {
        guard let id = selectedId else { return }
        let matches = Set(results.map(\.id))
        let target: UInt32?
        if settings.miniatures.arrowKeys == "by-workspace", let workspace = items.first(where: { $0.id == id })?.miniature?.workspace {
            let ordered = miniatureLayout.workspaces
            let within = items.filter { $0.miniature?.workspace == workspace && matches.contains($0.id) }
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
        } else { target = MiniatureLayout.nearest(from: id, direction: direction, frames: miniatureFrames, matches: matches) }
        if let target { hover(target); revealMiniatureSelection() }
    }

    func revealMiniatureSelection() {
        guard let id = selectedId, let workspace = items.first(where: { $0.id == id })?.miniature?.workspace,
              let page = miniatureLayout.page(for: workspace) else { return }
        miniaturePage = page
    }

    func turnMiniaturePage(_ delta: Int) {
        miniaturePage = miniatureLayout.turnedPage(miniaturePage, delta: delta)
        let names = Set(miniatureLayout.cells(on: miniaturePage).map(\.workspace))
        if let entry = results.first(where: { names.contains($0.miniature?.workspace ?? "") }) { hover(entry.id) }
    }

    func refreshVisibleThumbnails(lens: Int) {
        let names = Set(miniatureLayout.cells(on: miniaturePage).map(\.workspace))
        for item in items {
            guard let entry = item.miniature, !entry.frozen, names.contains(entry.workspace) else { continue }
            ThumbnailCache.shared.request(entry.window, lens: lens)
        }
    }
}

extension LensSession {
    func miniatureLandingFrame(in cell: MiniatureLayout.Cell) -> CGRect? {
        guard let source = miniatureLanding, let workspace = miniatureWorkspaces.first(where: { $0.current }) else { return nil }
        return MiniatureLayout.scale(source, from: workspace.source, to: cell.frame)
    }

    func updateMiniatureLanding() {
        guard summonHeld, settings.presentation == "miniatures", settings.summonHints.contains("landing-spot"),
              let id = selectedId, let entry = items.first(where: { $0.id == id })?.miniature,
              let workspace = miniatureWorkspaces.first(where: { $0.current }) else { setMiniatureLanding(nil); return }
        if entry.floating || entry.workspace == workspace.name { setMiniatureLanding(entry.frame); return }
        let root = focus.workspace.rootTilingContainer
        let rect = root.lastAppliedLayoutPhysicalRect?.cgRect ?? workspace.source
        let wraps = root.layout == .tabGroup && !root.children.isEmpty
        let orientation = wraps ? root.orientation.opposite : root.orientation
        let count = CGFloat(wraps ? 2 : root.children.count + 1)
        let gap = count > 1 ? CGFloat(ResolvedGaps(gaps: config.gaps, monitor: focus.workspace.workspaceMonitor).inner.get(orientation).toDouble()) / 2 : 0
        if orientation == .h {
            setMiniatureLanding(CGRect(x: rect.maxX - rect.width / count + gap, y: rect.minY, width: rect.width / count - gap, height: rect.height))
        } else {
            setMiniatureLanding(CGRect(x: rect.minX, y: rect.maxY - rect.height / count + gap, width: rect.width, height: rect.height / count - gap))
        }
    }
}
