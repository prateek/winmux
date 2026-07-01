import Common

struct WindowDetectedMatcherEvaluation: Equatable {
    let matchedTerms: [String]
    let failedTerms: [String]

    var matched: Bool { failedTerms.isEmpty }

    var debugJson: Json {
        .dict([
            "matched": .bool(matched),
            "matched-terms": .array(matchedTerms.map(Json.string)),
            "failed-terms": .array(failedTerms.map(Json.string)),
        ])
    }
}

struct ZoneAffinityEvaluation: Equatable {
    let index: Int
    let zone: String
    let matcher: WindowDetectedMatcherEvaluation
    let target: ZoneAffinityTargetEvaluation
    let checkFurtherCallbacks: Bool
    let focusFollowsWindow: Bool
    let failIfNoop: Bool

    var matched: Bool { matcher.matched }

    var debugJson: Json {
        .dict([
            "index": .int(index),
            "zone": .string(zone),
            "matched": .bool(matched),
            "matcher": matcher.debugJson,
            "target": target.debugJson,
            "route-command": .string("move-node-to-zone \(zone)"),
            "check-further-callbacks": .bool(checkFurtherCallbacks),
            "focus-follows-window": .bool(focusFollowsWindow),
            "fail-if-noop": .bool(failIfNoop),
        ])
    }
}

enum ZoneAffinityTargetEvaluation: Equatable {
    case enabled(physicalMonitorId: Int?, zoneId: String, zoneName: String?)
    case disabled(physicalMonitorId: Int?, zoneId: String, zoneName: String?)
    case unresolved(String)

    var debugJson: Json {
        switch self {
            case .enabled(let physicalMonitorId, let zoneId, let zoneName):
                return .dict([
                    "state": .string("enabled"),
                    "physical-monitor-id": physicalMonitorId.map(Json.int) ?? .null,
                    "zone-id": .string(zoneId),
                    "zone-name": .stringOrNull(zoneName),
                ])
            case .disabled(let physicalMonitorId, let zoneId, let zoneName):
                return .dict([
                    "state": .string("disabled"),
                    "physical-monitor-id": physicalMonitorId.map(Json.int) ?? .null,
                    "zone-id": .string(zoneId),
                    "zone-name": .stringOrNull(zoneName),
                    "reason": .string("target zone is hidden; enable it before this affinity can route windows"),
                ])
            case .unresolved(let reason):
                return .dict([
                    "state": .string("unresolved"),
                    "reason": .string(reason),
                ])
        }
    }
}

extension WindowDetectedCallbackMatcher {
    @MainActor
    func evaluate(_ window: Window) async throws -> WindowDetectedMatcherEvaluation {
        var matchedTerms: [String] = []
        var failedTerms: [String] = []

        if let startupMatcher = duringWinMuxStartup {
            if startupMatcher == isStartup {
                matchedTerms.append("during-winmux-startup=\(startupMatcher)")
            } else {
                failedTerms.append("during-winmux-startup expected \(startupMatcher) but got \(isStartup)")
            }
        }

        if let regex = windowTitleRegexSubstring {
            let title = try await window.title
            if title.contains(regex) {
                matchedTerms.append("window-title-regex-substring matched title '\(title)'")
            } else {
                failedTerms.append("window-title-regex-substring did not match title '\(title)'")
            }
        }

        if let appId {
            let actual = window.app.rawAppBundleId ?? "nil"
            if appId == window.app.rawAppBundleId {
                matchedTerms.append("app-id matched '\(actual)'")
            } else {
                failedTerms.append("app-id expected '\(appId)' but got '\(actual)'")
            }
        }

        if let regex = appNameRegexSubstring {
            let actual = window.app.name ?? ""
            if actual.contains(regex) {
                matchedTerms.append("app-name-regex-substring matched app name '\(actual)'")
            } else {
                failedTerms.append("app-name-regex-substring did not match app name '\(actual)'")
            }
        }

        if let workspace {
            let actual = window.nodeWorkspace?.name ?? "nil"
            if workspace == window.nodeWorkspace?.name {
                matchedTerms.append("workspace matched '\(actual)'")
            } else {
                failedTerms.append("workspace expected '\(workspace)' but got '\(actual)'")
            }
        }

        if matchedTerms.isEmpty && failedTerms.isEmpty {
            matchedTerms.append("no matcher fields configured")
        }

        return WindowDetectedMatcherEvaluation(
            matchedTerms: matchedTerms,
            failedTerms: failedTerms,
        )
    }
}

extension ZoneAffinityConfig {
    @MainActor
    func evaluate(index: Int, window: Window) async throws -> ZoneAffinityEvaluation {
        let selector = zone
        return ZoneAffinityEvaluation(
            index: index,
            zone: selector?.raw ?? "<missing>",
            matcher: try await matcher.evaluate(window),
            target: selector.map(evaluateZoneAffinityTarget) ?? .unresolved("Missing required zone target"),
            checkFurtherCallbacks: checkFurtherCallbacks,
            focusFollowsWindow: focusFollowsWindow,
            failIfNoop: failIfNoop,
        )
    }
}

@MainActor
private func evaluateZoneAffinityTarget(_ selector: ZoneSelector) -> ZoneAffinityTargetEvaluation {
    switch resolveConfiguredZoneSelector(selector) {
        case .success(let zone):
            let monitorId = zone.physicalMonitor.monitorId_oneBased
            if zone.isEnabled {
                return .enabled(
                    physicalMonitorId: monitorId,
                    zoneId: zone.zoneId,
                    zoneName: zone.zoneName,
                )
            } else {
                return .disabled(
                    physicalMonitorId: monitorId,
                    zoneId: zone.zoneId,
                    zoneName: zone.zoneName,
                )
            }
        case .failure(let reason):
            return .unresolved(reason)
    }
}
