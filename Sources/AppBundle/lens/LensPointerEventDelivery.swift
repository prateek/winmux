import AppKit

@MainActor
final class LensPointerEventDelivery {
    struct Monitors {
        var local: (@escaping (NSEvent) -> NSEvent?) -> Any?
        var global: (@escaping (NSEvent) -> Void) -> Any?
        var remove: (Any) -> Void

        static var live: Self {
            Self(local: { NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: $0) },
                 global: { NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: $0) },
                 remove: { NSEvent.removeMonitor($0) })
        }
    }

    private let monitors: Monitors
    private let pointerLocation: () -> CGPoint
    private var tokens: [Any] = []

    init(monitors: Monitors = .live, pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }) {
        self.monitors = monitors
        self.pointerLocation = pointerLocation
    }

    func start(window: NSWindow, move: @escaping (NSEvent) -> Void) {
        stop()
        let location = pointerLocation
        let local = monitors.local { [weak window] event in
            if let window, window.isVisible, event.window === window { move(event) }
            return event
        }
        let global = monitors.global { [weak window] event in
            let point = location()
            guard let window, window.isVisible, window.frame.contains(point),
                  let translated = NSEvent.mouseEvent(with: .mouseMoved, location: window.convertPoint(fromScreen: point),
                                                     modifierFlags: event.modifierFlags, timestamp: event.timestamp,
                                                     windowNumber: window.windowNumber, context: nil,
                                                     eventNumber: 0, clickCount: 0, pressure: 0) else { return }
            move(translated)
        }
        tokens = [local, global].compactMap { $0 }
    }

    func stop() {
        for token in tokens { monitors.remove(token) }
        tokens = []
    }
}
