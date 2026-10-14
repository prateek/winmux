import AppKit
import Common

struct LensAdHocIdentity: Equatable {
    let filter: String
    let settings: LensConfig
    let search: String?
}

@MainActor
final class LensLifecycle {
    enum PendingKey {
        case meaning(LensKeyMeaning)
        case key(code: UInt16, characters: String, holdCharacters: String?, flags: NSEvent.ModifierFlags, timestamp: Double, receivedAt: Double, source: LensKeySource)
    }
    struct Opening {
        let name: String
        let gesture: StripGesture?
        let isStrip: Bool
        var release: NSEvent.ModifierFlags?
        var prepared: LensSession?
        var keys: [LensKeyBinding] = []
        let listKeys: [LensKeyBinding]
        var pending: [PendingKey] = []
        let startingState: LensInputState
        var presentation: String
        var pendingState: LensInputState = .hold
    }
    enum State {
        case closed
        case opening(Opening)
        case ready(LensSession)
        case presented(LensSession)
    }
    struct Dependencies {
        var evaluate: LensInlineSearch.Evaluate
        var requestThumbnail: (Window, Int) -> Void
        var closeThumbnails: (Int) -> Void
        var flags: () -> NSEvent.ModifierFlags

        @MainActor
        static func live(isTesting: () -> Bool = { isUnitTest },
                         request: @escaping @MainActor (Window, Int) -> Void = { ThumbnailCache.shared.request($0, lens: $1) }) -> Self {
            let testing = isTesting()
            return Self(evaluate: { body, context, windows in
                precondition(!testing, "Unconfigured Lens dependency: NickelSupervisor.evalFilter")
                return await NickelSupervisor.shared.evalFilter(body, context: context, windows: windows)
            }, requestThumbnail: { window, token in
                precondition(!testing, "Unconfigured Lens dependency: ThumbnailCache.request")
                request(window, token)
            }, closeThumbnails: { ThumbnailCache.shared.closeLens($0) },
            flags: { NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue)) })
        }
    }

    private(set) var trace: LensOpeningTrace?
    private(set) var state: State = .closed
    var session: LensSession? {
        switch state {
            case .opening(let opening): return opening.prepared
            case .ready(let model), .presented(let model): return model
            default: return nil
        }
    }
    var openingGesture: StripGesture? {
        if case .opening(let opening) = state { return opening.gesture }
        return nil
    }
    private let clock: any Clock<Duration>
    private let emit: (ServerEvent) -> Void
    private let dependencies: Dependencies
    private let inlineSearch: LensInlineSearch
    var prepare: (LensSession) -> Void = { _ in }
    var inputStateChanged: (LensSession) -> Void = { _ in }
    var updatePresentation: (LensSession) -> Void = { _ in }
    var show: (LensSession) -> Void
    struct ShowInstruction: Equatable {
        let activate: Bool
        let focusSearch: Bool
    }
    var finishShow: (LensSession, ShowInstruction) -> Void = { _, _ in }
    var hide: () -> Void
    private var stripDisplay: Task<Void, Never>?
    private var thumbnailRefresh: Task<Void, Never>?
    private var thumbnailToken: Int?
    private var nextThumbnailToken = 0
    private(set) var searchInput: (context: JSONValue, windows: [JSONValue], ids: [UInt32]) = (.null, [], [])
    private var generation = 0
    private var identity: LensAdHocIdentity?
    private var remembered: [String: String] = [:]

    init(clock: any Clock<Duration> = ContinuousClock(), dependencies: Dependencies, emit: @escaping (ServerEvent) -> Void,
         show: @escaping (LensSession) -> Void, hide: @escaping () -> Void) {
        self.clock = clock
        self.dependencies = dependencies
        self.emit = emit
        self.show = show
        self.hide = hide
        inlineSearch = LensInlineSearch(clock: clock, evaluate: dependencies.evaluate)
    }

    // Test observation of owned work.
    enum Effect: Hashable { case search, landing, stripDisplay, thumbnails }
    var ownedEffects: Set<Effect> {
        var effects: Set<Effect> = []
        if inlineSearch.current != nil { effects.insert(.search) }
        if landingTask != nil { effects.insert(.landing) }
        if stripDisplay != nil { effects.insert(.stripDisplay) }
        if thumbnailRefresh != nil { effects.insert(.thumbnails) }
        return effects
    }
    var searchTask: Task<Void, Never>? { inlineSearch.current }

    func begin(_ name: String, toggle: Bool, strip: StripGesture? = nil, trace: LensOpeningTrace? = nil, keys: [LensKeyBinding] = [], invocation: StripGesture? = nil, settings: LensConfig? = nil, identity: LensAdHocIdentity? = nil) -> Int? {
        let modal: Bool
        if case .opening(let opening) = state { modal = opening.pendingState != .hold }
        else { modal = session?.holdEndedByKey == true }
        let sameIdentity = self.identity == identity
        let previous: String?
        if case .opening(let opening) = state { previous = opening.name } else { previous = session?.name }
        dismiss()
        if previous == name && sameIdentity && (modal || (toggle && strip == nil)) { trace?.cancel(); return nil }
        self.trace = trace
        self.identity = identity
        let presentation = settings?.presentation ?? (strip != nil ? "strip" : "list")
        let startingState = settings?.startingInputState ?? (presentation == "list" ? .search : .normal)
        state = .opening(Opening(name: name, gesture: strip ?? invocation, isStrip: strip != nil, keys: keys, listKeys: settings.map { LensKeyBinding.resolve($0.keys) } ?? keys, startingState: startingState, presentation: presentation))
        return generation
    }

    @discardableResult
    func complete(_ model: LensSession, ticket: Int, context: JSONValue = .null, windows: [JSONValue] = [], ids: [UInt32] = [], invocation: StripGesture? = nil) -> Bool {
        guard ticket == generation, case .opening(var opening) = state, opening.name == model.name else { return false }
        if model.settings.presentation == "strip", let gesture = opening.gesture ?? invocation {
            model.beginStrip(gesture)
            model.cycleStripSelection(0)
            model.stripReleasedWhileOpening = opening.release
        }
        let gesture = opening.gesture ?? invocation
        model.startHold(gesture)
        trace?.advance("session ready")
        model.owner = self
        trace?.session(model)
        searchInput = (context, windows, ids)
        if model.settings.presentation == "strip", let gesture = model.stripGesture {
            state = .ready(model)
            replay(opening.pending, to: model)
            if let release = opening.release { model.endHold(flags: release, committing: model.stripReleaseKey(flags: release) != nil) }
            guard session === model, model.settings.presentation == "strip" else { return true }
            let flags = opening.release ?? dependencies.flags()
            // A release that came before readiness runs its action once; the strip is never drawn.
            if commitStripRelease(flags, model: model) { return true }
            prepare(model)
            guard session === model, ticket == generation else { return true }
            trace?.startInterval("display delay")
            send(.modifiersChanged(flags), from: model)
            guard session === model else { return true }
            stripDisplay = Task { @MainActor [weak self, weak model] in
                do { try await gesture.waitForDisplay() } catch { return }
                guard let self, let model, ticket == self.generation, self.session === model, !Task.isCancelled else { return }
                self.stripDisplay = nil
                let flags = self.dependencies.flags()
                if self.commitStripRelease(flags, model: model) { return }
                guard self.session === model else { return }
                self.trace?.advance("display delay")
                self.presented(model)
            }
        } else {
            opening.prepared = model
            state = .opening(opening)
            presented(model)
            replay(opening.pending, to: model)
            if let release = opening.release { model.endHold(flags: release, committing: model.stripReleaseKey(flags: release) != nil) }
            // The live flags win over a release recorded while opening.
            if session === model { model.send(.modifiersChanged(dependencies.flags())) }
        }
        return true
    }

    private func replay(_ keys: [PendingKey], to model: LensSession) {
        for key in keys {
            guard session === model else { return }
            switch key {
                case .meaning(let meaning): _ = model.perform(meaning)
                case .key(let code, let characters, let holdCharacters, let flags, let timestamp, let receivedAt, let source):
                    let state = model.inputState
                    let held = model.hold != nil
                    let presentation = model.settings.presentation
                    let meaning = lensKeyMeaning(state: state, hold: model.hold ?? model.invokingGesture,
                                                 keys: model.activeKeyBindings, code: code, characters: state == .hold ? holdCharacters ?? characters : characters, flags: flags, presentation: presentation, source: source)
                    let trace = self.trace
                    switch meaning {
                        case .dismiss: dismiss()
                        case .global, .triggerGlobal, .globalBinding, .fieldEditor: break
                        default: _ = model.perform(meaning)
                    }
                    trace?.key(code: code, characters: characters, flags: flags, timestamp: timestamp,
                               presentation: presentation, state: state, hold: held, path: "opening replay",
                               destination: held && model.holdEndedByKey ? "Hold ended by key; " + model.inputState.rawValue : String(describing: meaning),
                               search: model.query, selectedId: model.selectedId, fieldEditor: false, receivedAt: receivedAt)
            }
        }
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
            emit(.lensEvent(opened: true, lens: model.eventFilter == nil ? model.name : nil, filter: model.eventFilter))
        }
        guard session === model, ticket == generation else { return }
        let firstNonStrip = !conversion && model.settings.presentation != "strip"
        finishShow(model, ShowInstruction(activate: firstNonStrip, focusSearch: firstNonStrip && model.inputState == .search))
        guard session === model, ticket == generation else { return }
        if !wasPresented, !conversion, model.inputState == .search || !model.query.isEmpty { startSearch(model) }
        if !wasPresented || restartEffects { startPresentationEffects(model) }
    }

    func send(_ event: LensSession.Event, from model: LensSession) {
        guard session === model else { return }
        if case .dismissed = event { dismiss(); return }
        let oldSearch = model.query
        let oldPresentation = model.settings.presentation
        let oldHints = model.hintsShown
        let oldInputState = model.inputState
        model.apply(event)
        trace?.session(model)
        switch event {
            case .pointerSelectionChanged: break
            default: updatePresentation(model)
        }
        if oldInputState != model.inputState { inputStateChanged(model) }
        switch event {
            case .searchChanged:
                guard oldSearch != model.query else { return }
                startSearch(model)
            case .inputStateChanged:
                if model.inputState == .search { startSearch(model) }
            case .presentationChanged:
                guard oldPresentation != model.settings.presentation else { return }
                cancelPresentationEffects()
                presented(model, restartEffects: true, conversion: true)
                return
            case .modifiersChanged:
                guard oldHints != model.hintsShown else { return }
            default: break
        }
        updateMiniatureLanding()
    }

    /// Modifier changes from the global and local monitors. Only these commit a strip's release;
    /// the panel's own `flagsChanged` events update hints alone.
    func stripFlagsChanged(_ flags: NSEvent.ModifierFlags, from model: LensSession) {
        send(.modifiersChanged(flags), from: model)
        guard session === model else { return }
        let wasHeld = model.hold != nil
        model.endHold(flags: flags, committing: model.stripReleaseKey(flags: flags) != nil)
        trace?.key(code: 65535, characters: "", flags: flags, timestamp: LensTimebase.now(),
                   presentation: model.settings.presentation, state: wasHeld ? .hold : model.inputState, hold: model.hold != nil, path: "flagsChanged",
                   destination: wasHeld && model.hold == nil ? "Hold ended" : "modifiers changed",
                   search: model.query, selectedId: model.selectedId, fieldEditor: false)
        trace?.session(model)
        _ = commitStripRelease(flags, model: model)
    }

    /// `lens` with no arguments. A session that is already a list is put in front and made key again.
    func changePresentationToList(_ model: LensSession) {
        guard session === model else { return }
        guard model.settings.presentation == "list" else { send(.presentationChanged("list"), from: model); return }
        if case .presented = state { presented(model, conversion: true) }
    }

    private func commitStripRelease(_ flags: NSEvent.ModifierFlags, model: LensSession) -> Bool {
        let key = model.stripReleaseKey(flags: flags)
        model.endHold(flags: flags, committing: key != nil)
        guard let key else { return false }
        if let action = model.onAction { action(key) } else { dismiss() }
        return true
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
        stripDisplay?.cancel()
        stripDisplay = nil
        thumbnailRefresh?.cancel()
        thumbnailRefresh = nil
        if let token = thumbnailToken { dependencies.closeThumbnails(token) }
        thumbnailToken = nil
        cancelLanding()
    }

    func cycleStrip(name: String, keyCode: UInt16, flags: NSEvent.ModifierFlags, identity: LensAdHocIdentity? = nil) -> Bool {
        guard self.identity == identity else { return false }
        if let session { return session.name == name && session.cycleStrip(keyCode: keyCode, flags: flags) }
        guard case .opening(let opening) = state, opening.name == name, opening.gesture?.step(keyCode: keyCode, flags: flags) != nil else { return false }
        return openingStripKey(keyCode: keyCode, flags: flags) == .consumed
    }

    func openingStripKey(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String = "", holdCharacters: String? = nil, timestamp: Double? = nil, source: LensKeySource = .panel) -> StripInput? {
        guard case .opening(var opening) = state, opening.prepared == nil, let gesture = opening.gesture else { return nil }
        let pending = PendingKey.key(code: keyCode, characters: characters, holdCharacters: holdCharacters,
                                     flags: flags, timestamp: timestamp ?? LensTimebase.now(), receivedAt: LensTimebase.now(), source: source)
        guard opening.pendingState != .hold || (opening.release == nil && gesture.keyCode != nil && !gesture.holdModifiers.isEmpty) else {
            // With no Hold, only a strip takes keys while it opens: its own steps, and Tab and backtick.
            guard opening.isStrip else { return nil }
            if let step = gesture.step(keyCode: keyCode, flags: flags) {
                // After the release the selection is settled: the commit waits only for the session.
                if opening.release == nil { opening.pending.append(.meaning(.step(step))); state = .opening(opening) }
                return .consumed
            }
            // Another binding drops the strip before it runs, so a settled release cannot undo it.
            return (keyCode == 48 || keyCode == 50) && gesture.owns(flags) ? .consumed : .cancel
        }
        let meaning = lensKeyMeaning(state: opening.pendingState, hold: gesture, keys: opening.keys,
                                     code: keyCode, characters: opening.pendingState == .hold ? holdCharacters ?? characters : characters,
                                     flags: flags, presentation: opening.presentation, source: source)
        switch meaning {
            case .global: return .cancel
            case .triggerGlobal: return .ignored
            case .globalBinding, .fieldEditor, .fieldEditorEdit:
                return opening.presentation == "strip" ? .cancel : .ignored
            case .dismiss:
                if opening.pendingState == .hold { return .cancel }
            case .endHold(_, let text, _):
                opening.pendingState = text == "/" ? .search : opening.startingState
                if opening.pendingState == .search, opening.presentation == "strip" {
                    opening.presentation = "list"
                    opening.keys = opening.listKeys
                }
            case .enterSearch:
                opening.pendingState = .search
                if opening.presentation == "strip" {
                    opening.presentation = "list"
                    opening.keys = opening.listKeys
                }
            case .leaveSearch: opening.pendingState = .normal
            default: break
        }
        opening.pending.append(pending)
        state = .opening(opening)
        return .consumed
    }

    /// Records a release of the invoking modifiers that happens before the session is ready, so a
    /// press that follows it cannot hide it from the live modifier state.
    func openingFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard case .opening(var opening) = state, let gesture = opening.gesture, opening.release == nil else { return }
        guard opening.isStrip || !gesture.holdModifiers.isEmpty else { return }
        if gesture.holdEnded(flags: flags) || (opening.isStrip && gesture.shouldCommit(flags: flags)) { opening.release = flags; state = .opening(opening) }
    }

    func cancelOpening(ticket: Int) {
        guard ticket == generation, case .opening = state else { return }
        dismiss()
    }

    func dismiss() {
        if case .closed = state { return }
        let model = session
        if let model {
            trace?.session(model, active: false)
            model.hoveredTileId = nil
        }
        trace?.cancel()
        trace = nil
        let wasPresented: Bool
        if case .presented = state { wasPresented = true } else { wasPresented = false }
        state = .closed
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
    private weak var evaluatedColumns: ColumnState?
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
            let source = model.miniatureWorkspaces.first { $0.name == entry.workspace }?.source ?? workspace.source
            model.setMiniatureLanding(miniatureFloatingLanding(entry.frame, from: source, to: workspace.source))
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
                        let frame = miniatureColumnLanding(placement, in: rect, horizontalGap: gaps.inner.get(.h).toDouble(),
                                                           verticalGap: gaps.inner.get(.v).toDouble(), floatingFrame: entry.frame, source: workspace.source)
                        model.setMiniatureLanding(frame)
                        return
                    }
                }
            }
            return
        }
        columnsOffLanding(model, workspace: workspace)
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
