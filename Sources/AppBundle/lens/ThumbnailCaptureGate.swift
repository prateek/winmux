import Foundation

struct ThumbnailCaptureGate {
    private struct Request { let id: UInt32; let lens: Int? }
    private var queued: [Request] = []
    private var active: Set<UInt32> = []
    private var lastStarted: [UInt32: TimeInterval] = [:]

    var isIdle: Bool { queued.isEmpty && active.isEmpty }

    mutating func enqueue(_ id: UInt32, lens: Int? = nil, now: TimeInterval) {
        guard !active.contains(id) else { return }
        if let index = queued.firstIndex(where: { $0.id == id }) {
            let existing = queued[index]
            if lens == nil {
                queued[index] = Request(id: id, lens: nil)
            } else if existing.lens == nil {
                queued.remove(at: index)
                queued.insert(existing, at: 0)
            }
            return
        }
        if lens == nil, let last = lastStarted[id], now - last < 0.8 { return }
        let request = Request(id: id, lens: lens)
        if lens != nil { queued.insert(request, at: queued.firstIndex(where: { $0.lens == nil }) ?? queued.count) }
        else { queued.append(request) }
    }

    mutating func start(now: TimeInterval) -> [UInt32] {
        var ids: [UInt32] = []
        while active.count < 2, !queued.isEmpty {
            let request = queued.removeFirst()
            active.insert(request.id)
            lastStarted[request.id] = now
            ids.append(request.id)
        }
        return ids
    }

    mutating func finish(_ id: UInt32) { active.remove(id) }
    mutating func closeLens(_ lens: Int) { queued.removeAll { $0.lens == lens } }
    mutating func closeWindow(_ id: UInt32) {
        queued.removeAll { $0.id == id }
        lastStarted.removeValue(forKey: id)
    }
}
