import Foundation

struct ThumbnailCaptureGate {
    private struct Request {
        let id: UInt32
        var lens: Int?
        var lenses: Set<Int>
        let needsLarger: Bool
    }
    private var queued: [Request] = []
    private var active: [UInt32: Request] = [:]
    private var lastStarted: [UInt32: TimeInterval] = [:]

    var inFlight: Int { active.count }
    var isIdle: Bool { queued.isEmpty && active.isEmpty }

    mutating func enqueue(_ id: UInt32, lens: Int? = nil, now: TimeInterval, force: Bool = false, needsLarger: Bool = false, recapture: Bool = false) {
        guard active[id] == nil || recapture else { return }
        var lenses = lens.map { Set([$0]) } ?? []
        // A departure that would enlarge the picture skips the throttle: the capture it follows may be a small Lens refresh.
        if let index = queued.firstIndex(where: { $0.id == id }) {
            lenses.formUnion(queued[index].lenses)
            if lens != nil, queued[index].lens != nil { queued[index].lenses = lenses }
            let previous = queued[index]
            let departure = lens == nil && (force || previous.lens != nil)
            let upgrade = needsLarger && !previous.needsLarger && previous.lens != nil
            guard departure || upgrade else { return }
            queued.remove(at: index)
        } else if !force, lens == nil, !needsLarger, !recapture, let last = lastStarted[id], now - last < 0.8 { return }
        let request = Request(id: id, lens: lens, lenses: lens == nil ? [] : lenses, needsLarger: needsLarger)
        let index: Int
        if force { index = 0 }
        else if lens == nil { index = queued.firstIndex(where: { $0.lens != nil }) ?? queued.count }
        else if needsLarger { index = queued.firstIndex(where: { $0.lens != nil && !$0.needsLarger }) ?? queued.count }
        else { index = queued.count }
        queued.insert(request, at: index)
    }

    mutating func start(now: TimeInterval) -> [UInt32] {
        var ids: [UInt32] = []
        while active.count < 2, let index = queued.firstIndex(where: { active[$0.id] == nil }) {
            let request = queued.remove(at: index)
            active[request.id] = request
            lastStarted[request.id] = now
            ids.append(request.id)
        }
        return ids
    }

    func activeLens(_ id: UInt32) -> Int? { active[id]?.lens }
    mutating func finish(_ id: UInt32) { active.removeValue(forKey: id) }
    mutating func closeLens(_ lens: Int) {
        queued = queued.compactMap { original -> Request? in
            guard original.lens != nil else { return original }
            var request = original
            request.lenses.remove(lens)
            guard !request.lenses.isEmpty else { return nil }
            if request.lens == lens { request.lens = request.lenses.min() }
            return request
        }
    }
    mutating func closeWindow(_ id: UInt32) {
        queued.removeAll { $0.id == id }
        lastStarted.removeValue(forKey: id)
    }
}
