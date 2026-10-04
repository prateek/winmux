import Foundation

func configReloadEvent(dryRun: Bool, error: String?, configPath: String) -> ServerEvent? {
    dryRun ? nil : .configReloaded(ok: error == nil, error: error, configPath: configPath)
}
