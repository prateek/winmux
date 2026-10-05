import Foundation

@MainActor
final class LensEffectSignal {
    private var count = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    func send() {
        count += 1
        waiters.removeAll { target, waiter in
            if count >= target { waiter.resume(); return true }
            return false
        }
    }
    func wait(_ target: Int = 1) async {
        if count >= target { return }
        await withCheckedContinuation { waiters.append((target, $0)) }
    }
}
