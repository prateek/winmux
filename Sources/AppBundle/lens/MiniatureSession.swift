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
        guard summonHeld, (settings.presentation == "miniatures" || settings.presentation == "strip"), settings.summonHints.contains("landing-spot"),
              let id = selectedId, let entry = items.first(where: { $0.id == id })?.miniature,
              let workspace = miniatureWorkspaces.first(where: { $0.current }) else { setMiniatureLanding(nil); return }
        if entry.workspace == workspace.name { setMiniatureLanding(settings.presentation == "strip" ? nil : entry.frame); return }
        if entry.floating {
            let source = miniatureWorkspaces.first { $0.name == entry.workspace }?.source ?? workspace.source
            setMiniatureLanding(miniatureFloatingLanding(entry.frame, from: source, to: workspace.source))
            return
        }
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

func miniatureIsFrozen(tray: Bool, fullscreen: Bool, workspaceVisible: Bool, parked: Bool) -> Bool {
    tray || fullscreen || !workspaceVisible || parked
}

func miniatureFloatingLanding(_ frame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
    let x = destination.minX + (frame.minX - source.minX) / max(1, source.width) * destination.width
    let y = destination.minY + (frame.minY - source.minY) / max(1, source.height) * destination.height
    return CGRect(x: min(max(destination.minX, x), max(destination.minX, destination.maxX - frame.width)),
                  y: min(max(destination.minY, y), max(destination.minY, destination.maxY - frame.height)),
                  width: frame.width, height: frame.height)
}

func appendingRetainedMiniatureWorkspaces(_ ordered: [MiniatureWorkspace], retained: [MiniatureWorkspace]) -> [MiniatureWorkspace] {
    var snapshots = ordered
    for workspace in retained where !snapshots.contains(where: { $0.name == workspace.name }) {
        snapshots.append(MiniatureWorkspace(name: workspace.name, title: "Previous \(workspace.title)", source: workspace.source, current: false))
    }
    return snapshots
}

/// Items arrive in the Lens's sort order. Tiled windows are drawn first and floating ones over
/// them; where two overlap, the one earlier in sort order is drawn last and takes the pointer.
func miniatureDrawOrder(_ items: [SwitcherPaletteItem]) -> [SwitcherPaletteItem] {
    items.enumerated().sorted { lhs, rhs in
        let a = lhs.element.miniature?.floating == true, b = rhs.element.miniature?.floating == true
        return a == b ? lhs.offset > rhs.offset : !a
    }.map(\.element)
}
