import AppKit
import Common

@MainActor
final class ModeEngine {
    static let shared = ModeEngine(closeLens: { SwitcherPalettePanel.shared.dismiss() })
    @TaskLocal private static var inputAction: Int?
    private struct LensEntry: Sendable {
        let engine: ObjectIdentifier
        let generation: Int
    }
    @TaskLocal private static var lensEntry: LensEntry?
    private(set) var current: String? = mainModeId
    private(set) var properties: Mode = .zero
    private(set) var entryModifiers: NSEvent.ModifierFlags = []
    private(set) var entryChordModifiers: NSEvent.ModifierFlags = []
    private(set) var textModifiers: NSEvent.ModifierFlags = []
    private(set) var pending: [ModeChord] = []
    private(set) var count: Int?
    private(set) var pendingNames = ""
    private var returnMode = mainModeId
    private var generation = 0
    private var configurationRevision = 0
    var revision: Int { generation + configurationRevision }
    private var opening = false
    private var lensIsOpen = false
    private var lensOwner: Int?
    private var entering = false
    private var readyAction: (@MainActor () async -> Void)?
    private var released = false
    private var deadlinePassed = true
    private var draw: (() -> Void)?
    private var queued: [() async -> Void] = []
    private var inputTask: Task<Void, Never>?
    private var headTask: Task<Void, Never>?
    private var inputEpoch = 0
    private var inputCount = 0
    private var nextInputAction = 0
    private var runningInputActions = Set<Int>()
    private(set) var releasing = false
    var inputIsIdle: Bool { inputCount == 0 && !opening }
    /// True only in the queued action itself; a Task it spawns inherits the task-local but outlives the action.
    private var isRunningInput: Bool { Self.inputAction.map(runningInputActions.contains) ?? false }
    private var readinessTask: Task<Void, Never>?
    private var readinessGeneration = 0
    private var delayTask: Task<Void, Never>?
    private let clock: any Clock<Duration>
    var liveModifiers: () -> NSEvent.ModifierFlags
    private let closeLens: () -> Void
    var changed: () -> Void = {}
    var modeChanged: () -> Void = {}
    var didEnter: (String?, String?) async throws -> Void = { _, _ in }
    var execute: ([any Command]) async throws -> Void = executeModeCommands

    init(clock: any Clock<Duration> = ContinuousClock(), liveModifiers: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }, closeLens: @escaping () -> Void = {}) {
        self.clock = clock; self.liveModifiers = liveModifiers; self.closeLens = closeLens
    }

    func enter(_ name: String?, mode: Mode, invocation: ModeInvocation? = nil, cli: Bool = false, preservingLens: Bool = false) async throws {
        if name == mainModeId, lensIsOpen, !preservingLens {
            lensOwner = nil
            closeLens()
        }
        let previous = current
        replace(name, mode: mode, invocation: invocation, cli: cli)
        let ticket = generation
        entering = true
        if mode.opensLens { opening = true; lensOwner = ticket }
        var failure: (any Error)?
        do {
            if previous != name { try await didEnter(previous, name) }
            try await Self.$lensEntry.withValue(LensEntry(engine: ObjectIdentifier(self), generation: ticket)) {
                try await perform(mode.onEnter, generation: ticket)
            }
        } catch { failure = error }
        if generation == ticket {
            entering = false
            let ready: @MainActor () async -> Void = readyAction ?? { [self] in
                await finishReady()
            }
            readyAction = nil
            if isRunningInput { await ready() }
            else {
                await enqueueInput { [self] in
                    guard generation == ticket else { return }
                    await ready()
                }.value
            }
        }
        if let failure { throw failure }
    }

    func replace(_ name: String?, mode: Mode, invocation: ModeInvocation? = nil, cli: Bool = false) {
        entering = false
        releasing = false
        readyAction = nil
        let previous = current ?? mainModeId
        generation += 1
        let ticket = generation
        lensOwner = lensIsOpen && mode.requiresLens ? ticket : nil
        delayTask?.cancel()
        delayTask = nil
        draw = nil
        pending = []; pendingNames = ""; count = nil
        textModifiers = mode.unbound == .type ? entryModifiers : []
        properties = mode
        returnMode = previous
        current = name
        released = false
        entryModifiers = mode.lifetime == .held && !cli ? invocation?.holdModifiers ?? [] : []
        entryChordModifiers = entryModifiers.isEmpty ? [] : invocation?.invoking ?? []
        deadlinePassed = entryModifiers.isEmpty || mode.drawDelay <= 0
        if !deadlinePassed {
            let clock = self.clock
            delayTask = Task { @MainActor [weak self] in
                do { try await clock.sleep(for: .milliseconds(mode.drawDelay)) } catch { return }
                guard let self, self.generation == ticket else { return }
                self.enqueueInput { [weak self] in
                    guard let self, self.generation == ticket else { return }
                    await self.observeModifiers(self.liveModifiers())
                    guard self.generation == ticket else { return }
                    self.deadlinePassed = true
                    let draw = self.draw; self.draw = nil; draw?()
                }
                await self.waitForInput()
                if self.generation == ticket { self.delayTask = nil }
            }
        }
        changed()
        modeChanged()
    }

    func lensOpening() {
        opening = true; lensIsOpen = true
        let entry = Self.lensEntry
        lensOwner = entry?.engine == ObjectIdentifier(self) && entry?.generation == generation ? generation : nil
    }
    func reconfigure(_ mode: Mode) {
        configurationRevision += 1
        properties = mode
        if mode.lifetime != .held {
            entryModifiers = []; entryChordModifiers = []
            delayTask?.cancel(); delayTask = nil
            deadlinePassed = true
            let draw = self.draw; self.draw = nil; draw?()
        }
        pending = []; pendingNames = ""; count = nil
        changed()
        modeChanged()
    }
    var isOpening: Bool { opening }
    var delaysDrawing: Bool { !deadlinePassed }
    @discardableResult
    func enqueueInput(_ action: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        enqueueInput(after: inputTask, epoch: inputEpoch, action)
    }
    @discardableResult
    private func enqueueHeadInput(_ action: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let next = enqueueInput(after: headTask, epoch: nil, action)
        headTask = next
        return next
    }
    private func enqueueInput(after previous: Task<Void, Never>?, epoch: Int?, _ action: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        inputCount += 1
        nextInputAction += 1
        let id = nextInputAction
        let next = Task { @MainActor [self] in
            // Dropped work still counts until the chain before it ends, so an interrupted action keeps the queue busy.
            defer { inputCount -= 1 }
            await previous?.value
            guard epoch == nil || inputEpoch == epoch, !Task.isCancelled else { return }
            runningInputActions.insert(id)
            defer { runningInputActions.remove(id) }
            await Self.$inputAction.withValue(id) { await action() }
        }
        inputTask = next
        return next
    }
    func interruptOpening(_ action: @escaping @MainActor () async -> Void) {
        queued = []; readyAction = nil
        inputEpoch += 1
        enqueueHeadInput(action)
    }
    private func returnToMainAfterLensCloses(owner ticket: Int?) {
        guard let ticket, ticket == generation, current != mainModeId else { return }
        let tail = inputTask
        let head = enqueueHeadInput { [self] in
            guard generation == ticket, lensOwner != ticket else { return }
            await enterMain(reason: "Lens close")
        }
        // Input queued before the dismiss still runs, so later input waits for it as well as for the return.
        inputTask = Task { await tail?.value; await head.value }
    }
    private func enterMain(reason: String) async {
        do { try await enter(mainModeId, mode: config.modes[mainModeId] ?? .zero, preservingLens: true) }
        catch { lensLog.error("Mode \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)") }
    }
    func presentLens(show: @escaping () -> Void, flags: NSEvent.ModifierFlags? = nil, readModifiers: (() -> NSEvent.ModifierFlags)? = nil) {
        let read = readModifiers ?? { flags ?? self.liveModifiers() }
        if entering {
            readyAction = { [weak self] in
                guard let self else { return }
                await self.lensReady(show: show, flags: read())
            }
            return
        }
        if entryModifiers.isEmpty && !released && deadlinePassed && queued.isEmpty {
            opening = false
            _ = read()
            show()
        } else {
            readinessGeneration += 1
            let ticket = readinessGeneration
            readinessTask = enqueueInput { [weak self] in
                guard let self, self.readinessGeneration == ticket else { return }
                defer { if self.readinessGeneration == ticket { self.readinessTask = nil } }
                await self.lensReady(show: show, flags: read())
            }
        }
    }
    func waitForReadiness() async { await readinessTask?.value }
    func waitForInput() async { await inputTask?.value }
    func lensReady(show: @escaping () -> Void, flags: NSEvent.ModifierFlags) async {
        let ticket = readinessGeneration
        await finishReady(flags: flags)
        guard lensIsOpen, readinessGeneration == ticket, !Task.isCancelled else { return }
        if deadlinePassed { show() } else { draw = show }
    }
    private func finishReady(flags: NSEvent.ModifierFlags? = nil, actions: [() async -> Void]? = nil, cancelledOwner: Int? = nil) async {
        let epoch = inputEpoch
        let eventFlags = flags ?? (entryModifiers.isEmpty ? textModifiers : liveModifiers())
        let failedOwner = cancelledOwner ?? (actions == nil && opening && !lensIsOpen ? lensOwner : nil)
        let queued: [() async -> Void]
        if let actions { queued = actions }
        else {
            queued = self.queued; self.queued = []; opening = false
        }
        for action in queued {
            guard inputEpoch == epoch, !Task.isCancelled else { return }
            await action()
        }
        guard inputEpoch == epoch, !Task.isCancelled else { return }
        await observeModifiers(queued.isEmpty ? eventFlags : liveModifiers())
        guard inputEpoch == epoch, !Task.isCancelled else { return }
        if let failedOwner, generation == failedOwner, !lensIsOpen {
            await enterMain(reason: "cancelled Lens opening")
        }
    }
    func whenLensReady(_ action: @escaping @MainActor () async -> Void) {
        if opening { queued.append(action) } else { enqueueInput(action) }
    }
    func lensClosed(preserveOpeningInput: Bool = false) {
        let owner = lensOwner
        lensOwner = nil
        lensIsOpen = false; draw = nil; readyAction = nil
        readinessGeneration += 1
        readinessTask = nil
        if !preserveOpeningInput {
            opening = false; queued = []
            returnToMainAfterLensCloses(owner: owner)
            return
        }
        let parked = queued
        queued = []; opening = false
        let drain: @MainActor () async -> Void = { [weak self] in
            guard let self, !self.lensIsOpen else { return }
            await self.finishReady(actions: parked, cancelledOwner: owner)
        }
        if entering { readyAction = drain }
        else { enqueueInput(drain) }
    }

    func noteModifiers(_ flags: NSEvent.ModifierFlags) {
        textModifiers.formIntersection(flags)
        guard !entryModifiers.isEmpty else { return }
        if opening {
            recordOpeningRelease(flags)
        } else if flags.intersection(entryModifiers).isEmpty && !released {
            enqueueInput { [weak self] in await self?.observeModifiers(flags) }
        }
    }
    private func recordOpeningRelease(_ flags: NSEvent.ModifierFlags) {
        guard !entryModifiers.isEmpty, flags.intersection(entryModifiers).isEmpty, !released else { return }
        released = true
        queued.append { [weak self] in
            guard let self else { return }
            self.released = false
            await self.observeModifiers(flags)
        }
    }
    func observeModifiers(_ flags: NSEvent.ModifierFlags) async {
        textModifiers.formIntersection(flags)
        if opening { recordOpeningRelease(flags); return }
        guard !entryModifiers.isEmpty, flags.intersection(entryModifiers).isEmpty, !released else { return }
        released = true
        changed()
        await finishRelease()
    }
    private func finishRelease() async {
        guard released else { return }
        released = false
        entryModifiers = []
        releasing = true
        let ticket = generation
        do {
            try await execute(properties.onRelease.compactMap { if case .cmd(let command) = parseCommand($0) { command } else { nil } })
        } catch { lensLog.error("Mode release: \(error.localizedDescription, privacy: .public)") }
        if generation == ticket {
            if lensOwner == ticket {
                lensOwner = nil
                closeLens()
            }
            await enterMain(reason: "release return")
        }
    }

    private func perform(_ commands: [String], generation ticket: Int) async throws {
        for raw in commands {
            guard generation == ticket, !Task.isCancelled else { return }
            if case .cmd(let command) = parseCommand(raw) { try await execute([command]) }
        }
    }

    func resolve(_ chord: ModeChord, characters: String, keymap: [KeymapBlock], context: KeyContext, peeking: Bool = false, composing: Bool = false) -> ModeKeyResolution {
        let result = resolveModeKey(keymap: keymap, context: context, mode: properties, chord: chord, characters: characters,
                                    entryModifiers: entryModifiers, entryChordModifiers: entryChordModifiers, pending: pending, count: count, peeking: peeking, composing: composing, typingModifiers: textModifiers)
        let stateChanged = pending != result.pending || count != result.count
        pending = result.pending
        count = result.count
        pendingNames = pending.map { chord in
            let name = config.keyMapping.resolve().filter { UInt16($0.value.carbonKeyCode) == chord.code }.map(\.key).sorted().first ?? "?"
            let modifiers = chord.modifiers.toString()
            return modifiers.isEmpty ? name : "\(modifiers)-\(name)"
        }.joined(separator: " ")
        if stateChanged { changed() }
        return result
    }
    func cancelPending() {
        guard !pending.isEmpty || count != nil else { return }
        pending = []; pendingNames = ""; count = nil; changed()
    }
    func transientFinished(_ entered: String?) async throws {
        if current == entered, properties.lifetime == .transient { try await enter(returnMode, mode: config.modes[returnMode] ?? .zero) }
    }
}

@MainActor private func executeModeCommands(_ commands: [any Command]) async throws {
    guard !commands.isEmpty else { return }
    let run: @MainActor () async throws -> Void = {
        let result = try await commands.runCmdSeq(.defaultEnv, .emptyStdin)
        if result.exitCode != 0 { lensLog.error("Mode command: \(result.stderr.joined(separator: "; "), privacy: .public)") }
    }
    if refreshSessionEvent != nil || isUnitTest { try await run() }
    else if let token: RunSessionGuard = .isServerEnabled {
        try await runLightSession(.hotkeyBinding, token, body: run)
    }
}
