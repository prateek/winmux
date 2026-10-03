import Foundation

@MainActor
struct ConfigReloadEvent {
    var configPath: String
    let emit: (ServerEvent) -> Void
    private var finished = false

    init(configPath: String, emit: @escaping (ServerEvent) -> Void = broadcastEvent) {
        self.configPath = configPath
        self.emit = emit
    }

    mutating func finish(error: String?, dryRun: Bool, superseded: Bool) {
        guard !finished else { return }
        finished = true
        if !dryRun && !superseded { emit(.configReloaded(ok: error == nil, error: error, configPath: configPath)) }
    }
}
