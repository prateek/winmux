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
    private(set) var items: [SwitcherPaletteItem]
    private var searchResultsCache: [SwitcherPaletteItem]?
    @Published var hoveredTileId: UInt32?
    @Published private(set) var query: String { didSet { searchResultsCache = nil } }
    @Published private(set) var selection: Int
    @Published private(set) var marks: [UInt32] = []
    @Published private(set) var searchError: String?
    @Published var banner: String?
    @Published private(set) var summonHeld = false
    private var currentModifiers: NSEvent.ModifierFlags = []
    @Published private(set) var miniatureLanding: CGRect?
    @Published var miniaturePage = 0
    var miniatureSize = CGSize(width: 1000, height: 700)
    private(set) var miniatureExcludedIds: Set<UInt32> = []
    var miniatureWorkspaces: [MiniatureWorkspace] = []
    var tilesFrameInWindow = CGRect.zero
    var gridLayoutCache: GridLayoutCache?
    var stripLayoutCache: StripLayoutCache?
    weak var owner: LensLifecycle?

    enum Event {
        case searchChanged(String)
        case inputStateChanged(LensInputState)
        case selectionChanged(Int)
        case pointerSelectionChanged(Int)
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
        defer {
            switch event {
                case .pointerSelectionChanged, .modifiersChanged, .summonChanged, .dismissed: break
                default: reanchorPointer()
            }
        }
        switch event {
            case .inputStateChanged(let state):
                inputState = state
                let held = shouldSummon(currentModifiers)
                if held != summonHeld { summonHeld = held }
                if state == .search, !searchEdited, !rememberedSearch.isEmpty {
                    let selected = selectedId
                    if query != rememberedSearch { query = rememberedSearch }
                    keepSelectionOrSelectBest(selected)
                    if settings.presentation == "miniatures" { revealMiniatureSelection() }
                }
            case .searchChanged(let text):
                guard text != query else { return }
                if text.hasPrefix("="), !query.hasPrefix("=") {
                    inlineIds = Set((searchResultsCache ?? filterSwitcherPaletteItems(items, query: query)).map(\.id))
                }
                query = text
                searchEdited = true
                if !text.hasPrefix("=") { searchError = nil }
                selectBestResult()
                if settings.presentation == "miniatures" { revealMiniatureSelection() }
            case .selectionChanged(let index):
                selection = index
            case .pointerSelectionChanged(let index): selection = index
            case .modifiersChanged(let flags):
                currentModifiers = flags
                let held = shouldSummon(flags)
                if held != summonHeld { summonHeld = held }
            case .summonChanged(let held):
                if held != summonHeld { summonHeld = held }
            case .presentationChanged(let presentation):
                hoveredTileId = nil
                let selected = selectedId
                let leftStrip = settings.presentation == "strip" && presentation != "strip"
                settings.presentation = presentation
                // A strip never shows a remembered Search; the Presentation it becomes does.
                if leftStrip, inputState == .search, !searchEdited, query.isEmpty, !rememberedSearch.isEmpty {
                    query = rememberedSearch
                    keepSelectionOrSelectBest(selected)
                } else if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
                objectWillChange.send()
            case .sectionsChanged(let value):
                guard drawsSections else { return }
                let selected = selectedId
                settings.sections = value
                if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
                objectWillChange.send()
            case .itemsRemoved(let ids):
                if let hoveredTileId, ids.contains(hoveredTileId) { self.hoveredTileId = nil }
                let before = results
                let selected = selectedId
                let replacement = before.prefix(selection).filter { !ids.contains($0.id) }.count
                removedIds.formUnion(ids)
                if let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
                else if drawsSections, !query.isEmpty { selectBestResult() }
                else { selection = min(replacement, max(0, results.count - 1)) }
                objectWillChange.send()
            case .excludedChanged(let ids):
                miniatureExcludedIds = ids
                selection = initialSelection()
            case .dismissed: hoveredTileId = nil
        }
        switch event {
            case .searchChanged, .inputStateChanged, .itemsRemoved, .excludedChanged, .presentationChanged:
                if let hoveredTileId, !results.contains(where: { $0.id == hoveredTileId }) { self.hoveredTileId = nil }
            default: break
        }
    }

    private var pointerMotion: LensPointerMotion
    private let pointerLocation: () -> CGPoint
    private var inlineIds: Set<UInt32>?
    let keyBindings: [LensKeyBinding]
    private let sectionsOnlyKeys: Set<String>
    /// The key the grouping control shows: the first one bound to `sections next`.
    let sectionsKey: String?
    @Published private(set) var inputState: LensInputState
    private(set) var hold: StripGesture?
    private(set) var holdEndedByKey = false
    private(set) var invokingGesture: StripGesture?
    private let startingState: LensInputState
    private var rememberedSearch: String
    /// A Search the caller asked for is applied in every state; a recalled one waits for Search.
    private let searchIsExplicit: Bool
    var searchToRemember: String { searchEdited ? query : rememberedSearch }

    func enterSearch() {
        clearHoldByKey()
        send(.inputStateChanged(.search))
        if settings.presentation == "strip" { changePresentation("list") }
    }

    func leaveSearch() { send(.inputStateChanged(.normal)) }

    private func clearHoldByKey() {
        guard inputState == .hold else { return }
        holdEndedByKey = true
        hold = nil
    }

    func endHoldByKey() {
        guard inputState == .hold else { return }
        if startingState == .search { enterSearch() }
        else {
            clearHoldByKey()
            send(.inputStateChanged(.normal))
        }
    }

    private func keepSelectionOrSelectBest(_ selected: UInt32?) {
        if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
        else { selectBestResult() }
    }

    /// Untouched recalled Search is selected; its first edit replaces it.
    private(set) var searchEdited = false
    private var holdInitialized = false
    func noteSearchEdit() {
        if inputState == .search { searchEdited = true }
    }


    func startHold(_ gesture: StripGesture?) {
        guard !holdInitialized else { return }
        holdInitialized = true
        invokingGesture = gesture
        hold = gesture?.holdModifiers.isEmpty == false ? gesture : nil
        if hold != nil {
            currentModifiers = gesture?.invoking ?? []
            inputState = .hold
        }
    }
    func endHold(flags: NSEvent.ModifierFlags, committing: Bool = false) {
        if hold?.holdEnded(flags: flags) == true {
            hold = nil
            currentModifiers = flags
            send(.inputStateChanged(committing ? .normal : startingState))
        }
    }
    var stripGesture: StripGesture?
    /// The modifiers held when the invoking ones were released before the session was ready.
    var stripReleasedWhileOpening: NSEvent.ModifierFlags?
    private(set) var removedIds: Set<UInt32> = []
    var onAction: ((String) -> Void)?
    var onControl: ((TileWindowControl, UInt32) -> Void)?

    init(name: String, settings: LensConfig, items: [SwitcherPaletteItem], search: String, searchIsExplicit: Bool = false, eventFilter: String? = nil, sectionIdentities: [String: [LensSectionIdentity]]? = nil, pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }) {
        self.pointerLocation = pointerLocation
        pointerMotion = LensPointerMotion(anchor: pointerLocation())
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
        sectionsOnlyKeys = Set(settings.keys.filter { Self.sectionsOnly($0.value) }.keys)
        sectionsKey = keyBindings.first { binding in
            (settings.keys[binding.name] ?? []).contains {
                if case .cmd(let command) = parseCommand($0), let args = command.args as? SectionsCmdArgs { return args.value.val == "next" }
                return false
            }
        }?.name
        startingState = settings.startingInputState
        inputState = startingState
        rememberedSearch = search
        self.searchIsExplicit = searchIsExplicit
        // A strip has no Search row to show a recalled Search in: it waits for the list. A Search the caller asked for applies.
        query = (startingState == .search && settings.presentation != "strip") || searchIsExplicit ? search : ""
        selection = 0
        selection = initialSelection()
    }

    /// The list opens on its second row when the first is the focused window. Miniatures are not
    /// drawn in sort order, so they open on the most recently focused window that is not focused.
    func initialSelection() -> Int {
        let ranked = rankedResults
        let results = results
        guard settings.presentation == "miniatures", query.isEmpty else {
            let index = ranked.count > 1 && ranked.first?.isFocused == true ? 1 : 0
            guard ranked.indices.contains(index) else { return 0 }
            return results.firstIndex { $0.id == ranked[index].id } ?? 0
        }
        return results.enumerated().filter { !$0.element.isFocused }.max { lhs, rhs in
            lhs.element.lastFocusedSeq == rhs.element.lastFocusedSeq ? lhs.offset > rhs.offset : lhs.element.lastFocusedSeq < rhs.element.lastFocusedSeq
        }?.offset ?? 0
    }

    var drawsSections: Bool { settings.presentation == "list" || settings.presentation == "grid" }
    var sections: [LensSection<SwitcherPaletteItem>] { sections(for: rankedResults) }
    func sections(for entries: [SwitcherPaletteItem]) -> [LensSection<SwitcherPaletteItem>] {
        lensSections(entries, grouping: drawsSections ? settings.sections : "none", identities: sectionIdentities[settings.sections] ?? [],
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
    var sectionControlMinimumWidth: CGFloat { Self.sectionControlWidth(segments: visibleSectionValues.count) * tileMetrics.scale }
    /// A list's panel keeps its width while it is open, so it leaves room for a grouping set from outside the cycle.
    var listControlMinimumWidth: CGFloat { Self.sectionControlWidth(segments: sectionCycle.count + 1) * tileMetrics.scale }
    private static func sectionControlWidth(segments: Int) -> CGFloat { CGFloat(440 + segments * 68) }
    var activeKeyBindings: [LensKeyBinding] { drawsSections ? keyBindings : keyBindings.filter { !isSectionsOnly($0.name) } }
    func isSectionsOnly(_ key: String) -> Bool { sectionsOnlyKeys.contains(key) }
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
        if searchResultsCache == nil {
            searchResultsCache = query.hasPrefix("=") ? items : filterSwitcherPaletteItems(items, query: query)
        }
        let searched = searchResultsCache!
        let items = removedIds.isEmpty ? searched : searched.filter { !removedIds.contains($0.id) }
        let available = settings.presentation == "miniatures" ? items.filter { !miniatureExcludedIds.contains($0.id) && $0.miniature?.workspace.isEmpty != true } : items
        let windows = query.hasPrefix("=") ? available.filter { inlineIds?.contains($0.id) ?? true } : available
        guard settings.entries == "app", settings.presentation != "miniatures" else { return windows }
        var seen: Set<String> = []
        return windows.filter { seen.insert($0.appIdentity).inserted }.map { representative in
            windows.filter { $0.appIdentity == representative.appIdentity }.max {
                $0.lastFocusedSeq == $1.lastFocusedSeq ? $0.id > $1.id : $0.lastFocusedSeq < $1.lastFocusedSeq
            } ?? representative
        }
    }

    /// A control changed the window's state: its Tile shows the new state while the Lens stays open.
    /// The tree's class is current at once; AX reports a window's buttons late after a state change,
    /// so the buttons stay as read when the Lens opened.
    func refreshTile(windowId: UInt32, windowClass: WindowClass) {
        func update(_ item: SwitcherPaletteItem) -> SwitcherPaletteItem {
            guard item.id == windowId else { return item }
            var item = item
            let wasMinimized = item.tile.badges.minimized
            let minimized = windowClass == .minimized
            item.tile.controls = TileControlAvailability(buttons: item.tile.buttons, windowClass: windowClass)
            item.tile.badges.minimized = minimized
            // A minimized window shows its last capture, as it does when a Lens opens over it, and
            // one restored from the tray is captured again.
            if minimized != wasMinimized {
                item.tile.frozen = minimized
                item.miniature = item.miniature?.with(frozen: minimized, tray: minimized || windowClass == .hiddenApp)
            }
            return item
        }
        items = items.map(update)
        searchResultsCache = searchResultsCache?.map(update)
        objectWillChange.send()
    }

    var miniatureSearchVisible: Bool { !query.isEmpty }

    var selectedId: UInt32? { results.indices.contains(selection) ? results[selection].id : nil }

    func key(for event: NSEvent, click: Bool = false) -> String? {
        // Return / keypad enter share a binding; a click runs that Enter action too.
        let code: UInt16 = click || event.keyCode == 76 ? 36 : event.keyCode
        let modifiers: NSEvent.ModifierFlags
        if click { modifiers = clickModifiers(event.modifierFlags) }
        else { modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command]) }
        return keyBindings.first { $0.code == code && $0.modifiers == modifiers }?.name
    }

    func enterKey(modifiers: NSEvent.ModifierFlags) -> String? {
        keyBindings.first { $0.code == 36 && $0.modifiers == modifiers }?.name
    }

    func updateSummonModifiers(_ modifiers: NSEvent.ModifierFlags) { send(.modifiersChanged(modifiers)) }

    private func clickModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        if let hold, settings.presentation == "strip" { return hold.releaseModifiers(modifiers) }
        if let hold { return modifiers.intersection([.control, .option, .shift, .command]).subtracting(hold.invoking) }
        if settings.presentation == "strip", !holdEndedByKey { return stripGesture?.releaseModifiers(modifiers) ?? [] }
        return modifiers.intersection([.control, .option, .shift, .command])
    }

    private func shouldSummon(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        let held = clickModifiers(modifiers)
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
    func hover(_ id: UInt32?, at location: CGPoint) {
        hoverIndex(at: location) { id.flatMap { id in self.results.firstIndex { $0.id == id } } }
    }

    /// The pointer moved to `location`; `index` is the entry under it, looked up only when the pointer is armed.
    func hoverIndex(at location: CGPoint, _ index: () -> Int?) {
        hoverIndex(armed: pointerMotion.moved(to: location), index)
    }

    func pointerMoved(to location: CGPoint) -> Bool { pointerMotion.moved(to: location) }

    func hoverIndex(armed: Bool, _ index: () -> Int?) {
        guard armed, let index = index(), index != selection else { return }
        send(.pointerSelectionChanged(index))
    }

    func reanchorPointer() { pointerMotion = LensPointerMotion(anchor: pointerLocation()) }

    func toggleMark() {
        guard let id = selectedId else { return }
        if let index = marks.firstIndex(of: id) { marks.remove(at: index) } else { marks.append(id) }
    }
    func keepsOpen(after key: String) -> Bool {
        (inputState == .hold || settings.presentation == "strip") && !key.hasSuffix("enter") &&
            !commands(for: key).contains { $0 == "focus" || $0.hasPrefix("focus ") || $0 == "summon" || $0.hasPrefix("summon ") }
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
        let selected = selectedId
        inlineIds = Set(ids)
        searchError = nil
        let results = results
        if let hoveredTileId, !results.contains(where: { $0.id == hoveredTileId }) { self.hoveredTileId = nil }
        send(.selectionChanged(results.firstIndex { $0.id == selected } ?? min(selection, max(results.count - 1, 0))))
        if settings.presentation == "miniatures" { revealMiniatureSelection() }
        objectWillChange.send()
    }
    func rejectInlineResult(_ error: String) { searchError = error.components(separatedBy: .newlines).first }
    func setMiniatureLanding(_ frame: CGRect?) { miniatureLanding = frame }
    func changePresentation(_ presentation: String) { send(.presentationChanged(presentation)) }
}
