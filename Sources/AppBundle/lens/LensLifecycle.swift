import AppKit
import Common

@MainActor
final class LensLifecycle {
    private(set) var session: LensSession?
    private var opening: String?
    private var openingGesture: StripGesture?
    private var openingSteps = 0
    private var generation = 0
    private var remembered: [String: String] = [:]

    func begin(_ name: String, toggle: Bool, strip: StripGesture? = nil) -> Int? {
        let same = (session?.name ?? opening) == name
        dismiss()
        if same && toggle && strip == nil { return nil }
        opening = name
        openingGesture = strip
        return generation
    }

    @discardableResult
    func complete(_ session: LensSession, ticket: Int) -> Bool {
        guard ticket == generation, opening == session.name else { return false }
        if session.settings.presentation == "strip", let gesture = openingGesture {
            session.beginStrip(gesture)
            session.cycleStripSelection(openingSteps)
        }
        self.session = session
        opening = nil
        openingGesture = nil
        openingSteps = 0
        return true
    }

    func cycleStrip(name: String? = nil, keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if let session {
            guard name == nil || session.name == name else { return false }
            return session.cycleStrip(keyCode: keyCode, flags: flags)
        }
        guard let opening, name == nil || opening == name, openingGesture?.keyCode == keyCode else { return false }
        openingSteps += flags.contains(.shift) ? -1 : 1
        return true
    }

    func cancelOpening(ticket: Int) {
        guard ticket == generation, opening != nil else { return }
        dismiss()
    }

    func dismiss() {
        if let session { remembered[session.name] = session.query }
        session = nil
        opening = nil
        openingGesture = nil
        openingSteps = 0
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
                ids = lensFilterMatches(candidateIds, bits: bits)
                banner = nil
            case .failure(let error):
                ids = candidateIds
                banner = "Filter failed: \(error.message)"
        }
    }
}

func lensFilterMatches<T>(_ candidates: [T], bits: [Bool]) -> [T] {
    zip(candidates, bits).compactMap { candidate, matches in matches ? candidate : nil }
}
