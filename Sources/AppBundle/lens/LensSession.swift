import AppKit
import Common
import HotKey

@MainActor
final class LensSession: ObservableObject {
    let name: String
    let eventFilter: String?
    private(set) var settings: LensConfig
    let sectionIdentities: [String: [LensSectionIdentity]]
    let sectionCycle: [String]
    let items: [SwitcherPaletteItem]
    @Published private(set) var query: String
    @Published private(set) var selection: Int
    @Published private(set) var marks: [UInt32] = []
    @Published private(set) var searchError: String?
    @Published var banner: String?
    @Published private(set) var summonHeld = false
    @Published private(set) var miniatureLanding: CGRect?
    @Published var miniaturePage = 0
    var miniatureSize = CGSize(width: 1000, height: 700)
    private(set) var miniatureExcludedIds: Set<UInt32> = []
    var miniatureWorkspaces: [MiniatureWorkspace] = []
    var gridLayoutCache: GridLayoutCache?
    weak var owner: LensLifecycle?

    enum Event {
        case searchChanged(String)
        case selectionChanged(Int)
        case modifiersChanged(NSEvent.ModifierFlags)
        case summonChanged(Bool)
        case presentationChanged(String)
        case sectionsChanged(String)
        case itemsRemoved(Set<UInt32>)
        case excludedChanged(Set<UInt32>)
        case dismissed
    }

    func send(_ event: Event) {
        if let owner { owner.send(event, from: self) }
        else { apply(event) }
    }

    func apply(_ event: Event) {
        switch event {
            case .searchChanged(let text):
                guard text != query else { return }
                if text.hasPrefix("="), !query.hasPrefix("=") {
                    inlineIds = Set(filterSwitcherPaletteItems(items, query: query).map(\.id))
                }
                query = text
                searchEdited = true
                if !text.hasPrefix("=") { searchError = nil }
                selectBestResult()
                if settings.presentation == "miniatures" { revealMiniatureSelection() }
            case .selectionChanged(let index): selection = index
            case .modifiersChanged(let flags):
                let held = shouldSummon(flags)
                if held != summonHeld { summonHeld = held }
            case .summonChanged(let held):
                if held != summonHeld { summonHeld = held }
            case .presentationChanged(let presentation):
                let selected = selectedId
                settings.presentation = presentation
                if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
                objectWillChange.send()
            case .sectionsChanged(let value):
                guard drawsSections else { return }
                let selected = selectedId
                settings.sections = value
                if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
                objectWillChange.send()
            case .itemsRemoved(let ids):
                let before = results
                let selected = selectedId
                let replacement = before.prefix(selection).filter { !ids.contains($0.id) }.count
                removedIds.formUnion(ids)
                if drawsSections, !query.isEmpty { selectBestResult() }
                else { selection = results.firstIndex { $0.id == selected } ?? min(replacement, max(0, results.count - 1)) }
                objectWillChange.send()
            case .excludedChanged(let ids):
                miniatureExcludedIds = ids
                selection = initialSelection()
            case .dismissed: break
        }
    }

    private var lastPointerLocation = NSEvent.mouseLocation
    private var inlineIds: Set<UInt32>?
    let keyBindings: [LensKeyBinding]
    private(set) var hold: StripGesture?
    /// False while Search still holds what the session opened with, which is shown selected.
    private(set) var searchEdited = false
    private var holdInitialized = false

    func startHold(_ gesture: StripGesture?) {
        guard !holdInitialized else { return }
        holdInitialized = true
        hold = gesture?.holdModifiers.isEmpty == false ? gesture : nil
    }
    func endHold(flags: NSEvent.ModifierFlags) {
        if hold?.holdEnded(flags: flags) == true { hold = nil }
    }
    var stripGesture: StripGesture?
    /// The modifiers held when the invoking ones were released before the session was ready.
    var stripReleasedWhileOpening: NSEvent.ModifierFlags?
    private(set) var removedIds: Set<UInt32> = []
    var onAction: ((String) -> Void)?

    init(name: String, settings: LensConfig, items: [SwitcherPaletteItem], search: String, eventFilter: String? = nil, sectionIdentities: [String: [LensSectionIdentity]]? = nil) {
        self.name = name
        self.eventFilter = eventFilter
        self.settings = settings
        let focused = items.first(where: \.isFocused)
        var identities: [String: [LensSectionIdentity]] = [:]
        for grouping in ["workspace", "project", "monitor"] {
            var seen: Set<String> = []
            identities[grouping] = items.compactMap { item in
                let key = item.sectionKey(grouping)
                guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                return LensSectionIdentity(key: key, label: item.sectionLabel(grouping), current: focused?.sectionKey(grouping) == key)
            }
        }
        self.sectionIdentities = sectionIdentities ?? identities
        sectionCycle = ["none", "workspace", "app"] + (Set(items.map { $0.sectionKey("project") }.filter { !$0.isEmpty }).count > 1 ? ["project"] : []) + (Set(items.map { $0.sectionKey("monitor") }.filter { !$0.isEmpty }).count > 1 ? ["monitor"] : [])
        if settings.entries == "app" {
            let appCounts = Dictionary(grouping: items, by: \.appIdentity).mapValues(\.count)
            self.items = items.map { item in
                var snapshot = item
                snapshot.tile.title = snapshot.tile.appName
                snapshot.tile.appCount = appCounts[item.appIdentity]
                return snapshot
            }
        } else { self.items = items }
        keyBindings = LensKeyBinding.resolve(settings.keys)
        query = search
        selection = 0
        selection = initialSelection()
    }

    /// The list opens on its second row when the first is the focused window. Miniatures are not
    /// drawn in sort order, so they open on the most recently focused window that is not focused.
    func initialSelection() -> Int {
        let ranked = rankedResults
        let results = results
        guard settings.presentation == "miniatures", query.isEmpty else {
            let id = ranked.indices.contains(ranked.count > 1 && ranked.first?.isFocused == true ? 1 : 0) ? ranked[ranked.count > 1 && ranked.first?.isFocused == true ? 1 : 0].id : nil
            return results.firstIndex { $0.id == id } ?? 0
        }
        return results.enumerated().filter { !$0.element.isFocused }.max { lhs, rhs in
            lhs.element.lastFocusedSeq == rhs.element.lastFocusedSeq ? lhs.offset > rhs.offset : lhs.element.lastFocusedSeq < rhs.element.lastFocusedSeq
        }?.offset ?? 0
    }

    var drawsSections: Bool { settings.presentation == "list" || settings.presentation == "grid" }
    var sections: [LensSection<SwitcherPaletteItem>] {
        lensSections(rankedResults, grouping: drawsSections ? settings.sections : "none", identities: sectionIdentities[settings.sections] ?? [],
                     key: { $0.sectionKey(self.settings.sections) }, label: { $0.sectionLabel(self.settings.sections) })
    }
    var results: [SwitcherPaletteItem] { sections.flatMap(\.entries) }
    func selectBestResult() {
        let best = rankedResults.first?.id
        selection = results.firstIndex { $0.id == best } ?? 0
    }
    func changeSections(_ value: String) {
        guard drawsSections else { return }
        let next = value == "next" ? sectionCycle[(sectionCycle.firstIndex(of: settings.sections).map { $0 + 1 } ?? 0) % sectionCycle.count] : value
        send(.sectionsChanged(next))
    }
    var visibleSectionValues: [String] { sectionCycle + (sectionCycle.contains(settings.sections) ? [] : [settings.sections]) }
    var sectionControlMinimumWidth: CGFloat { CGFloat(440 + visibleSectionValues.count * 68) * tileMetrics.scale }
    var sectionsKey: String? { keyBindings.first { commands(for: $0.name).contains { if case .cmd(let command) = parseCommand($0), let args = command.args as? SectionsCmdArgs { return args.value.val == "next" }; return false } }?.name }
    var activeKeyBindings: [LensKeyBinding] { keyBindings.filter { drawsSections || !isSectionsOnly($0.name) } }
    func isSectionsOnly(_ key: String) -> Bool {
        let commands = commands(for: key)
        return Self.sectionsOnly(commands)
    }
    static func sectionsOnly(_ commands: [String]) -> Bool {
        !commands.isEmpty && commands.allSatisfy {
            if case .cmd(let command) = parseCommand($0) { return command.args is SectionsCmdArgs }
            return false
        }
    }
    static func openingBindings(_ settings: LensConfig) -> [LensKeyBinding] {
        LensKeyBinding.resolve(settings.keys.filter { _, commands in
            settings.presentation == "list" || settings.presentation == "grid" || !sectionsOnly(commands)
        })
    }
    @discardableResult
    func performSectionsAction(_ key: String) -> Bool {
        guard isSectionsOnly(key) else { return false }
        for raw in commands(for: key) {
            if case .cmd(let command) = parseCommand(raw), let args = command.args as? SectionsCmdArgs { changeSections(args.value.val) }
        }
        return true
    }

    var rankedResults: [SwitcherPaletteItem] {
        let items = removedIds.isEmpty ? items : items.filter { !removedIds.contains($0.id) }
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

    func updateSummonModifiers(_ modifiers: NSEvent.ModifierFlags) { send(.modifiersChanged(modifiers)) }

    private func shouldSummon(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        let held = settings.presentation == "strip" ? (stripGesture?.releaseModifiers(modifiers) ?? []) : modifiers.intersection([.control, .option, .shift, .command])
        return !held.isEmpty && keyBindings.contains { binding in
            binding.modifiers == held && commands(for: binding.name).contains { $0 == "summon" || $0.hasPrefix("summon ") }
        }
    }

    func performKeyAction(_ event: NSEvent) -> Bool {
        guard let key = key(for: event) else { return false }
        onAction?(key)
        return true
    }

    func moveSelection(_ delta: Int) { send(.selectionChanged(min(max(selection + delta, 0), max(results.count - 1, 0)))) }
    func hover(_ id: UInt32) { if let index = results.firstIndex(where: { $0.id == id }), index != selection { send(.selectionChanged(index)) } }
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
        selectBestResult()
        send(.selectionChanged(selection))
        if settings.presentation == "miniatures" { revealMiniatureSelection() }
        objectWillChange.send()
    }
    func rejectInlineResult(_ error: String) { searchError = error.components(separatedBy: .newlines).first }
    func setMiniatureLanding(_ frame: CGRect?) { miniatureLanding = frame }
    func changePresentation(_ presentation: String) { send(.presentationChanged(presentation)) }
}
