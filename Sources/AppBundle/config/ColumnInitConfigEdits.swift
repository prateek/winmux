import Common
import Foundation

@MainActor
func applyColumnInitManagedBlock(
    to configText: String,
    block: String,
    replaceExisting: Bool,
) -> Result<ColumnInitConfigEditResult, String> {
    applyColumnInitManagedBlockToConfigText(
        to: configText,
        block: block,
        replaceExisting: replaceExisting,
        validateConfig: validateColumnInitConfig,
    )
}

@MainActor
public func validateColumnInitConfigWithAppParser(_ text: String) -> Result<ColumnInitConfigValidation, String> {
    let parsed = parseConfig(text)
    guard parsed.errors.isEmpty else {
        return .failure(parsed.errors.map(\.description).joined(separator: "\n"))
    }
    return .success(ColumnInitConfigValidation(hasActiveColumns: !parsed.config.zones.isEmpty))
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
private func validateColumnInitConfig(_ text: String) -> Result<ColumnInitConfigValidation, String> {
    validateColumnInitConfigWithAppParser(text)
}
