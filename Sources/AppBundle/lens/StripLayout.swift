import AppKit

struct StripLayout {
    static let gap: CGFloat = 8
    let range: Range<Int>
    let before: Int
    let after: Int
    let rowWidth: CGFloat

    init(widths: [CGFloat], selection: Int, width: CGFloat, gap: CGFloat = Self.gap, overhead: CGFloat = 88) {
        let count = widths.count
        guard count > 0 else {
            range = 0 ..< 0; before = 0; after = 0; rowWidth = min(width, overhead)
            return
        }
        let selected = min(max(0, selection), count - 1)
        var best = selected ..< selected + 1
        var bestDistance = Int.max
        for visible in 1 ... min(9, count) {
            for start in max(0, selected - visible + 1) ... min(selected, count - visible) {
                let candidate = start ..< start + visible
                let total = widths[candidate].reduce(0, +) + CGFloat(visible - 1) * gap + overhead
                let distance = abs(start - min(max(0, selected - visible / 2), count - visible))
                if total <= width && (visible > best.count || (visible == best.count && distance < bestDistance)) {
                    best = candidate; bestDistance = distance
                }
            }
        }
        range = best
        before = best.lowerBound
        after = count - best.upperBound
        rowWidth = min(width, widths[best].reduce(0, +) + CGFloat(best.count - 1) * gap + overhead)
    }

}

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

    var elapsedSeconds: Double {
        let parts = elapsed().components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
    // Test observation of the gesture deadline.
    var shouldDisplay: Bool { elapsed() >= .milliseconds(100) }
    var committingModifiers: NSEvent.ModifierFlags { invoking.intersection([.command, .control, .option]) }
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
        if cycleStrip(keyCode: event.keyCode, flags: event.modifierFlags) { return .consumed }
        switch event.keyCode {
            case 53: return .cancel
            case 123: cycleStripSelection(-1); return .consumed
            case 124: cycleStripSelection(1); return .consumed
            // Tab and backtick belong to the strip only with its own modifiers; another chord on them is a global binding.
            case 48, 50: return stripGesture?.owns(event.modifierFlags) == true ? .consumed : .ignored
            default: break
        }
        if event.charactersIgnoringModifiers == "`" { return stripGesture?.owns(event.modifierFlags) == true ? .consumed : .ignored }
        if handleStripLetter(event) { return settings.presentation == "list" ? .list : .consumed }
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
        if performKeyAction(event) { return true }
        guard let text = event.charactersIgnoringModifiers, !text.isEmpty, text.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) else { return false }
        let held = event.modifierFlags.intersection([.command, .control, .option])
        guard held.isEmpty || held == stripGesture?.committingModifiers else { return false }
        let selected = selectedId
        changePresentation("list")
        send(.searchChanged(text))
        if let selected { hover(selected) }
        return true
    }

    func removeStripItems(_ ids: Set<UInt32>) {
        let before = results
        let selected = before.indices.contains(selection) ? before[selection].id : nil
        let replacement = before.prefix(selection).filter { !ids.contains($0.id) }.count
        removedIds.formUnion(ids)
        let after = results
        send(.selectionChanged(after.firstIndex { $0.id == selected } ?? min(replacement, max(0, after.count - 1))))
        objectWillChange.send()
    }

    var tileMetrics: TileMetrics { TileMetrics(visibleHeight: miniatureSize.height) }
    var tileKind: TileKind { TileKind.resolve(configured: settings.tile, override: nil, presentation: settings.presentation) }
    var stripRowHeight: CGFloat {
        tileMetrics.stripRowHeight(aspects: results.map { $0.tile.aspect }, kind: tileKind, availableWidth: miniatureSize.width)
    }
    var stripWidths: [CGFloat] {
        let metrics = tileMetrics
        let height = stripRowHeight
        return results.map { item in
            let pictureHeight = metrics.pictureHeight(rowHeight: height, accessory: item.tile.accessory, actualSize: settings.accessoryWindow == "actual-size", monitorHeightFraction: item.tile.monitorHeightFraction)
            return min(max(1, miniatureSize.width * 0.9 - 88 * metrics.scale), metrics.width(kind: tileKind, aspect: item.tile.aspect, rowHeight: pictureHeight))
        }
    }
    var stripLayout: StripLayout {
        StripLayout(widths: stripWidths, selection: selection, width: miniatureSize.width * 0.9,
                    gap: tileMetrics.stripGap, overhead: 88 * tileMetrics.scale)
    }
    var stripSummonAvailable: Bool {
        guard summonHeld, let item = results.first(where: { $0.id == selectedId }), let current = miniatureWorkspaces.first(where: \.current) else { return false }
        return item.miniature?.workspace != current.name
    }

    func refreshStripThumbnails(lens: Int, request: (Window, Int) -> Void) {
        let results = results
        for index in stripLayout.range {
            if let entry = results[index].miniature, !entry.frozen { request(entry.window, lens) }
        }
    }
}

func lensOnscreenWindows(presentation: String, tile: TileKind = .text, read: () -> Set<UInt32>) -> Set<UInt32> {
    presentation == "miniatures" || presentation == "strip" || tile != .text ? read() : []
}

extension LensSession {
    func refreshListThumbnails(lens: Int, request: (Window, Int) -> Void) {
        for item in results {
            if let entry = item.miniature, !entry.frozen { request(entry.window, lens) }
        }
    }
}
