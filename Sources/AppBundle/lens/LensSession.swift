import AppKit
import Common
import HotKey

@MainActor
final class LensSession: ObservableObject {
    let name: String
    private(set) var settings: LensConfig
    let items: [SwitcherPaletteItem]
    @Published var query: String {
        didSet {
            guard query != oldValue else { return }
            if query.hasPrefix("="), !oldValue.hasPrefix("=") {
                inlineIds = Set(filterSwitcherPaletteItems(items, query: oldValue).map(\.id))
            }
            if !query.hasPrefix("=") { searchError = nil }
            selection = 0
            onSearchChanged?()
            if settings.presentation == "miniatures" { revealMiniatureSelection() }
        }
    }
    @Published var selection: Int { didSet { updateMiniatureLanding() } }
    @Published private(set) var marks: [UInt32] = []
    @Published private(set) var searchError: String?
    @Published var banner: String?
    @Published var summonHeld = false { didSet { updateMiniatureLanding() } }
    @Published private(set) var miniatureLanding: CGRect?
    @Published var miniaturePage = 0
    var miniatureSize = CGSize(width: 1000, height: 700)
    var miniatureExcludedIds: Set<UInt32> = [] { didSet { selection = initialSelection() } }
    var miniatureWorkspaces: [MiniatureWorkspace] = []
    private var lastPointerLocation = NSEvent.mouseLocation
    private var inlineIds: Set<UInt32>?
    private let keyBindings: [(name: String, code: UInt16, modifiers: NSEvent.ModifierFlags)]
    var stripGesture: StripGesture?
    /// The modifiers held when the invoking ones were released before the session was ready.
    var stripReleasedWhileOpening: NSEvent.ModifierFlags?
    var removedIds: Set<UInt32> = []
    var onSearchChanged: (() -> Void)?
    var onAction: ((String) -> Void)?

    init(name: String, settings: LensConfig, items: [SwitcherPaletteItem], search: String) {
        self.name = name
        self.settings = settings
        self.items = items
        keyBindings = settings.keys.keys.sorted().compactMap { name in
            if case .success(let (modifiers, key)) = parseBinding(name, .emptyRoot, config.keyMapping.resolve()) {
                return (name, UInt16(key.carbonKeyCode), modifiers)
            }
            return nil
        }
        query = search
        selection = 0
        selection = initialSelection()
    }

    /// The list opens on its second row when the first is the focused window. Miniatures are not
    /// drawn in sort order, so they open on the most recently focused window that is not focused.
    func initialSelection() -> Int {
        let results = results
        guard settings.presentation == "miniatures", query.isEmpty else {
            return results.count > 1 && results.first?.isFocused == true ? 1 : 0
        }
        return results.enumerated().filter { !$0.element.isFocused }.max { lhs, rhs in
            lhs.element.lastFocusedSeq == rhs.element.lastFocusedSeq ? lhs.offset > rhs.offset : lhs.element.lastFocusedSeq < rhs.element.lastFocusedSeq
        }?.offset ?? 0
    }

    var results: [SwitcherPaletteItem] {
        let items = items.filter { !removedIds.contains($0.id) }
        let available = settings.presentation == "miniatures" ? items.filter { !miniatureExcludedIds.contains($0.id) && $0.miniature?.workspace.isEmpty != true } : items
        let windows = query.hasPrefix("=") ? available.filter { inlineIds?.contains($0.id) ?? true } : filterSwitcherPaletteItems(available, query: query)
        guard settings.entries == "app", settings.presentation != "miniatures" else { return windows }
        var seen: Set<String> = []
        return windows.filter { seen.insert($0.appIdentity).inserted }.map { representative in
            windows.filter { $0.appIdentity == representative.appIdentity }.max {
                $0.lastFocusedSeq == $1.lastFocusedSeq ? $0.id > $1.id : $0.lastFocusedSeq < $1.lastFocusedSeq
            } ?? representative
        }
    }

    var miniatureSearchVisible: Bool { !query.isEmpty }

    var selectedId: UInt32? { results.indices.contains(selection) ? results[selection].id : nil }

    func key(for event: NSEvent, click: Bool = false) -> String? {
        // Return / keypad enter share a binding; a click runs that Enter action too.
        let code: UInt16 = click || event.keyCode == 76 ? 36 : event.keyCode
        let modifiers = click && settings.presentation == "strip"
            ? stripGesture?.releaseModifiers(event.modifierFlags) ?? []
            : event.modifierFlags.intersection([.control, .option, .shift, .command])
        return keyBindings.first { $0.code == code && $0.modifiers == modifiers }?.name
    }

    func enterKey(modifiers: NSEvent.ModifierFlags) -> String? {
        keyBindings.first { $0.code == 36 && $0.modifiers == modifiers }?.name
    }

    func updateSummonModifiers(_ modifiers: NSEvent.ModifierFlags) {
        let held = settings.presentation == "strip" ? (stripGesture?.releaseModifiers(modifiers) ?? []) : modifiers.intersection([.control, .option, .shift, .command])
        let shouldHold = !held.isEmpty && keyBindings.contains { binding in
            binding.modifiers == held && commands(for: binding.name).contains { $0 == "summon" || $0.hasPrefix("summon ") }
        }
        if shouldHold != summonHeld { summonHeld = shouldHold }
    }

    func performKeyAction(_ event: NSEvent) -> Bool {
        guard let key = key(for: event) else { return false }
        onAction?(key)
        return true
    }

    func moveSelection(_ delta: Int) { selection = min(max(selection + delta, 0), max(results.count - 1, 0)) }
    func hover(_ id: UInt32) { if let index = results.firstIndex(where: { $0.id == id }) { selection = index } }
    func hover(_ id: UInt32, at location: CGPoint) {
        guard location != lastPointerLocation else { return }
        lastPointerLocation = location
        hover(id)
    }

    func toggleMark() {
        guard let id = selectedId else { return }
        if let index = marks.firstIndex(of: id) { marks.remove(at: index) } else { marks.append(id) }
    }
    func commands(for key: String) -> [String] { settings.keys[key] ?? [] }
    func targets(for key: String) -> [UInt32] {
        targets(forCommand: commands(for: key).first ?? "")
    }
    func targets(forCommand command: String) -> [UInt32] {
        let focusesSelection = command == "focus" || command.hasPrefix("focus ")
        return focusesSelection || marks.isEmpty ? selectedId.map { [$0] } ?? [] : marks
    }
    func acceptInlineResult(_ ids: [UInt32]) {
        inlineIds = Set(ids)
        searchError = nil
        selection = min(selection, max(results.count - 1, 0))
        if settings.presentation == "miniatures" { revealMiniatureSelection() }
        objectWillChange.send()
    }
    func rejectInlineResult(_ error: String) { searchError = error.components(separatedBy: .newlines).first }
    func setMiniatureLanding(_ frame: CGRect?) { miniatureLanding = frame }
    func changePresentation(_ presentation: String) {
        let selected = selectedId
        settings.presentation = presentation
        if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
        objectWillChange.send()
    }
}
