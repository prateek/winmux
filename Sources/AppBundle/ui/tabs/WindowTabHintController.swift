import AppKit
import Combine

@MainActor
final class WindowTabHintController: ObservableObject {
    static let shared: WindowTabHintController = WindowTabHintController(
        allowed: { !hotkeysSuspended && TrayMenuModel.shared.isEnabled && config.windowTabs.enabled },
        lensOpen: { SwitcherPalettePanel.shared.isLensOpen },
        bindings: { Array(activeMode.flatMap { config.modes[$0] }?.bindings.values ?? [:].values) },
    )
    private static let delay: Duration = .milliseconds(500)

    private(set) var shownModifiers: NSEvent.ModifierFlags?
    /// The addressed group's tab keys. The strip view reads this directly, so the strip models never
    /// carry a label.
    @Published private(set) var labels = WindowTabHintLabels()
    private var state = WindowTabHintState()
    private var task: Task<Void, Never>?
    private var scheduledToken: Int?
    private let clock: any Clock<Duration>
    private let liveFlags: () -> NSEvent.ModifierFlags
    private let enabled: () -> Bool
    private let lensOpen: () -> Bool
    private let bindingSource: () -> [HotkeyBinding]

    init(clock: any Clock<Duration> = ContinuousClock(), liveFlags: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }, allowed: @escaping () -> Bool, lensOpen: @escaping () -> Bool, bindings: @escaping () -> [HotkeyBinding]) {
        self.clock = clock
        self.liveFlags = liveFlags
        self.enabled = allowed
        self.lensOpen = lensOpen
        self.bindingSource = bindings
    }

    private var allowed: Bool {
        enabled() && !lensOpen()
    }

    private var bindings: [HotkeyBinding] {
        bindingSource()
    }

    func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        catchUp(windowTabHintModifiers(flags))
        publish()
    }

    func keyOrClick() {
        catchUpWithLiveFlags()
        state.keyOrClick(allowed: allowed)
        publish()
    }

    func pointerActivity(_ type: NSEvent.EventType) {
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) { return keyOrClick() }
        catchUpWithLiveFlags()
        publish()
    }

    func reset() {
        state.reset()
        publish()
    }

    /// Rechecks the gates and the addressed group, after a strip rebuild or a Lens opening or closing.
    func reconcile() {
        catchUpWithLiveFlags()
        publish(relabel: true)
    }

    /// The live modifiers differ from the last `flagsChanged` only when macOS dropped an event.
    private func catchUpWithLiveFlags() {
        catchUp(windowTabHintModifiers(liveFlags()))
    }

    private func catchUp(_ flags: NSEvent.ModifierFlags) {
        guard flags != state.held else { return }
        state.flagsChanged(flags, hasBindings: { self.bindings.contains { $0.modifiers == flags && windowTabBindingTarget($0) != nil } }, allowed: allowed)
    }

    private func publish(relabel: Bool = false) {
        if state.shown != nil || state.deadline != nil { state.enforce(allowed: allowed) }
        if scheduledToken != state.deadline {
            task?.cancel()
            task = nil
            scheduledToken = state.deadline
            if let token = state.deadline {
                task = Task { @MainActor [weak self, clock] in
                    do { try await clock.sleep(for: Self.delay) } catch { return }
                    guard let self else { return }
                    self.catchUpWithLiveFlags()
                    self.state.fire(token, allowed: self.allowed)
                    self.publish(relabel: true)
                }
            }
        }
        let shownChanged = shownModifiers != state.shown
        shownModifiers = state.shown
        if shownChanged || relabel {
            let labels = currentLabels()
            if self.labels != labels { self.labels = labels }
        }
    }

    private func currentLabels() -> WindowTabHintLabels {
        guard let modifiers = shownModifiers, let group = resolveTabFocusTarget(focus, .last)?.group else { return WindowTabHintLabels() }
        let labels = windowTabHintLabels(bindings: bindings, modifiers: modifiers, childCount: group.children.count, isTabGroup: group.isWindowTabGroup)
        var byWindow: [UInt32: String] = [:]
        for (index, child) in group.children.enumerated() {
            if let window = child.tabRepresentativeWindow, let label = labels[index] { byWindow[window.windowId] = label }
        }
        return WindowTabHintLabels(group: ObjectIdentifier(group), byWindow: byWindow)
    }
}

/// A window can stand for a tab in more than one strip (a nested group's window also represents
/// its outer tab), so a label belongs to the addressed group's strip only.
struct WindowTabHintLabels: Equatable {
    var group: ObjectIdentifier?
    var byWindow: [UInt32: String] = [:]

    func label(strip: ObjectIdentifier, window: UInt32) -> String? {
        strip == group ? byWindow[window] : nil
    }
}
