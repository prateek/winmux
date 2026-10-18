import AppKit

@MainActor
final class FindFocusHighlight {
    typealias MonitorInput = @MainActor (@escaping @MainActor (NSEvent.EventType) -> Void) -> () -> Void

    static var shared = FindFocusHighlight(
        show: { FindFocusPanels.shared.show($0) },
        fade: { FindFocusPanels.shared.fade() },
        hide: { FindFocusPanels.shared.hide() },
        monitorInput: monitorFindFocusInput,
    )

    private let clock: any Clock<Duration>
    private let draw: (Rect) -> Void
    private let fade: () -> Void
    private let hide: () -> Void
    private let monitorInput: MonitorInput
    private var stopMonitoring: (() -> Void)?
    private var lifetime: Task<Void, Never>?
    private weak var window: Window?
    private var appliedRect: Rect?
    private(set) var isShowing = false
    private(set) var generation = 0

    init(clock: any Clock<Duration> = ContinuousClock(), show: @escaping (Rect) -> Void,
         fade: @escaping () -> Void, hide: @escaping () -> Void,
         monitorInput: @escaping MonitorInput = { _ in {} }) {
        self.clock = clock
        self.draw = show
        self.fade = fade
        self.hide = hide
        self.monitorInput = monitorInput
    }

    func show(window: Window, rect: Rect) {
        generation += 1
        lifetime?.cancel()
        stopMonitoring?()
        self.window = window
        appliedRect = window.lastAppliedLayoutPhysicalRect
        isShowing = true
        draw(rect)
        stopMonitoring = monitorInput { [weak self] in self?.receiveInput($0) }
        let ticket = generation
        lifetime = Task { [weak self, clock] in
            do { try await clock.sleep(for: .milliseconds(800)) } catch { return }
            guard let self, self.generation == ticket, !Task.isCancelled else { return }
            self.fade()
            do { try await clock.sleep(for: .milliseconds(400)) } catch { return }
            guard self.generation == ticket, !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        generation += 1
        lifetime?.cancel()
        lifetime = nil
        stopMonitoring?()
        stopMonitoring = nil
        if isShowing { hide() }
        isShowing = false
        window = nil
        appliedRect = nil
    }

    func receiveInput(_ type: NSEvent.EventType) {
        switch type {
            case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown: dismiss()
            default: break
        }
    }

    func refresh() {
        guard isShowing else { return }
        if let appliedRect, window?.lastAppliedLayoutPhysicalRect != appliedRect { dismiss() }
    }
}

@MainActor
private func monitorFindFocusInput(_ receive: @escaping @MainActor (NSEvent.EventType) -> Void) -> () -> Void {
    let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
        MainActor.assumeIsolated { receive(event.type) }
    }
    let local = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
        MainActor.assumeIsolated { receive(event.type) }
        return event
    }
    return {
        if let global { NSEvent.removeMonitor(global) }
        if let local { NSEvent.removeMonitor(local) }
    }
}
