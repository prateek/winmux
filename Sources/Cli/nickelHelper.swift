import Common
import CoreServices
import Foundation

/// `config check`, `config convert` and `config schema` run `winmux-nickel` in place of this
/// process, so they work when the WinMux server is not running.
func execNickelHelper(_ action: ConfigAction, file: String? = nil, json: Bool = false) -> Never {
    guard let helper = findNickelHelper() else {
        exit(1, err: "Can't find the config helper winmux-nickel. Set WINMUX_NICKEL_HELPER to its path, or install WinMux.app")
    }
    var arguments = [helper, action.rawValue]
    switch (action, file) {
        case (_, let file?):
            arguments.append(file)
        case (.check, nil):
            // With no config file WinMux loads the shipped defaults, which is what a bare `check` checks.
            let configUrl = generatedConfigUrl()
            if FileManager.default.fileExists(atPath: configUrl.path) { arguments.append(configUrl.path) }
        case (.convert, nil):
            let candidates = legacyConfigCandidateUrls()
            guard let tomlUrl = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                exit(1, err: "No TOML config to convert. Looked for:\n\(candidates.map(\.path).joined(separator: "\n"))")
            }
            arguments.append(tomlUrl.path)
        case (.schema, nil):
            if json { arguments.append("--json") }
        case (.status, nil):
            die("'config status' is answered by the server")
    }
    var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
    execv(helper, &argv)
    exit(1, err: "Can't run \(helper): \(String(cString: strerror(errno)))")
}

private func findNickelHelper() -> String? {
    let name = "winmux-nickel"
    if let path = ProcessInfo.processInfo.environment["WINMUX_NICKEL_HELPER"] {
        return path
    }
    var candidates: [URL] = []
    if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
        candidates.append(executable.deletingLastPathComponent().appending(path: name))
    }
    if let apps = LSCopyApplicationURLsForBundleIdentifier(winMuxAppId as CFString, nil)?.takeRetainedValue() as? [URL] {
        candidates += apps.map { $0.appending(path: "Contents/Helpers").appending(path: name) }
    }
    return candidates.map(\.path).first { FileManager.default.isExecutableFile(atPath: $0) }
}
