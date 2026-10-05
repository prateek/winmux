import Common

@MainActor
final class LensInlineSearch {
    typealias Evaluate = @MainActor (String, JSONValue, [JSONValue]) async -> Result<[Bool], NickelFailure>
    private let clock: any Clock<Duration>
    private let debounce: Duration
    private let deadline: Duration
    private let evaluate: Evaluate
    private(set) var current: Task<Void, Never>?
    private var displayDeadline: Task<Void, Never>?
    private var generation = 0

    init(clock: any Clock<Duration> = ContinuousClock(), debounce: Duration = .milliseconds(150), deadline: Duration = .milliseconds(50), evaluate: @escaping Evaluate) {
        self.clock = clock
        self.debounce = debounce
        self.deadline = deadline
        self.evaluate = evaluate
    }

    func cancel() {
        displayDeadline?.cancel()
        displayDeadline = nil
        current?.cancel()
        current = nil
        generation += 1
    }

    @discardableResult
    func update(_ model: LensSession, context: JSONValue, windows: [JSONValue], ids: [UInt32]) -> Task<Void, Never>? {
        cancel()
        guard model.query.hasPrefix("=") else { return nil }
        let ticket = generation
        let body = String(model.query.dropFirst())
        let task = Task { [weak self, weak model] in
            guard let self else { return }
            defer { if ticket == self.generation { self.current = nil } }
            do { try await self.clock.sleep(for: self.debounce) } catch { return }
            guard let model, ticket == self.generation, !Task.isCancelled else { return }
            var expired = false
            let displayDeadline = Task { @MainActor in
                do { try await self.clock.sleep(for: self.deadline) } catch { return }
                guard ticket == self.generation, !Task.isCancelled else { return }
                self.displayDeadline = nil
                expired = true
                model.rejectInlineResult("Filter too slow")
            }
            self.displayDeadline = displayDeadline
            let result = await self.evaluate(body, context, windows)
            displayDeadline.cancel()
            guard ticket == self.generation, !Task.isCancelled else { return }
            self.displayDeadline = nil
            guard !expired else { return }
            switch result {
                case .success(let bits):
                    model.acceptInlineResult(lensFilterMatches(ids, bits: bits))
                case .failure(let error): model.rejectInlineResult(error.message)
            }
        }
        current = task
        return task
    }
}
