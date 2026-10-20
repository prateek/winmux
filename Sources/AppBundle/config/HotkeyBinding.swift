import AppKit
import Common
import Foundation
import HotKey
import TOMLKit

@MainActor private var hotkeys: [String: HotKey] = [:]
@MainActor private var activeTapBindings: [TapModifierKey: TapBinding] = [:]
@MainActor private var pendingTapBindings: [TapModifierKey: TapBinding] = [:]
@MainActor private var pressedTapModifiers: Set<TapModifierKey> = []
@MainActor private var pendingTapTriggerTasks: [TapModifierKey: Task<Void, Never>] = [:]
@MainActor private var pendingTapTriggerTokens: [TapModifierKey: Int] = [:]
@MainActor private var nextTapTriggerToken = 0
@MainActor private(set) var hotkeysSuspended = false
private let tapBindingTriggerDelayNs: UInt64 = 75_000_000

@MainActor func resetHotKeys() {
    invalidateModeRegistrations()
    WindowTabHintController.shared.reset()
    FindFocusHighlight.shared.dismiss()
    // Explicitly unregister all hotkeys. We cannot always rely on destruction of the HotKey object to trigger
    // unregistration because we might be running inside a hotkey handler that is keeping its HotKey object alive.
    for (_, key) in hotkeys {
        key.isEnabled = false
    }
    hotkeys = [:]
    activeTapBindings = [:]
    pendingTapBindings = [:]
    pressedTapModifiers = []
    cancelPendingTapTriggers()
    hotkeysSuspended = false
}

extension HotKey {
    var isEnabled: Bool {
        get { !isPaused }
        set {
            if isEnabled != newValue {
                isPaused = !newValue
            }
        }
    }
}

@MainActor var activeMode: String? {
    ModeEngine.shared.current
}
@MainActor func setHotkeysSuspended(_ suspended: Bool) {
    if hotkeysSuspended == suspended { return }
    hotkeysSuspended = suspended
    WindowTabHintController.shared.reconcile()
    if suspended {
        pendingTapBindings = [:]
        pressedTapModifiers = []
        cancelPendingTapTriggers()
    }
    applyHotkeyEnabledState()
}

@MainActor func activateMode(_ targetMode: String?, reenter: Bool = true) async throws {
    WindowTabHintController.shared.reset()
    let mode = targetMode.flatMap { config.modes[$0] }
    ModeEngine.shared.changed = { reconcileModeContext() }
    ModeEngine.shared.modeChanged = {
        activeTapBindings = ModeEngine.shared.properties.tapBindings.values.reduce(into: [:]) { $0[$1.trigger] = $1 }
        pendingTapBindings = [:]
        pressedTapModifiers = []
        cancelPendingTapTriggers()
        SwitcherPalettePanel.shared.currentModeChanged()
    }
    ModeEngine.shared.didEnter = { _, target in
        broadcastEvent(.modeChanged(mode: target))
        if !config.onModeChanged.isEmpty {
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.onModeChanged, token) {
                _ = try await config.onModeChanged.runCmdSeq(.defaultEnv, .emptyStdin)
            }
        }
    }
    if !reenter, ModeEngine.shared.current == targetMode { ModeEngine.shared.reconfigure(mode ?? .zero) }
    else { try await ModeEngine.shared.enter(targetMode, mode: mode ?? .zero, invocation: modeInvocation, cli: modeInvocation == nil) }
    applyHotkeyEnabledState()
    BindingModeHud.shared.refresh()
}

@MainActor func triggerBinding(_ binding: String, _ commands: [any Command], invocation: ModeInvocation? = nil, origin: LensTraceOrigin? = nil) {
    FindFocusHighlight.shared.dismiss()
    Task {
        do { try await runTriggeredBinding(binding, commands, invocation: invocation, origin: origin) }
        catch { lensLog.error("Binding: \(error.localizedDescription, privacy: .public)") }
    }
}

@MainActor func runTriggeredBinding(_ binding: String, _ commands: [any Command], invocation: ModeInvocation? = nil, origin: LensTraceOrigin? = nil) async throws {
    WindowTabHintController.shared.bindingTriggered()
    if hotkeysSuspended || !mayArrangeWindows { return }
    FindFocusHighlight.shared.dismiss()
    guard let entered = activeMode else { return }
    broadcastEvent(.bindingTriggered(mode: entered, binding: binding))
    let result = try await runLightSession(.hotkeyBinding, .checkServerIsEnabledOrDie(), shouldSchedulePostRefresh: !commands.canSkipPostCommandRefresh) {
        try await $lensTraceOrigin.withValue(origin) {
            try await $modeInvocation.withValue(invocation) { try await commands.runCmdSeq(.defaultEnv, .emptyStdin) }
        }
    }
    if result.exitCode != 0 { lensLog.error("Binding \(binding, privacy: .public): \(result.stderr.joined(separator: "; "), privacy: .public)") }
    try await ModeEngine.shared.transientFinished(entered)
}

@MainActor func noteTapBindingKeyDown() {
    if hotkeysSuspended { return }
    cancelPendingTapTriggers()
    pendingTapBindings = [:]
}

@MainActor func noteTapBindingFlagsChanged(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, origin: LensTraceOrigin? = nil) {
    WindowTabHintController.shared.flagsChanged(modifierFlags)
    SwitcherPalettePanel.shared.modifiersChanged(modifierFlags)
    if hotkeysSuspended { return }
    if activeTapBindings.isEmpty && pendingTapBindings.isEmpty && pendingTapTriggerTasks.isEmpty { return }
    guard let tapModifier = TapModifierKey(keyCode: keyCode) else { return }
    cancelPendingTapTriggers()

    // Rebuild the pressed-modifier state from the event snapshot instead of only
    // applying the single changed key. macOS can occasionally drop a modifier
    // release event; if that happens, a stale entry here makes later single-key
    // tap launchers look like multi-modifier chords and they stop firing.
    pressedTapModifiers = tapModifiersPressed(in: modifierFlags)

    if pressedTapModifiers.contains(tapModifier) {
        let hadOtherPressedModifiers = !pressedTapModifiers.subtracting([tapModifier]).isEmpty
        pendingTapBindings = [:]
        if !hadOtherPressedModifiers, let binding = activeTapBindings[tapModifier] {
            pendingTapBindings[tapModifier] = binding
        }
        return
    }

    if let binding = pendingTapBindings.removeValue(forKey: tapModifier) {
        scheduleTapBindingTrigger(binding, origin: origin)
    }
}

private func tapModifiersPressed(in modifierFlags: NSEvent.ModifierFlags) -> Set<TapModifierKey> {
    Set(TapModifierKey.allCases.filter { $0.isPressed(in: modifierFlags) })
}

@MainActor private func scheduleTapBindingTrigger(_ binding: TapBinding, origin: LensTraceOrigin?) {
    let trigger = binding.trigger
    nextTapTriggerToken += 1
    let token = nextTapTriggerToken
    pendingTapTriggerTokens[trigger] = token
    let task = Task { @MainActor in
        try? await Task.sleep(nanoseconds: tapBindingTriggerDelayNs)
        guard pendingTapTriggerTokens[trigger] == token else { return }
        pendingTapTriggerTasks[trigger] = nil
        pendingTapTriggerTokens[trigger] = nil
        guard pressedTapModifiers.isEmpty else { return }
        triggerBinding(binding.descriptionWithKeyNotation, binding.commands, origin: origin)
    }
    pendingTapTriggerTasks[trigger] = task
}

@MainActor private func cancelPendingTapTriggers() {
    for task in pendingTapTriggerTasks.values {
        task.cancel()
    }
    pendingTapTriggerTasks = [:]
    pendingTapTriggerTokens = [:]
}

@MainActor private func applyHotkeyEnabledState() {
    for (_, key) in hotkeys {
        key.isEnabled = !hotkeysSuspended
        if key.isEnabled && key.registrationError != 0 {
            lensLog.error("Carbon registration failed: \(key.registrationError)")
        }
    }
    reconcileSystemSymbolicHotkeys()
}

@MainActor func registerModeChords(_ chords: Set<ModeChord>) {
    guard mayArrangeWindows else { return }
    let wanted = Set(chords.flatMap { chord in chord.carbonKeyCodes.map { "\(chord.modifiers.rawValue)-\($0)" } })
    for id in hotkeys.keys.filter({ !wanted.contains($0) }) {
        hotkeys.removeValue(forKey: id)?.isEnabled = false
    }
    for chord in chords {
        for code in chord.carbonKeyCodes {
            guard let key = Key(carbonKeyCode: UInt32(code)) else { continue }
            let id = "\(chord.modifiers.rawValue)-\(code)"
            guard hotkeys[id] == nil else { continue }
            hotkeys[id] = HotKey(key: key, modifiers: chord.modifiers, keyDownWithTimeHandler: { time in
                Task { @MainActor in
                    guard !hotkeysSuspended else { return }
                    noteTapBindingKeyDown()
                    let text = chord.modifiers.contains(.shift) ? key.description.uppercased() : key.description.lowercased()
                    _ = handleModeKey(code: chord.code, flags: chord.modifiers, characters: text.count == 1 ? text : "", carbon: true,
                                      origin: LensTraceOrigin(start: time, received: LensTimebase.now(), source: "Carbon"))
                }
            })
        }
    }
    applyHotkeyEnabledState()
}

@MainActor func allowWindowArrangement() async {
    mayArrangeWindows = true
    do { try await activateMode(activeMode) }
    catch { lensLog.error("Hotkeys at Start: \(error.localizedDescription, privacy: .public)") }
}

@MainActor func listeningHotkeyChords() -> Set<SymbolicHotkeyChord> {
    guard !hotkeysSuspended else { return [] }
    return Set(hotkeys.compactMap { _, key in
        guard key.isEnabled, key.registrationError == 0 else { return nil }
        return SymbolicHotkeyChord(keyCode: UInt16(key.keyCombo.carbonKeyCode), modifiers: UInt64(key.keyCombo.modifiers.rawValue))
    })
}

@MainActor func modeHotkeyForTests(code: UInt16, modifiers: NSEvent.ModifierFlags = []) -> HotKey? {
    hotkeys["\(modifiers.rawValue)-\(code)"]
}

@MainActor func tapBindingPressedModifiersForTests() -> Set<TapModifierKey> {
    pressedTapModifiers
}

@MainActor func hasPendingTapBindingForTests() -> Bool {
    !pendingTapBindings.isEmpty || !pendingTapTriggerTasks.isEmpty
}
