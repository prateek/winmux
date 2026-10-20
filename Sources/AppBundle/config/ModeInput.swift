import AppKit
import Common
import HotKey

@MainActor private var registeredModeChords = Set<ModeChord>()
@MainActor private var modeContextSnapshot: KeyContext?
@MainActor private var lastExternalFrontApp: String?
@MainActor func invalidateModeRegistrations() { registeredModeChords = []; modeContextSnapshot = nil }

@MainActor func currentKeyContext(mode: String? = nil) -> KeyContext {
    let panel = SwitcherPalettePanel.shared
    let front = NSWorkspace.shared.frontmostApplication
    if let bundle = front?.bundleIdentifier, bundle != winMuxAppId { lastExternalFrontApp = bundle }
    return KeyContext(mode: mode ?? activeMode ?? "",
                      app: lastExternalFrontApp ?? focus.windowOrNil?.app.rawAppBundleId,
                      lensOpen: panel.isLensOpen, lens: panel.openLensName,
                      presentation: panel.openPresentation, columns: mayArrangeWindows ? focus.workspace.columns?.count : nil)
}

@MainActor func resolvedModeKeymap() -> [KeymapBlock] {
    if !config.keymap.isEmpty { return config.keymap }
    var errors: [TomlParseError] = []
    return parseKeymap(nil, modes: config.modes, mapping: config.keyMapping.resolve(), errors: &errors)
}

@MainActor func reconcileModeContext(pending: [ModeChord]? = nil) {
    guard mayArrangeWindows else { invalidateModeRegistrations(); return }
    let context = currentKeyContext()
    modeContextSnapshot = context
    let engine = ModeEngine.shared
    let chords = modeRegistrationChords(keymap: resolvedModeKeymap(), context: context, mode: engine.properties, entryModifiers: engine.entryModifiers, pending: pending ?? engine.pending, panelIsKey: SwitcherPalettePanel.shared.isKeyWindow)
    if chords != registeredModeChords {
        registeredModeChords = chords
        registerModeChords(chords)
    }
    BindingModeHud.shared.refresh()
}

@MainActor func refreshModeContextIfNeeded() {
    if modeContextSnapshot != currentKeyContext() { reconcileModeContext() }
}

@MainActor func observeUncapturedModeKey(code: UInt16, flags: NSEvent.ModifierFlags, characters: String) {
    let panel = SwitcherPalettePanel.shared
    guard !panel.isKeyWindow else { return }
    let engine = ModeEngine.shared
    engine.noteModifiers(flags)
    let entry = engine.entryModifiers
    let foreign = flags.subtracting(entry.union(.shift))
    if !entry.isEmpty, !flags.intersection(entry).isEmpty, !foreign.isEmpty {
        let decision = resolveModeKey(keymap: resolvedModeKeymap(), context: currentKeyContext(), mode: engine.properties,
                                      chord: .init(code: code, modifiers: flags), characters: characters, entryModifiers: entry)
        if decision.kind == .global {
            handleModeKey(code: code, flags: flags, characters: characters)
            return
        }
    }
    engine.cancelPending()
    if engine.properties.lifetime == .transient {
        let revision = engine.revision
        let entered = engine.current
        engine.enqueueInput {
            guard engine.revision == revision else { return }
            try? await engine.transientFinished(entered)
        }
    }
}

@MainActor @discardableResult
func handleModeKey(code: UInt16, flags: NSEvent.ModifierFlags, characters: String, carbon: Bool = false, origin: LensTraceOrigin? = nil, composing: Bool = false) -> Bool {
    let engine = ModeEngine.shared
    let releasesHeldMode = !engine.entryModifiers.isEmpty && flags.intersection(engine.entryModifiers).isEmpty
    engine.noteModifiers(flags)
    let inputWasIdle = engine.inputIsIdle
    let preview = resolveModeKey(keymap: resolvedModeKeymap(), context: currentKeyContext(), mode: engine.properties,
                                 chord: .init(code: code, modifiers: flags), characters: characters,
                                 entryModifiers: engine.entryModifiers, entryChordModifiers: engine.entryChordModifiers, pending: engine.pending, count: engine.count,
                                 peeking: SwitcherPalettePanel.shared.session?.zoomPeeking == true, composing: composing, typingModifiers: engine.textModifiers)
    if inputWasIdle && preview.editorOwned {
        LensModeKeyTrace(code: code, flags: flags, characters: characters, origin: origin).finish("field editor")
        return false
    }
    if inputWasIdle && preview.kind == .pass {
        LensModeKeyTrace(code: code, flags: flags, characters: characters, origin: origin).finish("pass")
        engine.cancelPending(); return false
    }
    if inputWasIdle, preview.kind == .type, !carbon, !engine.isOpening {
        let modifiers = flags.subtracting(engine.textModifiers.union(engine.entryModifiers)).intersection([.command, .control, .option])
        let text = code == 51 || (!characters.isEmpty && characters.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) })
        if SwitcherPalettePanel.shared.firstResponder is NSTextView || !modifiers.isEmpty || !text {
            LensModeKeyTrace(code: code, flags: flags, characters: characters, origin: origin).finish("field editor")
            if preview.editsSearch || (text && modifiers.isEmpty) { SwitcherPalettePanel.shared.session?.noteSearchEdit() }
            engine.cancelPending(); return false
        }
    }
    let dispatch: @MainActor () async -> Void = {
        await dispatchModeKey(code: code, flags: flags, characters: characters, carbon: carbon, origin: origin, composing: composing)
    }
    if preview.kind == .pending { reconcileModeContext(pending: preview.pending) }
    if engine.isOpening && preview.kind == .global && !releasesHeldMode { engine.interruptOpening(dispatch) }
    else if engine.isOpening { engine.whenLensReady(dispatch) }
    else { engine.enqueueInput(dispatch) }
    return true
}

@MainActor private func dispatchModeKey(code: UInt16, flags: NSEvent.ModifierFlags, characters: String, carbon: Bool, origin: LensTraceOrigin?, composing: Bool = false) async {
    let engine = ModeEngine.shared
    let panel = SwitcherPalettePanel.shared
    let trace = LensModeKeyTrace(code: code, flags: flags, characters: characters, origin: origin)
    let chord = ModeChord(code: code, modifiers: flags)
    let entry = engine.entryModifiers
    let result = engine.resolve(chord, characters: characters, keymap: resolvedModeKeymap(), context: currentKeyContext(), peeking: panel.session?.zoomPeeking == true, composing: composing)
    defer { trace.finish([String(describing: result.kind), result.target, result.bindingName].compactMap { $0 }.joined(separator: " ")) }
    do {
        switch result.kind {
            case .run:
                let commands = Array(repeating: result.commands, count: result.repetitions).flatMap { $0 }
                try await runTriggeredBinding(result.bindingName ?? "key", commands, invocation: .init(keyCode: code, invoking: flags), origin: origin)
            case .pending: break
            case .consume:
                if result.count == nil { try await engine.transientFinished(activeMode) }
            case .cancel:
                if engine.properties.lifetime == .transient { try await engine.transientFinished(activeMode) }
                else { panel.dismiss(); try await activateMode(result.target ?? mainModeId) }
            case .latch:
                guard let target = result.target, let mode = config.modes[target], mode.unbound != .latch else { return }
                try await activateMode(target)
                await dispatchModeKey(code: code, flags: flags.subtracting(entry), characters: characters, carbon: carbon, origin: origin)
            case .global:
                panel.dismiss()
                try await activateMode(mainModeId)
                let global = resolveModeKey(keymap: resolvedModeKeymap(), context: currentKeyContext(), mode: config.modes[mainModeId] ?? .zero, chord: chord, characters: characters)
                if global.kind == .run { try await runTriggeredBinding(global.bindingName ?? "key", global.commands, invocation: .init(keyCode: code, invoking: flags), origin: origin) }
            case .type: panel.typeModeKey(code: code, characters: characters)
            case .pass: break
        }
    } catch { lensLog.error("Mode key: \(error.localizedDescription, privacy: .public)") }
}
