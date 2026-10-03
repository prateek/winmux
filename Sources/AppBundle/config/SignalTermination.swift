import Foundation

final class SignalTermination: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var finished = false

    func eventHandler(timeout: TimeInterval = 2, restore: @escaping @Sendable () -> Void,
                      cleanup: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void,
                      terminate: @escaping @Sendable () -> Void) -> @Sendable () -> Void {
        { [self] in run(timeout: timeout, restore: restore, cleanup: cleanup, terminate: terminate) }
    }

    func run(timeout: TimeInterval = 2, restore: () -> Void,
             cleanup: (@escaping @Sendable () -> Void) -> Void,
             terminate: @escaping @Sendable () -> Void) {
        guard lock.withLock({
            if started { return false }
            started = true
            return true
        }) else { return }
        restore()
        let finish: @Sendable () -> Void = { [self] in
            let first = lock.withLock {
                if finished { return false }
                finished = true
                return true
            }
            if first { terminate() }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout, execute: finish)
        cleanup(finish)
    }
}
