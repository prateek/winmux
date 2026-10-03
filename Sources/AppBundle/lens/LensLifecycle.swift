import Common

@MainActor
final class LensLifecycle {
    private(set) var session: LensSession?
    private var opening: String?
    private var generation = 0
    private var remembered: [String: String] = [:]

    func begin(_ name: String, toggle: Bool) -> Int? {
        let same = (session?.name ?? opening) == name
        dismiss()
        if same && toggle { return nil }
        opening = name
        return generation
    }

    @discardableResult
    func complete(_ session: LensSession, ticket: Int) -> Bool {
        guard ticket == generation, opening == session.name else { return false }
        self.session = session
        opening = nil
        return true
    }

    func dismiss() {
        if let session { remembered[session.name] = session.query }
        session = nil
        opening = nil
        generation += 1
    }

    func search(for name: String, override: String?) -> String { override ?? remembered[name] ?? "" }
}

struct LensFilterResolution {
    let ids: [UInt32]
    let banner: String?

    init(candidateIds: [UInt32], result: Result<[Bool], NickelFailure>) {
        switch result {
            case .success(let bits):
                ids = candidateIds.enumerated().filter { bits.indices.contains($0.offset) && bits[$0.offset] }.map(\.element)
                banner = nil
            case .failure(let error):
                ids = candidateIds
                banner = "Filter failed: \(error.message)"
        }
    }
}
