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
}

@TaskLocal var lensInvocation: StripGesture?

extension LensSession {
    func beginStrip(_ gesture: StripGesture) {
        stripGesture = gesture
        selection = results.count > 1 ? (gesture.invoking.contains(.shift) ? results.count - 1 : 1) : 0
    }

    @discardableResult
    func cycleStrip(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard settings.presentation == "strip", stripGesture?.keyCode == keyCode else { return false }
        cycleStripSelection(flags.contains(.shift) ? -1 : 1)
        return true
    }

    func cycleStripSelection(_ delta: Int) {
        let count = results.count
        selection = count == 0 ? 0 : (selection + delta % count + count) % count
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
        let selected = selectedId
        changePresentation("list")
        query = text
        if let selected { hover(selected) }
        return true
    }

    func removeStripItems(_ ids: Set<UInt32>) {
        removedIds.formUnion(ids)
        selection = min(selection, max(0, results.count - 1))
        objectWillChange.send()
    }

    var stripLayout: StripLayout { StripLayout(count: results.count, selection: selection, width: miniatureSize.width - 48) }
    var stripSummonAvailable: Bool {
        guard summonHeld, let item = results.first(where: { $0.id == selectedId }), let current = miniatureWorkspaces.first(where: \.current) else { return false }
        return item.miniature?.workspace != current.name
    }

    func refreshStripThumbnails(lens: Int) {
        let results = results
        for index in stripLayout.range {
            if let entry = results[index].miniature, !entry.frozen { ThumbnailCache.shared.request(entry.window, lens: lens) }
        }
    }
}
