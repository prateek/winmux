import AppKit
import Common

@MainActor
final class LensLifecycle {
    struct Opening {
        let name: String
        let gesture: StripGesture?
        var steps = 0
        var release: NSEvent.ModifierFlags?
        var prepared: LensSession?
        var keys: [LensKeyBinding] = []
        var pending: [LensKeyMeaning] = []
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
    private let clock: any Clock<Duration>
    private let emit: (ServerEvent) -> Void
    private let dependencies: Dependencies
    private let inlineSearch: LensInlineSearch
    var prepare: (LensSession) -> Void = { _ in }
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

    func begin(_ name: String, toggle: Bool, strip: StripGesture? = nil, trace: LensOpeningTrace? = nil, keys: [LensKeyBinding] = []) -> Int? {
        let previous: String?
        if case .opening(let opening) = state { previous = opening.name } else { previous = session?.name }
        dismiss()
        if previous == name && toggle && strip == nil { trace?.cancel(); return nil }
        self.trace = trace
        state = .opening(Opening(name: name, gesture: strip, keys: keys))
        return generation
    }

    @discardableResult
    func complete(_ model: LensSession, ticket: Int, context: JSONValue = .null, windows: [JSONValue] = [], ids: [UInt32] = [], invocation: StripGesture? = nil) -> Bool {
        guard ticket == generation, case .opening(var opening) = state, opening.name == model.name else { return false }
        if model.settings.presentation == "strip", let gesture = opening.gesture ?? invocation {
            model.beginStrip(gesture)
            model.cycleStripSelection(opening.steps)
            model.stripReleasedWhileOpening = opening.release
        }
        let gesture = opening.gesture ?? invocation
        model.startHold(gesture?.keyCode == nil ? nil : gesture)
        if let release = opening.release { model.endHold(flags: release) }
        trace?.advance("session ready")
        model.owner = self
        trace?.session(model)
        searchInput = (context, windows, ids)
        if model.settings.presentation == "strip", let gesture = model.stripGesture {
            state = .ready(model)
            for meaning in opening.pending { _ = model.perform(meaning, retainTyping: true) }
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
            for meaning in opening.pending { _ = model.perform(meaning, retainTyping: true) }
        }
        return true
    }

    func presented(_ model: LensSession, restartEffects: Bool = false, conversion: Bool = false) {
        if case .opening(let opening) = state {
            guard opening.name == model.name else { return }
        } else { guard session === model else { return } }
        let wasPresented: Bool
        if case .presented = state { wasPresented = true } else { wasPresented = false }
        let ticket = generation
        show(model)
        guard ticket == generation else { return }
        state = .presented(model)
        if !wasPresented {
            emit(.lensEvent(opened: true, lens: model.eventFilter == nil ? model.name : nil, filter: model.eventFilter))
        }
        guard session === model, ticket == generation else { return }
        let firstNonStrip = !conversion && model.settings.presentation != "strip"
        finishShow(model, ShowInstruction(activate: firstNonStrip, focusSearch: firstNonStrip))
        guard session === model, ticket == generation else { return }
        if !wasPresented, !conversion, model.settings.presentation != "strip" { startSearch(model) }
        if !wasPresented || restartEffects { startPresentationEffects(model) }
    }

    func send(_ event: LensSession.Event, from model: LensSession) {
        guard session === model else { return }
        if case .dismissed = event { dismiss(); return }
        let oldSearch = model.query
        let oldPresentation = model.settings.presentation
        let oldSummon = model.summonHeld
        model.apply(event)
        trace?.session(model)
        switch event {
            case .searchChanged:
                guard oldSearch != model.query else { return }
                startSearch(model)
            case .presentationChanged:
                guard oldPresentation != model.settings.presentation else { return }
                cancelPresentationEffects()
                presented(model, restartEffects: true, conversion: true)
                return
            case .modifiersChanged:
                guard oldSummon != model.summonHeld else { return }
            case .summonChanged:
                guard oldSummon != model.summonHeld else { return }
            default: break
        }
        updateMiniatureLanding()
    }

    /// Modifier changes from the global and local monitors. Only these commit a strip's release;
    /// the panel's own `flagsChanged` events update Summon alone.
    func stripFlagsChanged(_ flags: NSEvent.ModifierFlags, from model: LensSession) {
        send(.modifiersChanged(flags), from: model)
        guard session === model else { return }
        let wasHeld = model.hold != nil
        model.endHold(flags: flags)
        trace?.key(code: 65535, characters: "", flags: flags, timestamp: LensTimebase.now(),
                   presentation: model.settings.presentation, hold: model.hold != nil, path: "flagsChanged",
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
        model.endHold(flags: flags)
        guard let key = model.stripReleaseKey(flags: flags) else { return false }
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

    func cycleStrip(name: String, keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if let session { return session.name == name && session.cycleStrip(keyCode: keyCode, flags: flags) }
        guard case .opening(let opening) = state, opening.name == name, opening.gesture?.step(keyCode: keyCode, flags: flags) != nil else { return false }
        return openingStripKey(keyCode: keyCode, flags: flags) == .consumed
    }

    /// Nil outside a chord's opening; accepted keys are replayed when its session is ready.
    func openingStripKey(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String = "", timestamp: Double? = nil) -> StripInput? {
        guard case .opening(var opening) = state, opening.prepared == nil, let gesture = opening.gesture else { return nil }
        let meaning = lensKeyMeaning(hold: opening.release == nil ? gesture : nil, keys: opening.keys,
                                     code: keyCode, characters: characters, flags: flags)
        trace?.key(code: keyCode, characters: characters, flags: flags, timestamp: timestamp ?? LensTimebase.now(),
                   presentation: "opening", hold: opening.release == nil, path: "openingStripKey",
                   destination: String(describing: meaning), search: "", selectedId: nil, fieldEditor: false)
        // A release has settled the old strip selection; later Trigger presses do not revive it.
        if opening.release != nil, gesture.step(keyCode: keyCode, flags: flags) != nil { return .consumed }
        switch meaning {
            case .step(let delta): opening.steps += delta
            case .global, .fieldEditor: return .ignored
            case .dismiss: return .cancel
            default: opening.pending.append(meaning)
        }
        state = .opening(opening)
        return .consumed
    }

    /// Records a release of the invoking modifiers that happens before the session is ready, so a
    /// press that follows it cannot hide it from the live modifier state.
    func openingFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard case .opening(var opening) = state, let gesture = opening.gesture, opening.release == nil else { return }
        if gesture.shouldCommit(flags: flags) { opening.release = flags; state = .opening(opening) }
    }

    func cancelOpening(ticket: Int) {
        guard ticket == generation, case .opening = state else { return }
        dismiss()
    }

    func dismiss() {
        if case .closed = state { return }
        let model = session
        if let model { trace?.session(model, active: false) }
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
            remembered[model.name] = model.query
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
        let key = model.summonHeld ? model.selectedId : nil
        if key != nil, key == landingKey, evaluatedDestination === focus.workspace, evaluatedColumns === focus.workspace.columns { return }
        landingRequest += 1
        let request = landingRequest
        landingKey = key
        evaluatedDestination = focus.workspace
        evaluatedColumns = focus.workspace.columns
        landingTask?.cancel()
        landingTask = nil
        model.setMiniatureLanding(nil)
        guard model.summonHeld, (model.settings.presentation == "miniatures" || model.settings.presentation == "strip"), model.settings.summonHints.contains("landing-spot"),
              let id = model.selectedId, let entry = model.items.first(where: { $0.id == id })?.miniature,
              let workspace = model.miniatureWorkspaces.first(where: { $0.current }) else { model.setMiniatureLanding(nil); return }
        if entry.workspace == workspace.name {
            model.setMiniatureLanding(model.settings.presentation == "strip" ? nil : entry.frame)
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
                              model.summonHeld, model.selectedId == id, focus.workspace === destination else { return }
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
