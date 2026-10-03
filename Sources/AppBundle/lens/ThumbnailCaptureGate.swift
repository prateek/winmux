import Foundation

struct ThumbnailCaptureGate {
    private struct Request { let id: UInt32; let lens: Int? }
    private var queued: [Request] = []
    private var active: Set<UInt32> = []
    private var lastStarted: [UInt32: TimeInterval] = [:]

    var inFlight: Int { active.count }
    var isIdle: Bool { queued.isEmpty && active.isEmpty }

    mutating func enqueue(_ id: UInt32, lens: Int? = nil, now: TimeInterval, force: Bool = false) {
        guard !active.contains(id) else { return }
        if let index = queued.firstIndex(where: { $0.id == id }) {
            guard lens == nil, force || queued[index].lens != nil else { return }
            queued.remove(at: index)
            queued.insert(Request(id: id, lens: nil), at: force ? 0 : queued.firstIndex(where: { $0.lens != nil }) ?? queued.count)
            return
        }
        if !force, lens == nil, let last = lastStarted[id], now - last < 0.8 { return }
        let request = Request(id: id, lens: lens)
        if force { queued.insert(request, at: 0) }
        else if lens == nil { queued.insert(request, at: queued.firstIndex(where: { $0.lens != nil }) ?? queued.count) }
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
