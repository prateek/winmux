import Foundation

@ScreenshotWorker
final class RefreshingSnapshot<Value> {
    private(set) var value: Value?
    private var generation = 0
    private var fetch: Task<Void, Never>?
    private let load: @ScreenshotWorker () async -> Value?

    init(load: @escaping @ScreenshotWorker () async -> Value?) { self.load = load }

    func invalidate() { generation += 1 }

    func refresh() async {
        if let fetch { await fetch.value; return }
        let task = Task { @ScreenshotWorker in
            var fetchedGeneration: Int
            repeat {
                fetchedGeneration = generation
                if let next = await load() { value = next }
            } while fetchedGeneration != generation
            fetch = nil
        }
        fetch = task
        await task.value
    }
}
