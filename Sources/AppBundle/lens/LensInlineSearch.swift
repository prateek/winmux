import Common

@MainActor
final class LensInlineSearch {
    typealias Evaluate = @MainActor (String, JSONValue, [JSONValue]) async -> Result<[Bool], NickelFailure>
    private let debounce: Duration
    private let deadline: Duration
    private let evaluate: Evaluate
    private var current: Task<Void, Never>?
    private var generation = 0

    init(debounce: Duration = .milliseconds(150), deadline: Duration = .milliseconds(50), evaluate: @escaping Evaluate) {
        self.debounce = debounce
        self.deadline = deadline
        self.evaluate = evaluate
    }

    func cancel() {
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
            do { try await Task.sleep(for: self.debounce) } catch { return }
            guard let model, ticket == self.generation, !Task.isCancelled else { return }
            var expired = false
            let displayDeadline = Task { @MainActor in
                do { try await Task.sleep(for: self.deadline) } catch { return }
                guard ticket == self.generation else { return }
                expired = true
                model.rejectInlineResult("Filter too slow")
            }
            let result = await self.evaluate(body, context, windows)
            displayDeadline.cancel()
            guard !expired, ticket == self.generation, !Task.isCancelled else { return }
            switch result {
                case .success(let bits):
                    model.acceptInlineResult(ids.enumerated().filter { bits.indices.contains($0.offset) && bits[$0.offset] }.map(\.element))
                case .failure(let error): model.rejectInlineResult(error.message)
            }
        }
        current = task
        return task
    }
}
