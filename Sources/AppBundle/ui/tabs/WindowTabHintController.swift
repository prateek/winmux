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

    init(clock: any Clock<Duration> = ContinuousClock(), liveFlags: @escaping () -> NSEvent.ModifierFlags = { NSEvent.ModifierFlags(rawValue: UInt(currentSessionModifierFlags().rawValue)) }, allowed: @escaping () -> Bool, lensOpen: @escaping () -> Bool, bindings: @escaping () -> [HotkeyBinding]) {
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

    /// A key or click catches up from its own event's modifiers, which are in order with the
    /// `flagsChanged` events: the live state can be ahead of them, and would spoil a hold the
    /// key came before. A registered hotkey reaches here with no event.
    func keyOrClick(eventFlags: NSEvent.ModifierFlags? = nil) {
        if let eventFlags { catchUp(windowTabHintModifiers(eventFlags)) }
        state.keyOrClick()
        publish()
    }

    func pointerActivity(_ type: NSEvent.EventType, eventFlags: NSEvent.ModifierFlags) {
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) { return keyOrClick(eventFlags: eventFlags) }
        catchUp(windowTabHintModifiers(eventFlags))
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
        state.flagsChanged(flags, hasBindings: { self.bindings.contains { $0.modifiers == flags && windowTabBindingTarget($0) != nil } }, allowed: self.allowed)
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
        if shownChanged || relabel || state.shown != nil {
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
        return WindowTabHintLabels(group: group, byWindow: byWindow)
    }
}

/// A window can stand for a tab in more than one strip (a nested group's window also represents
/// its outer tab), so a label belongs to the addressed group's strip only. The group is held weakly:
/// a strip whose container reuses a freed group's address never matches it.
struct WindowTabHintLabels: Equatable {
    weak var group: TilingContainer?
    var byWindow: [UInt32: String] = [:]

    func label(strip: ObjectIdentifier, window: UInt32) -> String? {
        group.map(ObjectIdentifier.init) == strip ? byWindow[window] : nil
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.group === rhs.group && lhs.byWindow == rhs.byWindow
    }
}
