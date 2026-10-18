import AppKit
import Combine

@MainActor
final class WindowTabHintController: ObservableObject {
    static let shared: WindowTabHintController = WindowTabHintController(
        allowed: { !hotkeysSuspended && TrayMenuModel.shared.isEnabled && config.windowTabs.enabled },
        lensOpen: { SwitcherPalettePanel.shared.session != nil },
        bindings: { Array(activeMode.flatMap { config.modes[$0] }?.bindings.values ?? [:].values) },
        didChange: {
            let strips = WindowTabHintController.shared.applyingLabels(to: TrayMenuModel.shared.windowTabStrips)
            if TrayMenuModel.shared.setIfChanged(\.windowTabStrips, strips) {
                WindowTabStripPanelController.shared.refresh()
            }
        }
    )
    private static let delay: Duration = .milliseconds(500)

    @Published private(set) var shownModifiers: NSEvent.ModifierFlags?
    private var state = WindowTabHintState()
    private var task: Task<Void, Never>?
    private var scheduledToken: Int?
    private let clock: any Clock<Duration>
    private let liveFlags: () -> NSEvent.ModifierFlags
    private let enabled: () -> Bool
    private let lensOpen: () -> Bool
    private let bindingSource: () -> [HotkeyBinding]
    private let didChange: () -> Void

    init(clock: any Clock<Duration> = ContinuousClock(), liveFlags: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }, allowed: @escaping () -> Bool, lensOpen: @escaping () -> Bool, bindings: @escaping () -> [HotkeyBinding], didChange: @escaping () -> Void = {}) {
        self.clock = clock
        self.liveFlags = liveFlags
        self.enabled = allowed
        self.lensOpen = lensOpen
        self.bindingSource = bindings
        self.didChange = didChange
    }

    private var allowed: Bool {
        enabled() && !lensOpen()
    }

    private var bindings: [HotkeyBinding] {
        bindingSource()
    }

    func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        let flags = windowTabHintModifiers(flags)
        state.flagsChanged(flags, hasBindings: bindings.contains { $0.modifiers == flags && windowTabBindingTarget($0) != nil }, allowed: allowed)
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

    func reconcile() {
        state.enforce(allowed: allowed)
        publish()
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
                    self.publish()
                }
            }
        }
        if shownModifiers != state.shown {
            shownModifiers = state.shown
            didChange()
        }
    }

    func applyingLabels(to strips: [WindowTabStripViewModel]) -> [WindowTabStripViewModel] {
        let addressed = resolveTabFocusTarget(focus, .last)?.group
        let labels = shownModifiers.flatMap { modifiers in
            addressed.map { windowTabHintLabels(bindings: bindings, modifiers: modifiers, childCount: $0.children.count, isTabGroup: $0.isWindowTabGroup) }
        } ?? [:]
        let labelsByWindow = addressed.map { group in
            Dictionary(uniqueKeysWithValues: group.children.enumerated().compactMap { index, child -> (UInt32, String)? in
                guard let window = child.tabRepresentativeWindow, let label = labels[index] else { return nil }
                return (window.windowId, label)
            })
        } ?? [:]
        return strips.map { strip in
            var strip = strip
            strip.tabs = strip.tabs.map { tab in
                var tab = tab
                tab.hintLabel = addressed.map { ObjectIdentifier($0) == strip.id } == true ? labelsByWindow[tab.windowId] : nil
                return tab
            }
            return strip
        }
    }
}
