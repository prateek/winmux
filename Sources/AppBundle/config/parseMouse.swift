import AppKit
import Common
import TOMLKit

private let mouseParser: [String: any ParserProtocol<MouseConfig>] = [
    "zone-snap": Parser(\.columnSnap, parseColumnSnapConfig),
    "column-snap": Parser(\.columnSnap, parseColumnSnapConfig), // config-version 3 spelling
    "zone-divider-drag": Parser(\.columnDividerDrag, parseColumnDividerDragPolicy),
    "column-divider-drag": Parser(\.columnDividerDrag, parseColumnDividerDragPolicy), // config-version 3 spelling
]

private let columnSnapParser: [String: any ParserProtocol<ColumnSnapConfig>] = [
    "policy": Parser(\.policy, parseColumnSnapPolicy),
    "modifier": Parser(\.modifier, parseColumnSnapModifier),
    "gesture": Parser(\.gesture, parseColumnSnapGesture),
    "target": Parser(\.target, parseColumnSnapTarget),
]

func parseMouseConfig(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> MouseConfig {
    parseTable(raw, MouseConfig(), mouseParser, backtrace, &errors)
}

private let updatesParser: [String: any ParserProtocol<UpdatesConfig>] = [
    "automatic-check": Parser(\.automaticCheck, parseBool),
]

func parseUpdatesConfig(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> UpdatesConfig {
    parseTable(raw, UpdatesConfig(), updatesParser, backtrace, &errors)
}

private func parseColumnSnapConfig(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> ColumnSnapConfig {
    parseTable(raw, ColumnSnapConfig(), columnSnapParser, backtrace, &errors)
}

private func parseColumnSnapPolicy(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ColumnSnapPolicy> {
    parseString(raw, backtrace).flatMap { rawValue in
        ColumnSnapPolicy.fromConfigIdentifier(rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ColumnSnapPolicy.self)))
    }
}

private func parseColumnDividerDragPolicy(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ColumnDividerDragPolicy> {
    parseString(raw, backtrace).flatMap { rawValue in
        return ColumnDividerDragPolicy(rawValue: rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ColumnDividerDragPolicy.self)))
    }
}

private func parseColumnSnapGesture(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ColumnSnapGesture> {
    parseString(raw, backtrace).flatMap { rawValue in
        ColumnSnapGesture(rawValue: rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ColumnSnapGesture.self)))
    }
}

private func parseColumnSnapTarget(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ColumnSnapTarget> {
    parseString(raw, backtrace).flatMap { rawValue in
        return ColumnSnapTarget.fromConfigIdentifier(rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ColumnSnapTarget.self)))
    }
}

private func parseColumnSnapModifier(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<NSEvent.ModifierFlags> {
    parseString(raw, backtrace).flatMap { rawValue -> ParsedToml<NSEvent.ModifierFlags> in
        let parts = rawValue.split(separator: "-").map(String.init)
        guard !parts.isEmpty else {
            return .failure(.semantic(backtrace, "Must contain at least one modifier"))
        }

        var flags: NSEvent.ModifierFlags = []
        for part in parts {
            guard let modifier = modifiersMap[part] else {
                return .failure(.semantic(
                    backtrace,
                    "Unsupported modifier '\(part)'. Possible values: alt, ctrl, cmd, shift, or '-' combinations like alt-shift",
                ))
            }
            flags.insert(modifier)
        }
        guard !flags.isEmpty else {
            return .failure(.semantic(backtrace, "Must contain at least one modifier"))
        }
        return .success(flags)
    }
}

private func possibleValuesMessage<T>(_ type: T.Type) -> String where T: RawRepresentable, T: CaseIterable, T.RawValue == String {
    "Possible values: \(type.allCases.map(\.rawValue).joined(separator: ", "))"
}
