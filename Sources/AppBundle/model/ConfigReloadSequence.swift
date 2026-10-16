@MainActor
final class ConfigReloadResult {
    var eventPath: String
    var eventError: String?
    var outcome = ConfigLoadOutcome.failed

    init(configPath: String) { eventPath = configPath }
}

@MainActor
final class ConfigReloadSequence {
    private var started = 0

    func run<Load>(
        dryRun: Bool,
        configPath: String,
        load: @MainActor () async -> Load,
        overtaken: @MainActor (Load) -> Bool,
        rest: @MainActor (Load, ConfigReloadResult) async throws -> Bool,
        syncWatcher: @MainActor (ConfigLoadOutcome) -> Void,
        emit: @MainActor (ServerEvent) -> Void,
    ) async throws -> Bool {
        // A dry run changes nothing, so it neither overtakes a reload nor is overtaken.
        if !dryRun { started += 1 }
        let ticket = started
        let result = ConfigReloadResult(configPath: configPath)
        let read = await load()
        if ticket != started && !dryRun {
            // A later reload started while this one was loading, and its result is the newer one.
            // Return before the emitting defer; held by
            // ConfigReloadSequenceTest.testSupersededReloadEmitsNothingAfterNewerReloadCompletes.
            return overtaken(read)
        }
        // Even when applying throws, the loaded helper's files are the ones to watch.
        defer {
            if !dryRun { syncWatcher(result.outcome) }
            if let event = configReloadEvent(dryRun: dryRun, error: result.eventError, configPath: result.eventPath) { emit(event) }
        }
        return try await rest(read, result)
    }
}
