import AppKit
import os

// Written from app AX threads, consumed (read-and-clear) by the main-thread mouse-up handler.
private let windowRegistrationDeferredDuringMouseDown = OSAllocatedUnfairLock(initialState: false)

func noteWindowRegistrationDeferredDuringMouseDown() {
    windowRegistrationDeferredDuringMouseDown.withLock { $0 = true }
}

func takeWindowRegistrationDeferredDuringMouseDown() -> Bool {
    windowRegistrationDeferredDuringMouseDown.withLock { deferred in
        let wasDeferred = deferred
        deferred = false
        return wasDeferred
    }
}

extension [UInt32: AxWindow] {
    @discardableResult
    mutating func getOrRegisterAxWindow(
        windowId id: UInt32,
        _ axWindow: AXUIElement,
        _ nsApp: NSRunningApplication,
        _ job: RunLoopJob,
    ) throws -> AxWindow? {
        if let existing = self[id] { return existing }
        if isLeftMouseButtonDown {
            noteWindowRegistrationDeferredDuringMouseDown()
            return nil
        }

        if let window = try AxWindow.new(windowId: id, axWindow, nsApp, job) {
            self[id] = window
            return window
        } else {
            return nil
        }
    }
}
