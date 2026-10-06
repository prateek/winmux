import AppKit

struct StripGesture {
    let keyCode: UInt16?
    let invoking: NSEvent.ModifierFlags
    private let elapsed: @Sendable () -> Duration
    let waitForDisplay: @Sendable () async throws -> Void

    init(keyCode: UInt16?, invoking: NSEvent.ModifierFlags, clock: any Clock<Duration> = ContinuousClock()) {
        self.keyCode = keyCode
        self.invoking = invoking
        (elapsed, waitForDisplay) = Self.start(on: clock)
    }

    private static func start<C: Clock>(on clock: C) -> (@Sendable () -> Duration, @Sendable () async throws -> Void) where C.Duration == Duration {
        let started = clock.now
        return ({ started.duration(to: clock.now) }, { try await clock.sleep(until: started.advanced(by: .milliseconds(100)), tolerance: nil) })
    }

    // Test observation of the gesture deadline.
    var shouldDisplay: Bool { elapsed() >= .milliseconds(100) }
    var committingModifiers: NSEvent.ModifierFlags { invoking.intersection([.command, .control, .option]) }
    var holdModifiers: NSEvent.ModifierFlags {
        committingModifiers.isEmpty ? invoking.intersection(.shift) : committingModifiers
    }
    func holdEnded(flags: NSEvent.ModifierFlags) -> Bool { flags.intersection(holdModifiers).isEmpty }
    func shouldCommit(flags: NSEvent.ModifierFlags) -> Bool { flags.intersection(committingModifiers).isEmpty }
    func releaseModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .control, .option]).subtracting(committingModifiers)
    }
    /// A chord is the strip's own when it holds exactly the invoking modifiers; Shift is free.
    func owns(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection([.command, .control, .option]) == committingModifiers
    }
    /// The step the invoking key makes, Shift reversing it. Nil for any other key or chord.
    func step(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Int? {
        guard keyCode == self.keyCode, owns(flags) else { return nil }
        return flags.contains(.shift) ? -1 : 1
    }
}

func stripDebugLog(_ message: @autoclosure () -> String) {
    if ProcessInfo.processInfo.environment["WINMUX_DEBUG_STRIP_EVENTS"] == "1" { debugFocusLog(message()) }
}

enum StripInput { case ignored, consumed, cancel, list }

@TaskLocal var lensInvocation: StripGesture?

extension LensSession {
    func beginStrip(_ gesture: StripGesture) {
        stripGesture = gesture
        startHold(gesture)
        send(.selectionChanged(gesture.invoking.contains(.shift) ? max(0, results.count - 1) : initialSelection()))
    }

    @discardableResult
    func cycleStrip(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard settings.presentation == "strip", let step = stripGesture?.step(keyCode: keyCode, flags: flags) else { return false }
        cycleStripSelection(step)
        return true
    }

    func stripInput(_ event: NSEvent) -> StripInput {
        guard settings.presentation == "strip" else { return .ignored }
        let meaning = meaning(for: event)
        if meaning == .dismiss { return .cancel }
        if perform(meaning) { return settings.presentation == "list" ? .list : .consumed }
        return .ignored
    }

    func cycleStripSelection(_ delta: Int) {
        let count = results.count
        send(.selectionChanged(count == 0 ? 0 : (selection + delta % count + count) % count))
    }

    func stripReleaseKey(flags: NSEvent.ModifierFlags) -> String? {
        guard settings.presentation == "strip", let gesture = stripGesture, gesture.shouldCommit(flags: flags) else { return nil }
        return enterKey(modifiers: gesture.releaseModifiers(flags)) ?? "enter"
    }

    @discardableResult
    func handleStripLetter(_ event: NSEvent) -> Bool {
        guard settings.presentation == "strip" else { return false }
        let meaning = meaning(for: event)
        switch meaning {
            case .command, .text: return perform(meaning)
            default: return false
        }
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
        guard summonHeld, let item = items.first(where: { $0.id == selectedId }), let current = miniatureWorkspaces.first(where: \.current) else { return false }
        return item.miniature?.workspace != current.name
    }

    func refreshListThumbnails(lens: Int, request: (Window, Int) -> Void) {
        let items = results
        let layout = listLayout(count: items.count)
        for index in layout.visibleRange(selection: selection, count: items.count) {
            if let entry = items[index].miniature, !entry.frozen { request(entry.window, lens) }
        }
    }

    func refreshThumbnails(lens: Int, request: (Window, Int) -> Void) {
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
