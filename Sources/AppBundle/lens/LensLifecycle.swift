import AppKit
import Common

struct LensAdHocIdentity: Equatable {
    let filter: String
    let settings: LensConfig
    let search: String?
    init(filter: String, settings: LensConfig, search: String? = nil) {
        self.filter = filter; self.settings = settings; self.search = search
    }
}

@MainActor
final class LensLifecycle {
    private static weak var columnsObserver: LensLifecycle?

    static func columnsChanged(on workspace: Workspace) {
        // Workspaces are created while monitors are assigned, before `focus` can be resolved.
        guard let observer = columnsObserver, workspace === focus.workspace else { return }
        observer.updateMiniatureLanding()
    }

    struct Opening {
        let name: String
        let presentation: String
    }
    enum State {
        case closed
        case opening(Opening)
        case ready(LensSession)
        case presented(LensSession)

        /// From the first `.opening` to `.closed`, before a session is prepared too.
        var isOpen: Bool {
            if case .closed = self { return false }
            return true
        }
    }
    struct Dependencies {
        var evaluate: LensInlineSearch.Evaluate
        var requestThumbnail: (Window, Int, CGSize) -> Void
        var closeThumbnails: (Int) -> Void
        var flags: () -> NSEvent.ModifierFlags
        var observeThumbnails: (Int, LensSessionStatistics) -> Void = { _, _ in }

        @MainActor
        static func live(isTesting: () -> Bool = { isUnitTest },
                         request: @escaping @MainActor (Window, Int, CGSize) -> Void = { ThumbnailCache.shared.request($0, lens: $1, demand: $2) }) -> Self {
            let testing = isTesting()
            return Self(evaluate: { body, context, windows in
                precondition(!testing, "Unconfigured Lens dependency: NickelSupervisor.evalFilter")
                return await NickelSupervisor.shared.evalFilter(body, context: context, windows: windows)
            }, requestThumbnail: { window, token, size in
                precondition(!testing, "Unconfigured Lens dependency: ThumbnailCache.request")
                request(window, token, size)
            }, closeThumbnails: { ThumbnailCache.shared.closeLens($0) },
            flags: { NSEvent.modifierFlags },
            observeThumbnails: { ThumbnailCache.shared.observeLens($0, statistics: $1) })
        }
    }

    private(set) var trace: LensOpeningTrace?
    private(set) var state: State = .closed {
        didSet { if state.isOpen != oldValue.isOpen { openChanged() } }
    }
    var isOpen: Bool { state.isOpen }
    var openName: String? {
        if case .opening(let opening) = state { return opening.name == "<ad-hoc>" ? nil : opening.name }
        return session?.eventFilter == nil ? session?.name : nil
    }
    var openPresentation: String? {
        if case .opening(let opening) = state { return opening.presentation }
        return session?.settings.presentation
    }
    var openChanged: () -> Void = {}
    var session: LensSession? {
        switch state {
            case .ready(let model), .presented(let model): return model
            default: return nil
        }
    }
    private let clock: any Clock<Duration>
    private let modeEngine: ModeEngine
    private let emit: (ServerEvent) -> Void
    private let dependencies: Dependencies
    private let inlineSearch: LensInlineSearch
    var prepare: (LensSession) -> Void = { _ in }
    var modeChanged: (LensSession) -> Void = { _ in }
    var updatePresentation: (LensSession) -> Void = { _ in }
    var show: (LensSession) -> Void
    struct ShowInstruction: Equatable {
        let activate: Bool
        let focusSearch: Bool
    }
    var finishShow: (LensSession, ShowInstruction) -> Void = { _, _ in }
    var hide: () -> Void
    var observeFrames: (LensSessionStatistics) -> Void = { _ in }
    private var thumbnailRefresh: Task<Void, Never>?
    private var thumbnailToken: Int?
    private var nextThumbnailToken = 0
    private(set) var searchInput: (context: JSONValue, windows: [JSONValue], ids: [UInt32]) = (.null, [], [])
    private var generation = 0
    private var identity: LensAdHocIdentity?
    private var remembered: [String: String] = [:]

    init(clock: any Clock<Duration> = ContinuousClock(), modeEngine: ModeEngine = .shared, dependencies: Dependencies, emit: @escaping (ServerEvent) -> Void,
         show: @escaping (LensSession) -> Void, hide: @escaping () -> Void) {
        self.clock = clock
        self.modeEngine = modeEngine
        self.dependencies = dependencies
        self.emit = emit
        self.show = show
        self.hide = hide
        inlineSearch = LensInlineSearch(clock: clock, evaluate: dependencies.evaluate)
    }

    // Test observation of owned work.
    enum Effect: Hashable { case search, landing, thumbnails }
    var ownedEffects: Set<Effect> {
        var effects: Set<Effect> = []
        if inlineSearch.current != nil { effects.insert(.search) }
        if landingTask != nil { effects.insert(.landing) }
        if thumbnailRefresh != nil { effects.insert(.thumbnails) }
        return effects
    }
    var searchTask: Task<Void, Never>? { inlineSearch.current }

    func begin(_ name: String, toggle: Bool, trace: LensOpeningTrace? = nil, settings: LensConfig? = nil, identity: LensAdHocIdentity? = nil) -> Int? {
        let previous = if case .opening(let opening) = state { opening.name } else { session?.name }
        if previous == name, self.identity == identity, toggle || identity != nil {
            dismiss()
            trace?.cancel()
            return nil
        }
        dismiss(replacing: true)
        self.trace = trace
        self.identity = identity
        state = .opening(Opening(name: name, presentation: settings?.presentation ?? "list"))
        modeEngine.lensOpening()
        return generation
    }

    @discardableResult
    func complete(_ model: LensSession, ticket: Int, context: JSONValue = .null, windows: [JSONValue] = [], ids: [UInt32] = []) -> Bool {
        guard ticket == generation, case .opening(let opening) = state, opening.name == model.name else { return false }
        model.owner = self
        Self.columnsObserver = self
        trace?.advance("session ready")
        trace?.session(model)
        searchInput = (context, windows, ids)
        state = .ready(model)
        model.send(.modifiersChanged(modeEngine.entryModifiers))
        prepare(model)
        if modeEngine.delaysDrawing { trace?.advance("display delay") }
        if !isUnitTest { reconcileModeContext() }
        modeEngine.presentLens(show: { [weak self, weak model] in
                guard let self, let model, self.generation == ticket, self.session === model else { return }
                self.presented(model)
            }, readModifiers: { [weak model, dependencies] in
                let flags = dependencies.flags()
                model?.send(.modifiersChanged(flags))
                return flags
            })
        return true
    }

    func presented(_ model: LensSession, restartEffects: Bool = false, conversion: Bool = false) {
        if case .opening(let opening) = state {
            guard opening.name == model.name else { return }
        } else { guard session === model else { return } }
        let wasPresented: Bool
        if case .presented = state { wasPresented = true } else { wasPresented = false }
        let ticket = generation
        if !wasPresented { model.reanchorPointer() }
        show(model)
        guard ticket == generation else { return }
        state = .presented(model)
        if !wasPresented {
            if let statistics = trace?.statistics {
                statistics.presented()
                observeFrames(statistics)
            }
            emit(.lensEvent(opened: true, lens: model.eventFilter == nil ? model.name : nil, filter: model.eventFilter))
        }
        guard session === model, ticket == generation else { return }
        let activateOnOpening = !conversion
        finishShow(model, ShowInstruction(activate: activateOnOpening, focusSearch: activateOnOpening && model.isTyping))
        guard session === model, ticket == generation else { return }
        if !wasPresented, !conversion, model.isTyping || !model.query.isEmpty { startSearch(model) }
        if !wasPresented || restartEffects { startPresentationEffects(model) }
    }

    func send(_ event: LensSession.Event, from model: LensSession) {
        guard session === model else { return }
        if case .dismissed = event { dismiss(); return }
        let oldSearch = model.query
        let oldPresentation = model.settings.presentation
        let oldHints = model.hintsShown
        model.apply(event)
        trace?.session(model)
        switch event {
            // A hovered selection changes no layout; only a follow picture moves with it.
            case .pointerSelectionChanged: if model.peekedId != nil { updatePresentation(model) }
            default: updatePresentation(model)
        }
        switch event {
            case .searchChanged:
                guard oldSearch != model.query else { return }
                startSearch(model)
            case .presentationChanged:
                guard oldPresentation != model.settings.presentation else { return }
                if !isUnitTest { reconcileModeContext() }
                cancelPresentationEffects()
                presented(model, restartEffects: true, conversion: true)
                return
            case .modifiersChanged:
                // A strip that opens with hints shown has no landing until a modifier event computes it.
                guard oldHints != model.hintsShown || (model.summonHintsShown && landingKey != model.selectedId) else { return }
            default: break
        }
        updateMiniatureLanding()
    }

    func modifiersChanged(_ flags: NSEvent.ModifierFlags, from model: LensSession) {
        send(.modifiersChanged(flags), from: model)
        modeEngine.noteModifiers(flags)
    }

    func currentModeChanged() {
        guard let model = session else { return }
        model.modeChanged()
        trace?.session(model)
        modeChanged(model)
        updatePresentation(model)
        if model.isTyping { startSearch(model) }
    }

    /// `lens` with no arguments. A session that is already a list is put in front and made key again.
    func changePresentationToList(_ model: LensSession) {
        guard session === model else { return }
        guard model.settings.presentation == "list" else { send(.presentationChanged("list"), from: model); return }
        if case .presented = state { presented(model, conversion: true) }
    }

    private func startSearch(_ model: LensSession) {
        inlineSearch.update(model, context: searchInput.context, windows: searchInput.windows, ids: searchInput.ids)
    }

    private func startPresentationEffects(_ model: LensSession) {
        if model.settings.presentation != "strip" { updateMiniatureLanding() }
        guard model.drawsPictures, thumbnailRefresh == nil else { return }
        nextThumbnailToken += 1
        let token = nextThumbnailToken
        thumbnailToken = token
        if let statistics = trace?.statistics { dependencies.observeThumbnails(token, statistics) }
        let ticket = generation
        let clock = self.clock
        thumbnailRefresh = Task { @MainActor [weak self, weak model] in
            await Task.yield()
            while !Task.isCancelled {
                do {
                    guard let self, let model, ticket == self.generation, self.session === model, self.thumbnailToken == token else { return }
                    model.refreshThumbnails(lens: token, request: self.dependencies.requestThumbnail)
                }
                do { try await clock.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    private func cancelPresentationEffects() {
        thumbnailRefresh?.cancel()
        thumbnailRefresh = nil
        if let token = thumbnailToken { dependencies.closeThumbnails(token) }
        thumbnailToken = nil
        cancelLanding()
    }

    func openingModifiersChanged(_ flags: NSEvent.ModifierFlags) {
        modeEngine.noteModifiers(flags)
    }

    func cancelOpening(ticket: Int) {
        guard ticket == generation, case .opening = state else { return }
        dismiss(preserveOpeningInput: true)
    }

    func dismiss(preserveOpeningInput: Bool = false, replacing: Bool = false) {
        if case .closed = state { return }
        let model = session
        trace?.statistics.stop()
        if let model {
            model.endPeekOnDismiss()
            trace?.session(model, active: false)
            model.hoveredTileId = nil
        }
        trace?.cancel()
        trace = nil
        let wasPresented: Bool
        if case .presented = state { wasPresented = true } else { wasPresented = false }
        state = .closed
        modeEngine.lensClosed(preserveOpeningInput: preserveOpeningInput, replacing: replacing)
        if Self.columnsObserver === self { Self.columnsObserver = nil }
        generation += 1
        inlineSearch.cancel()
        searchInput = (.null, [], [])
        cancelPresentationEffects()
        if let model {
            model.setMiniatureLanding(nil)
            remembered[model.name] = model.searchToRemember
            // Keep its weak owner so late events cannot revive dismissed effects.
            if wasPresented { emit(.lensEvent(opened: false, lens: model.eventFilter == nil ? model.name : nil, filter: model.eventFilter)) }
        }
        hide()
    }

    func search(for name: String, override: String?) -> String { override ?? remembered[name] ?? "" }

    private(set) var landingTask: Task<Void, Never>?
    private var landingColumnsTask: Task<JSONValue, Error>?
    private weak var landingDestination: Workspace?
    private weak var landingColumns: ColumnState?
    /// The selection the landing spot on screen, or being computed, belongs to.
    private var landingKey: UInt32?
    private weak var evaluatedDestination: Workspace?
    private var evaluatedColumns: ColumnState?
    private var landingRequest = 0

    func cancelLanding() {
        landingRequest += 1
        landingTask?.cancel()
        landingTask = nil
        landingColumnsTask?.cancel()
        landingColumnsTask = nil
        landingDestination = nil
        landingColumns = nil
        landingKey = nil
        evaluatedDestination = nil
        evaluatedColumns = nil
        session?.setMiniatureLanding(nil)
    }
    func updateMiniatureLanding() {
        guard let model = session else { return }
        // The pointer moving inside one miniature re-assigns the same selection.
        let key = model.summonHintsShown && model.settings.summonHints.contains("landing-spot") ? model.selectedId : nil
        if key != nil, key == landingKey, evaluatedDestination === focus.workspace, evaluatedColumns === focus.workspace.columns { return }
        landingRequest += 1
        let request = landingRequest
        landingKey = key
        evaluatedDestination = focus.workspace
        evaluatedColumns = focus.workspace.columns
        landingTask?.cancel()
        landingTask = nil
        model.setMiniatureLanding(nil)
        guard model.summonHintsShown, model.settings.summonHints.contains("landing-spot"),
              let id = model.selectedId, let entry = model.items.first(where: { $0.id == id })?.miniature,
              let workspace = model.miniatureWorkspaces.first(where: { $0.current }) else { model.setMiniatureLanding(nil); return }
        if entry.workspace == workspace.name {
            model.setMiniatureLanding(model.settings.presentation == "miniatures" ? entry.frame : nil)
            return
        }
        if entry.floating {
            model.setMiniatureLanding(floatingLanding(entry))
            return
        }
        if focus.workspace.columns != nil {
            let destination = focus.workspace
            landingTask = Task { @MainActor [weak self, weak model] in
                defer { if request == self?.landingRequest { self?.landingTask = nil } }
                while !Task.isCancelled {
                    guard let columns = destination.columns else {
                        guard let self, let model, request == self.landingRequest, self.session === model,
                              focus.workspace === destination else { return }
                        self.evaluatedColumns = nil
                        self.columnsOffLanding(model, workspace: workspace)
                        return
                    }
                    let snapshotTask: Task<JSONValue, Error>
                    do {
                        guard let self, let model, request == self.landingRequest, self.session === model else { return }
                        if self.landingDestination !== destination || self.landingColumns !== columns || self.landingColumnsTask == nil {
                            // The cached records describe the Column state that was replaced.
                            self.landingColumnsTask?.cancel()
                            self.landingDestination = destination
                            self.landingColumns = columns
                            self.landingColumnsTask = Task { @MainActor in try await destination.columnRecords() }
                        }
                        self.evaluatedColumns = columns
                        snapshotTask = self.landingColumnsTask!
                    }
                    let snapshot = try? await snapshotTask.value
                    do {
                        guard let self, let model, !Task.isCancelled, request == self.landingRequest, self.session === model else { return }
                        guard destination.columns === columns else { continue }
                        guard snapshot != nil else {
                            // A failed read is not kept for the session.
                            if self.landingColumnsTask == snapshotTask { self.landingColumnsTask = nil }
                            return
                        }
                    }
                    let records = snapshot?.arrayOrNil?.map { column -> JSONValue in
                        guard case .object(var fields) = column else { return column }
                        let windows = fields["windows"]?.arrayOrNil?.filter { $0["id"] != .int(Int(id)) } ?? []
                        fields["windows"] = .array(windows)
                        fields["empty"] = .bool(windows.isEmpty)
                        return .object(fields)
                    } ?? []
                    let decision = await ColumnPolicy.decision(window: entry.window, workspace: destination, columnsSnapshot: .array(records))
                    do {
                        guard let self, let model, !Task.isCancelled, request == self.landingRequest, self.session === model,
                              model.hintsShown, model.selectedId == id, focus.workspace === destination else { return }
                        guard destination.columns === columns else { continue }
                        let rect = destination.rootTilingContainer.lastAppliedLayoutPhysicalRect?.cgRect ?? workspace.source
                        let placement = ColumnPlacement.resolve(decision, columns: columns,
                                                                children: destination.rootTilingContainer.children, incoming: entry.window)
                        let gaps = ResolvedGaps(gaps: config.gaps, monitor: destination.workspaceMonitor)
                        let frame = placement.verticalRange == nil
                            ? self.floatingLanding(entry)
                            : ColumnPlacement.frame(placement, in: rect, horizontalGap: gaps.inner.get(.h).toDouble(),
                                                     verticalGap: gaps.inner.get(.v).toDouble())
                        model.setMiniatureLanding(frame)
                        return
                    }
                }
            }
            return
        }
        columnsOffLanding(model, workspace: workspace)
    }

    private func floatingLanding(_ entry: MiniatureWindow) -> CGRect {
        let destination = focus.workspace.workspaceMonitor
        if let proportion = entry.window.savedProportionalPosition {
            let size = entry.window.lastKnownActualRect?.size ?? entry.window.lastFloatingSize
            let frame = restoredFloatingWindowFrame(proportion: proportion, size: size ?? .zero, in: destination.rect.cgRect)
            // The restore clamps with no size when none was read; the window keeps its own.
            return size == nil ? CGRect(origin: frame.origin, size: entry.frame.size) : frame
        }
        guard monitors.count > 1 else { return entry.frame }
        let source = CGPoint(x: entry.frame.midX, y: entry.frame.midY).monitorApproximation
        guard source.activeWorkspace !== focus.workspace else { return entry.frame }
        return mappedFloatingWindowFrame(entry.frame, from: source.visibleRect.cgRect, to: destination.visibleRect.cgRect)
    }

    private func columnsOffLanding(_ model: LensSession, workspace: MiniatureWorkspace) {
        let root = focus.workspace.rootTilingContainer
        let rect = root.lastAppliedLayoutPhysicalRect?.cgRect ?? workspace.source
        let wraps = root.layout == .tabGroup && !root.children.isEmpty
        let orientation = wraps ? root.orientation.opposite : root.orientation
        let count = CGFloat(wraps ? 2 : root.children.count + 1)
        let gap = count > 1 ? CGFloat(ResolvedGaps(gaps: config.gaps, monitor: focus.workspace.workspaceMonitor).inner.get(orientation).toDouble()) / 2 : 0
        if orientation == .h {
            model.setMiniatureLanding(CGRect(x: rect.maxX - rect.width / count + gap, y: rect.minY, width: rect.width / count - gap, height: rect.height))
        } else {
            model.setMiniatureLanding(CGRect(x: rect.minX, y: rect.maxY - rect.height / count + gap, width: rect.width, height: rect.height / count - gap))
        }
    }
}

struct LensFilterResolution {
    let ids: [UInt32]
    let banner: String?

    init(candidateIds: [UInt32], result: Result<[Bool], NickelFailure>) {
        switch result {
            case .success(let bits):
                ids = lensFilterMatches(candidateIds, bits: bits)
                banner = nil
            case .failure(let error):
                ids = candidateIds
                banner = "Filter failed: \(error.message)"
        }
    }
}

func lensFilterMatches<T>(_ candidates: [T], bits: [Bool]) -> [T] {
    zip(candidates, bits).compactMap { candidate, matches in matches ? candidate : nil }
}
