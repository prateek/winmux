import Common
import Foundation

@MainActor
func applyZoneInitManagedBlock(
    to configText: String,
    block: String,
    replaceExisting: Bool,
) -> Result<ZoneInitConfigEditResult, String> {
    applyZoneInitManagedBlockToConfigText(
        to: configText,
        block: block,
        replaceExisting: replaceExisting,
        validateConfig: validateZoneInitConfig,
    )
}

@MainActor
public func validateZoneInitConfigWithAppParser(_ text: String) -> Result<ZoneInitConfigValidation, String> {
    let parsed = parseConfig(text)
    guard parsed.errors.isEmpty else {
        return .failure(parsed.errors.map(\.description).joined(separator: "\n"))
    }
    return .success(ZoneInitConfigValidation(hasActiveZones: !parsed.config.zones.isEmpty))
}

@MainActor
public func validateConfigWithAppParser(_ text: String) -> Result<Void, String> {
    let parsed = parseConfig(text)
    guard parsed.errors.isEmpty else {
        return .failure(parsed.errors.map(\.description).joined(separator: "\n"))
    }
    return .success(())
}

@MainActor
private func validateZoneInitConfig(_ text: String) -> Result<ZoneInitConfigValidation, String> {
    validateZoneInitConfigWithAppParser(text)
}
