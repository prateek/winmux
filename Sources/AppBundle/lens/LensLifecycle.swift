import AppKit
import Common

@MainActor
final class LensLifecycle {
    private(set) var session: LensSession?
    private var opening: String?
    private var openingGesture: StripGesture?
    private var openingSteps = 0
    private var openingRelease: NSEvent.ModifierFlags?
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
            session.stripReleasedWhileOpening = openingRelease
        }
        self.session = session
        opening = nil
        openingGesture = nil
        openingSteps = 0
        openingRelease = nil
        return true
    }

    func cycleStrip(name: String, keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if let session { return session.name == name && session.cycleStrip(keyCode: keyCode, flags: flags) }
        guard opening == name, openingGesture?.step(keyCode: keyCode, flags: flags) != nil else { return false }
        return openingStripKey(keyCode: keyCode, flags: flags) == .consumed
    }

    /// A key that arrives while a strip is opening. The invoking key is a step applied when the
    /// session is ready; Tab and backtick with the strip's modifiers do nothing; anything else is
    /// `.ignored`, which means it is not the strip's. Nil when no strip is opening.
    func openingStripKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> StripInput? {
        guard session == nil, opening != nil, let gesture = openingGesture else { return nil }
        if let step = gesture.step(keyCode: keyCode, flags: flags) {
            // After the release the selection is settled: the commit waits only for the session.
            if openingRelease == nil { openingSteps += step }
            return .consumed
        }
        return (keyCode == 48 || keyCode == 50) && gesture.owns(flags) ? .consumed : .ignored
    }

    /// Records a release of the invoking modifiers that happens before the session is ready, so a
    /// press that follows it cannot hide it from the live modifier state.
    func openingFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard session == nil, opening != nil, let gesture = openingGesture, openingRelease == nil else { return }
        if gesture.shouldCommit(flags: flags) { openingRelease = flags }
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
        openingRelease = nil
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
