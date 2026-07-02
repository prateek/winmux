import Foundation
import Common

public struct ConfigRestoreBackupResult: Equatable, Sendable {
    public let targetPath: String
    public let sourceBackupPath: String
    public let previousConfigBackupPath: String?

    public init(targetPath: String, sourceBackupPath: String, previousConfigBackupPath: String?) {
        self.targetPath = targetPath
        self.sourceBackupPath = sourceBackupPath
        self.previousConfigBackupPath = previousConfigBackupPath
    }
}

@MainActor
public func restoreConfigFromBackup(
    targetUrl: URL,
    backupUrl: URL,
    validateConfig: @MainActor (String) -> Result<Void, String>,
) -> Result<ConfigRestoreBackupResult, String> {
    let restoredText: String
    do {
        restoredText = try String(contentsOf: backupUrl, encoding: .utf8)
    } catch {
        return .failure("Can't read backup config '\(backupUrl.path)': \(error.localizedDescription)")
    }

    switch validateConfig(restoredText) {
        case .success:
            break
        case .failure(let message):
            return .failure("Backup config is not valid; refusing to restore:\n\(message)")
    }

    let previousBackup: URL?
    if FileManager.default.fileExists(atPath: targetUrl.path) {
        previousBackup = nextConfigRestoreRollbackUrl(for: targetUrl)
    } else {
        previousBackup = nil
    }

    do {
        try FileManager.default.createDirectory(
            at: targetUrl.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        if let previousBackup {
            try FileManager.default.copyItem(at: targetUrl, to: previousBackup)
        }
        try restoredText.write(to: targetUrl, atomically: true, encoding: .utf8)
    } catch {
        return .failure("Can't restore config to '\(targetUrl.path)': \(error.localizedDescription)")
    }

    return .success(ConfigRestoreBackupResult(
        targetPath: targetUrl.path,
        sourceBackupPath: backupUrl.path,
        previousConfigBackupPath: previousBackup?.path,
    ))
}

public func renderConfigRestoreBackupOutput(_ result: ConfigRestoreBackupResult) -> [String] {
    var output = [
        "Restored config from backup: \(result.sourceBackupPath)",
        "Config path: \(result.targetPath)",
    ]
    if let previousBackup = result.previousConfigBackupPath {
        output.append("Previous config backup: \(previousBackup)")
    }
    output.append("Restored config OK")
    return output
}

public func nextConfigRestoreRollbackUrl(for url: URL, date: Date = Date()) -> URL {
    let stamp = configRestoreBackupTimestamp(date: date)
    let baseName = "\(url.lastPathComponent).rollback-\(stamp)"
    let directory = url.deletingLastPathComponent()
    var candidate = directory.appending(component: baseName)
    var suffix = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = directory.appending(component: "\(baseName)-\(suffix)")
        suffix += 1
    }
    return candidate
}

private func configRestoreBackupTimestamp(date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: date)
}
