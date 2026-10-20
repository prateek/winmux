import AppKit
import Common
import HotKey

@MainActor
final class LensSession: ObservableObject {
    let name: String
    let eventFilter: String?
    let theme: LensTheme
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
    @Published private(set) var peekedId: UInt32?
    private var peekZoom = false
    private var peekDismissed = false
    private var closedPeekIds: Set<UInt32> = []
    var peekCaptureMs: Double?
    var listRowRects: [UInt32: CGRect] = [:]
    var followsPeek: Bool { settings.followsPeek(presentation: settings.presentation) }
    var zoomPeeking: Bool { !followsPeek && peekedId != nil }

    @Published private(set) var hintsShown = false
    private var currentModifiers: NSEvent.ModifierFlags = []
    @Published private(set) var miniatureLanding: CGRect?
    @Published var miniaturePage = 0
    var thumbnailScale: CGFloat = 1
    /// `lifted` is for Presentations that enlarge the selected Tile, which any Tile can become.
    func thumbnailDemand(_ points: CGSize, lifted: Bool) -> CGSize {
        let factor = (lifted ? tileMetrics.selectionScale : 1) * thumbnailScale
        return CGSize(width: points.width * factor, height: points.height * factor)
    }

    var miniatureSize = CGSize(width: 1000, height: 700)
    private(set) var miniatureExcludedIds: Set<UInt32> = []
    var miniatureWorkspaces: [MiniatureWorkspace] = []
    @Published var listPanelHeight: CGFloat = 0
    var tilesFrameInWindow = CGRect.zero
    var hintSnapshots: [Bool: LensHintSnapshot] = [:]
    var hintContext: KeyContext?
    var hintRevision = -1
    var gridLayoutCache: GridLayoutCache?
    var stripLayoutCache: StripLayoutCache?
    weak var owner: LensLifecycle?

    enum Event {
        case peekToggled
        case searchChanged(String)
        case modeChanged
        case selectionChanged(Int)
        case pointerSelectionChanged(Int)
        case modifiersChanged(NSEvent.ModifierFlags)
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
            synchronizePeek()
            switch event {
                case .pointerSelectionChanged, .modifiersChanged, .dismissed: break
                default: reanchorPointer()
            }
        }
        switch event {
            case .peekToggled:
                // Space on a closed overview cell has nothing to grow.
                if !followsPeek, peekZoom || !closedPeekIds.contains(targets(forCommand: "focus").first ?? 0) { peekZoom.toggle() }
                // A Tile hovered before the zoom is under the picture now.
                if peekZoom { hoveredTileId = nil }
            case .modeChanged:
                let held = shouldShowHints(currentModifiers)
                if held != hintsShown { hintsShown = held }
                if isTyping, !searchEdited, !rememberedSearch.isEmpty {
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
                let held = shouldShowHints(flags)
                if held != hintsShown { hintsShown = held }
            case .presentationChanged(let presentation):
                hoveredTileId = nil
                // A Presentation that follows has no zoom; a strip that becomes a list keeps it.
                if settings.followsPeek(presentation: presentation) { peekZoom = false }
                let selected = selectedId
                let leftStrip = settings.presentation == "strip" && presentation != "strip"
                settings.presentation = presentation
                let shown = shouldShowHints(currentModifiers)
                if shown != hintsShown { hintsShown = shown }
                // A strip never shows a remembered Search; the Presentation it becomes does.
                if leftStrip, isTyping, !searchEdited, query.isEmpty, !rememberedSearch.isEmpty {
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
            case .dismissed:
                hoveredTileId = nil
                endPeekOnDismiss()
        }
        switch event {
            case .searchChanged, .modeChanged, .itemsRemoved, .excludedChanged, .presentationChanged:
                if let hoveredTileId, !results.contains(where: { $0.id == hoveredTileId }) { self.hoveredTileId = nil }
            default: break
        }
    }

    private var pointerMotion: LensPointerMotion
    private let pointerLocation: () -> CGPoint
    private var inlineIds: Set<UInt32>?
    var isTyping: Bool { ModeEngine.shared.properties.unbound == .type }
    var isHeld: Bool { !ModeEngine.shared.entryModifiers.isEmpty }
    private var rememberedSearch: String
    private let searchIsExplicit: Bool
    var searchToRemember: String { searchEdited ? query : rememberedSearch }

    func enterSearch() { Task { try await activateMode("search") } }
    func leaveSearch() { Task { try await activateMode("browse") } }
    func modeChanged() { send(.modeChanged); hintSnapshots = [:]; objectWillChange.send() }

    var bindingContext: KeyContext {
        var context = currentKeyContext()
        context.lensOpen = true; context.lens = name == "<ad-hoc>" ? nil : name; context.presentation = settings.presentation
        return context
    }
    var modeCommandStrings: [String: [String]] {
        let context = bindingContext
        var result: [String: [String]] = [:]
        for binding in winningKeyBindings(resolvedModeKeymap(), context: context, prefix: []) where binding.chords.count == 1 {
            guard result[binding.name] == nil else { continue }
            result[binding.name] = binding.commands?.map { $0.args.description } ?? []
        }
        return result
    }
    var keyBindings: [LensKeyBinding] { LensKeyBinding.resolve(modeCommandStrings) }
    var sectionsKey: String? { keyBindings.first { modeCommandStrings[$0.name] == ["lens sections next"] }?.name }

    private func keepSelectionOrSelectBest(_ selected: UInt32?) {
        if let selected, let index = results.firstIndex(where: { $0.id == selected }) { selection = index }
        else { selectBestResult() }
    }

    /// Untouched recalled Search is selected; its first edit replaces it.
    private(set) var searchEdited = false
    func noteSearchEdit() { if isTyping { searchEdited = true } }
    func typeKey(code: UInt16, characters: String) {
        let edited = searchEdited
        searchEdited = true
        if code == 51 { send(.searchChanged(edited ? String(query.dropLast()) : "")) }
        else if !characters.isEmpty { send(.searchChanged(edited ? query + characters : characters)) }
    }
    private(set) var removedIds: Set<UInt32> = []
    var onAction: ((String) -> Void)?
    var onControl: ((TileWindowControl, UInt32) -> Void)?

    init(name: String, settings: LensConfig, items: [SwitcherPaletteItem], search: String, searchIsExplicit: Bool = false, eventFilter: String? = nil, sectionIdentities: [String: [LensSectionIdentity]]? = nil, pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }, systemIsDark: () -> Bool = { LensTheme.systemIsDark }) {
        self.pointerLocation = pointerLocation
        pointerMotion = LensPointerMotion(anchor: pointerLocation())
        self.name = name
        self.eventFilter = eventFilter
        self.settings = settings
        theme = LensTheme.resolve(settings.appearance, systemIsDark: systemIsDark)
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
        rememberedSearch = search
        self.searchIsExplicit = searchIsExplicit
        // A strip has no Search row to show a recalled Search in: it waits for the list. A Search the caller asked for applies.
        let mode = ModeEngine.shared.properties
        let typing = mode.unbound == .type || (mode.unbound == .latch && config.modes[mode.latchTo]?.unbound == .type)
        query = (typing && settings.presentation != "strip") || searchIsExplicit ? search : ""
        selection = 0
        selection = initialSelection()
        hintsShown = shouldShowHints([])
        synchronizePeek()
    }

    /// The list opens on its second row when the first is the focused window. Miniatures are not
    /// drawn in sort order, so they open on the most recently focused window that is not focused.
    func initialSelection() -> Int {
        let ranked = rankedResults
        let results = results
        if ModeEngine.shared.properties.onEnter.contains("lens step prev"), let focused = results.firstIndex(where: \.isFocused) { return focused }
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
    var activeKeyBindings: [LensKeyBinding] { keyBindings }
    func isSectionsOnly(_ key: String) -> Bool { modeCommandStrings[key] == ["lens sections next"] }
    @discardableResult
    func performSectionsAction(_ key: String) -> Bool {
        guard isSectionsOnly(key) else { return false }
        changeSections("next")
        return true
    }

    func endPeekOnDismiss() {
        peekDismissed = true
        peekZoom = false
        synchronizePeek()
    }

    func synchronizePeek() {
        let selected = !peekDismissed && (followsPeek || peekZoom) ? targets(forCommand: "focus").first : nil
        if selected == nil { peekZoom = false }
        // A closed overview cell has nothing to show; the zoom waits for the next live one.
        let target = selected.flatMap { closedPeekIds.contains($0) ? nil : $0 }
        if target != peekedId { peekedId = target }
    }

    func endZoomForClick() -> Bool {
        guard zoomPeeking else { return false }
        send(.peekToggled)
        return true
    }

    /// Miniatures keeps a closed window's cell for the session, so a zoom on it ends instead of
    /// moving on, and the cell is never peeked again.
    func peekedWindowClosed(_ id: UInt32) {
        closedPeekIds.insert(id)
        if peekedId == id { send(.peekToggled) }
    }

    @discardableResult
    func performPeekAction(_ key: String) -> Bool {
        guard commands(for: key) == ["lens peek"] else { return false }
        if !followsPeek { send(.peekToggled) }
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

    func updateHintModifiers(_ modifiers: NSEvent.ModifierFlags) { send(.modifiersChanged(modifiers)) }

    private func clickModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let engine = ModeEngine.shared
        if isHeld, engine.properties.onRelease.contains("lens focus") {
            return modifiers.intersection([.control, .option, .command]).subtracting(engine.entryModifiers)
        }
        return modifiers.intersection([.control, .option, .shift, .command]).subtracting(engine.entryModifiers)
    }

    private func shouldShowHints(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        if settings.hints == "always" { return true }
        let counted = modifiers.subtracting(ModeEngine.shared.entryModifiers)
        return counted.contains(hintsModifier)
    }

    var hintsModifier: NSEvent.ModifierFlags {
        switch settings.hintsKey {
            case "cmd": .command
            case "ctrl": .control
            case "shift": .shift
            default: .option
        }
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
        guard !zoomPeeking, armed, let index = index(), index != selection else { return }
        send(.pointerSelectionChanged(index))
    }

    func reanchorPointer() { pointerMotion = LensPointerMotion(anchor: pointerLocation()) }

    func toggleMark() {
        guard let id = selectedId else { return }
        if let index = marks.firstIndex(of: id) { marks.remove(at: index) } else { marks.append(id) }
    }
    func commands(for key: String) -> [String] { modeCommandStrings[key] ?? [] }
    func targets(for key: String) -> [UInt32] {
        let command = commands(for: key).first ?? ""
        return targets(forCommand: command == "lens focus" ? "focus" : command)
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
