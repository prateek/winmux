import AppKit

struct StripLayout {
    static let entryWidth: CGFloat = 148
    static let entryHeight: CGFloat = 132
    static let gap: CGFloat = 8
    let range: Range<Int>
    let before: Int
    let after: Int
    let rowWidth: CGFloat

    init(count: Int, selection: Int, width: CGFloat) {
        let capacity = max(1, min(9, Int((max(0, width - 88) + Self.gap) / (Self.entryWidth + Self.gap))))
        let visible = min(count, capacity)
        let start = min(max(0, selection - visible / 2), max(0, count - visible))
        range = start ..< start + visible
        before = start
        after = count - range.upperBound
        rowWidth = min(width, CGFloat(max(1, visible)) * (Self.entryWidth + Self.gap) - Self.gap + 88)
    }
}

struct StripGesture {
    let keyCode: UInt16?
    let invoking: NSEvent.ModifierFlags
    let openedAt: TimeInterval
    var committingModifiers: NSEvent.ModifierFlags { invoking.intersection([.command, .control, .option]) }
    func shouldDisplay(now: TimeInterval) -> Bool { now >= openedAt + 0.1 }
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

    var stripLayout: StripLayout { StripLayout(count: results.count, selection: selection, width: miniatureSize.width - 48) }
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

func lensOnscreenWindows(presentation: String, read: () -> Set<UInt32>) -> Set<UInt32> {
    presentation == "miniatures" || presentation == "strip" ? read() : []
}
