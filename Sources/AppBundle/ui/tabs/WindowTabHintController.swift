import AppKit
import Combine

@MainActor
final class WindowTabHintController: ObservableObject {
    static let shared: WindowTabHintController = WindowTabHintController(
        allowed: { !hotkeysSuspended && TrayMenuModel.shared.isEnabled && config.windowTabs.enabled },
        lensOpen: { SwitcherPalettePanel.shared.session != nil },
        bindings: { Array(activeMode.flatMap { config.modes[$0] }?.bindings.values ?? [:].values) },
    )
    private static let delay: Duration = .milliseconds(500)

    private(set) var shownModifiers: NSEvent.ModifierFlags?
    /// Each labelled tab's key, by the window id the strip draws for that tab. The strip view reads
    /// this directly, so the strip models never carry a label.
    @Published private(set) var labels: [UInt32: String] = [:]
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
        apply(windowTabHintModifiers(flags))
        publish()
    }

    func keyOrClick() {
        state.keyOrClick(allowed: allowed)
        publish()
    }

    func pointerActivity(_ type: NSEvent.EventType) {
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) { keyOrClick() }
        else { reconcile() }
    }

    func reset() {
        state.reset()
        publish()
    }

    /// Catches up with the live modifiers, which differ from the last `flagsChanged` only when
    /// macOS dropped an event, then rechecks the gates and the addressed group.
    func reconcile() {
        apply(windowTabHintModifiers(liveFlags()))
        publish()
    }

    private func apply(_ flags: NSEvent.ModifierFlags) {
        state.flagsChanged(flags, hasBindings: bindings.contains { $0.modifiers == flags && windowTabBindingTarget($0) != nil }, allowed: allowed)
    }

    private func publish() {
        state.enforce(allowed: allowed)
        if scheduledToken != state.deadline {
            task?.cancel()
            task = nil
            scheduledToken = state.deadline
            if let token = state.deadline {
                task = Task { @MainActor [weak self, clock] in
                    do { try await clock.sleep(for: Self.delay) } catch { return }
                    guard let self else { return }
                    self.state.fire(token, liveFlags: windowTabHintModifiers(self.liveFlags()), allowed: self.allowed)
                    self.reconcile()
                }
            }
        }
        shownModifiers = state.shown
        let labels = currentLabels()
        if self.labels != labels { self.labels = labels }
    }

    private func currentLabels() -> [UInt32: String] {
        guard let modifiers = shownModifiers, let group = resolveTabFocusTarget(focus, .last)?.group else { return [:] }
        let labels = windowTabHintLabels(bindings: bindings, modifiers: modifiers, childCount: group.children.count, isTabGroup: group.isWindowTabGroup)
        var result: [UInt32: String] = [:]
        for (index, child) in group.children.enumerated() {
            if let window = child.tabRepresentativeWindow, let label = labels[index] { result[window.windowId] = label }
        }
        return result
    }
}
