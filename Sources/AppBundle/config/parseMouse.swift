import AppKit
import Common
import TOMLKit

private let mouseParser: [String: any ParserProtocol<MouseConfig>] = [
    "zone-snap": Parser(\.zoneSnap, parseZoneSnapConfig),
]

private let zoneSnapParser: [String: any ParserProtocol<ZoneSnapConfig>] = [
    "policy": Parser(\.policy, parseZoneSnapPolicy),
    "modifier": Parser(\.modifier, parseZoneSnapModifier),
    "gesture": Parser(\.gesture, parseZoneSnapGesture),
    "target": Parser(\.target, parseZoneSnapTarget),
]

func parseMouseConfig(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> MouseConfig {
    parseTable(raw, MouseConfig(), mouseParser, backtrace, &errors)
}

private func parseZoneSnapConfig(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> ZoneSnapConfig {
    parseTable(raw, ZoneSnapConfig(), zoneSnapParser, backtrace, &errors)
}

private func parseZoneSnapPolicy(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ZoneSnapPolicy> {
    parseString(raw, backtrace).flatMap { rawValue in
        ZoneSnapPolicy(rawValue: rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ZoneSnapPolicy.self)))
    }
}

private func parseZoneSnapGesture(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ZoneSnapGesture> {
    parseString(raw, backtrace).flatMap { rawValue in
        ZoneSnapGesture(rawValue: rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ZoneSnapGesture.self)))
    }
}

private func parseZoneSnapTarget(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<ZoneSnapTarget> {
    parseString(raw, backtrace).flatMap { rawValue in
        ZoneSnapTarget(rawValue: rawValue)
            .orFailure(.semantic(backtrace, possibleValuesMessage(ZoneSnapTarget.self)))
    }
}

private func parseZoneSnapModifier(
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
