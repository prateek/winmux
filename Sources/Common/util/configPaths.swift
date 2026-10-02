import Foundation

public let generatedConfigDirectoryName = "winmux"
public let generatedConfigFileName = "winmux.ncl"
public let legacyConfigFileName = "winmux.toml"
public let legacyConfigDotfileName = ".winmux.toml"

public func xdgConfigHomeUrl() -> URL {
    ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/")
}

/// The config file WinMux loads when it is not started with `--config-path`.
public func generatedConfigUrl() -> URL {
    xdgConfigHomeUrl()
        .appending(path: generatedConfigDirectoryName)
        .appending(path: generatedConfigFileName)
}

/// Where a TOML config from before the move to Nickel may be.
public func legacyConfigCandidateUrls() -> [URL] {
    [
        xdgConfigHomeUrl().appending(path: generatedConfigDirectoryName).appending(path: legacyConfigFileName),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: legacyConfigDotfileName),
    ]
}
