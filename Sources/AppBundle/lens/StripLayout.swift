import AppKit

func stripDebugLog(_ message: @autoclosure () -> String) {
    if ProcessInfo.processInfo.environment["WINMUX_DEBUG_STRIP_EVENTS"] == "1" { debugFocusLog(message()) }
}

extension LensSession {
    func cycleStripSelection(_ delta: Int) {
        let count = results.count
        send(.selectionChanged(count == 0 ? 0 : (selection + delta % count + count) % count))
    }

    func removeStripItems(_ ids: Set<UInt32>) { send(.itemsRemoved(ids)) }

    var tileMetrics: TileMetrics { TileMetrics(visibleSize: miniatureSize) }
    var tileKind: TileKind { TileKind.resolve(configured: settings.tile, presentation: settings.presentation) }
    var drawsPictures: Bool { Self.drawsPictures(settings: settings) }

    static func drawsPictures(settings: LensConfig) -> Bool {
        TileKind.resolve(configured: settings.tile, presentation: settings.presentation) != .text
    }

    var listLayout: ListLayout { listLayout(count: results.count) }
    func listLayout(count: Int) -> ListLayout {
        var starts: [Int] = [], offset = 0
        for section in sections {
            if section.label != nil { starts.append(offset) }
            offset += section.entries.count
        }
        return ListLayout(count: count, kind: tileKind, visibleSize: miniatureSize, sectionStarts: starts, minimumWidth: listControlMinimumWidth)
    }
    func stripSummonAvailable(items: [SwitcherPaletteItem]) -> Bool {
        guard let item = items.first(where: { $0.id == selectedId }), let current = miniatureWorkspaces.first(where: \.current) else { return false }
        return (item.miniature?.workspace ?? item.workspaceIdentity ?? item.workspaceName) != current.name
    }

    func refreshListThumbnails(lens: Int, request: (Window, Int, CGSize) -> Void) {
        let items = results
        let layout = listLayout(count: items.count)
        for index in layout.visibleRange(selection: selection, count: items.count) {
            if let entry = items[index].miniature, !entry.frozen {
                let picture = tileMetrics.fittedPicture(aspect: items[index].tile.aspect,
                    in: CGSize(width: tileMetrics.listPictureWidth, height: tileMetrics.listPictureHeight - 2 * tileMetrics.rowVerticalPadding))
                request(entry.window, lens, thumbnailDemand(picture, lifted: false))
            }
        }
    }

    func refreshThumbnails(lens: Int, request: (Window, Int, CGSize) -> Void) {
        guard drawsPictures else { return }
        switch settings.presentation {
            case "strip", "grid": refreshGridThumbnails(lens: lens, request: request)
            case "list": refreshListThumbnails(lens: lens, request: request)
            default: refreshVisibleThumbnails(lens: lens, request: request)
        }
    }
}

struct ListLayout {
    let radius: CGFloat
    let width: CGFloat
    let height: CGFloat
    let headerHeight: CGFloat
    let topOffset: CGFloat
    let rowHeight: CGFloat
    let gap: CGFloat
    let capacity: Int
    let rowOffsets: [CGFloat]
    /// The window's height: the tallest the list gets, plus room for an error or banner line.
    /// The window keeps this size while Search changes the row count; the view draws from its top.
    let panelHeight: CGFloat
    var rowsHeight: CGFloat { height - headerHeight }

    init(count: Int, kind: TileKind, visibleSize: CGSize, sectionStarts: [Int] = [], minimumWidth: CGFloat = 0) {
        let metrics = TileMetrics(visibleSize: visibleSize)
        radius = 30 * metrics.scale
        width = max(760 * metrics.scale, minimumWidth)
        headerHeight = 90 * metrics.scale
        topOffset = visibleSize.height / 4
        rowHeight = kind == .text ? metrics.textHeight : metrics.listPictureHeight
        gap = 4 * metrics.scale
        // A quarter down and at most two thirds tall leaves a margin below a full list.
        let maxRowsHeight = max(rowHeight, visibleSize.height * 0.66 - headerHeight)
        panelHeight = min(visibleSize.height - topOffset, maxRowsHeight + headerHeight + 40 * metrics.scale)
        var y: CGFloat = 0
        var offsets: [CGFloat] = []
        for index in 0..<count {
            if sectionStarts.contains(index) { y += (32 + (index == 0 ? 0 : 6)) * metrics.scale }
            offsets.append(y)
            y += rowHeight + gap
        }
        rowOffsets = sectionStarts.isEmpty ? [] : offsets
        height = min(max(rowHeight + gap, y), maxRowsHeight) + headerHeight
        capacity = max(1, Int(ceil((height - headerHeight) / (rowHeight + gap))))
    }

    func visibleRange(selection: Int, count: Int) -> Range<Int> {
        if !rowOffsets.isEmpty, rowOffsets.indices.contains(selection), rowOffsets.count == count {
            let top = max(0, min(rowOffsets[selection] - rowsHeight / 2, (rowOffsets.last ?? 0) + rowHeight - rowsHeight))
            let start = rowOffsets.firstIndex { $0 + rowHeight >= top } ?? 0
            let end = rowOffsets.lastIndex { $0 <= top + rowsHeight } ?? start
            return start..<end + 1
        }
        let visible = min(capacity, count)
        let start = min(max(0, selection - visible / 2), max(0, count - visible))
        return start ..< start + visible
    }
}

func lensOnscreenWindows(drawsPictures: Bool, read: () -> Set<UInt32>) -> Set<UInt32> {
    drawsPictures ? read() : []
}
