import AppKit
import Common

@MainActor
final class ModeEngine {
    static let shared = ModeEngine(closeLens: { SwitcherPalettePanel.shared.dismiss() })
    @TaskLocal private static var inputAction: Int?
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
    private var cancelledOpening = false
    private var entering = false
    private var readyAction: (@MainActor () async -> Void)?
    private var released = false
    private var deadlinePassed = true
    private var draw: (() -> Void)?
    private var queued: [() async -> Void] = []
    private var inputTask: Task<Void, Never>?
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
    private let liveModifiers: () -> NSEvent.ModifierFlags
    private let closeLens: () -> Void
    var changed: () -> Void = {}
    var modeChanged: () -> Void = {}
    var didEnter: (String?, String?) async throws -> Void = { _, _ in }
    var execute: ([any Command]) async throws -> Void = executeModeCommands

    init(clock: any Clock<Duration> = ContinuousClock(), liveModifiers: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }, closeLens: @escaping () -> Void = {}) {
        self.clock = clock; self.liveModifiers = liveModifiers; self.closeLens = closeLens
    }

    func enter(_ name: String?, mode: Mode, invocation: ModeInvocation? = nil, cli: Bool = false) async throws {
        let previous = current
        replace(name, mode: mode, invocation: invocation, cli: cli)
        let ticket = generation
        entering = true
        if LensCommandList(mode.onEnter).containsOpener { opening = true }
        var failure: (any Error)?
        do {
            if previous != name { try await didEnter(previous, name) }
            try await perform(mode.onEnter, generation: ticket)
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

    func lensOpening() { opening = true; lensIsOpen = true }
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
        enqueueInput(after: nil, epoch: nil, action)
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
    func returnToMainAfterLensCloses() {
        guard current != mainModeId, properties.requiresLens else { return }
        let ticket = generation
        enqueueHeadInput { [self] in
            guard generation == ticket else { return }
            await leaveLensDependentMode()
        }
    }
    private func leaveLensDependentMode() async {
        guard !lensIsOpen, current != mainModeId, properties.requiresLens else { return }
        do { try await enter(mainModeId, mode: config.modes[mainModeId] ?? .zero) }
        catch { lensLog.error("Mode after Lens close: \(error.localizedDescription, privacy: .public)") }
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
    private func finishReady(flags: NSEvent.ModifierFlags? = nil, actions: [() async -> Void]? = nil) async {
        let epoch = inputEpoch
        let flags = flags ?? (entryModifiers.isEmpty ? textModifiers : liveModifiers())
        let cancelledOpening = self.cancelledOpening
        self.cancelledOpening = false
        opening = false
        let queued = actions ?? self.queued; self.queued = []
        for action in queued {
            guard inputEpoch == epoch, !Task.isCancelled else { return }
            await action()
        }
        guard inputEpoch == epoch, !Task.isCancelled else { return }
        await observeModifiers(flags)
        guard inputEpoch == epoch, !Task.isCancelled else { return }
        if cancelledOpening { await leaveLensDependentMode() }
    }
    func whenLensReady(_ action: @escaping @MainActor () async -> Void) {
        if opening { queued.append(action) } else { enqueueInput(action) }
    }
    func lensClosed(cancelMode: Bool = true, preserveOpeningInput: Bool = false) {
        lensIsOpen = false; draw = nil; readyAction = nil
        cancelledOpening = preserveOpeningInput
        if !preserveOpeningInput { opening = false; queued = [] }
        readinessGeneration += 1
        readinessTask = nil
        if cancelMode {
            delayTask?.cancel(); delayTask = nil
            entryModifiers = []; released = false
        }
        if preserveOpeningInput && !entering {
            // The parked work leaves with this drain; later keys queue behind it in arrival order.
            let parked = queued
            queued = []; opening = false
            enqueueInput { [weak self] in
                guard let self else { return }
                if self.lensIsOpen {
                    // A newer Lens owns the keyboard now and reads the release at its own ready point.
                    self.released = false
                    self.cancelledOpening = false
                    return
                }
                await self.finishReady(actions: parked)
            }
        }
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
        let ticket = generation
        queued.append { [weak self] in
            guard let self, self.generation == ticket else { return }
            await self.finishRelease()
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
            closeLens()
            do { try await enter(mainModeId, mode: config.modes[mainModeId] ?? .zero) }
            catch { lensLog.error("Mode release return: \(error.localizedDescription, privacy: .public)") }
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
