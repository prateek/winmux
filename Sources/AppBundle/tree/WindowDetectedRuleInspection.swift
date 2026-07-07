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

struct RuleEvaluation: Equatable {
    let index: Int
    let card: String
    let matcher: WindowDetectedMatcherEvaluation
    let target: RuleCardTargetEvaluation
    let focus: Bool
    let checkFurtherRules: Bool

    var matched: Bool { matcher.matched }

    var debugJson: Json {
        .dict([
            "index": .int(index),
            "card": .string(card),
            "matched": .bool(matched),
            "matcher": matcher.debugJson,
            "target": target.debugJson,
            "focus": .bool(focus),
            "check-further-rules": .bool(checkFurtherRules),
        ])
    }
}

enum RuleCardTargetEvaluation: Equatable {
    case existing(columnKey: String?)
    case willCreate(columnKey: String)

    var debugJson: Json {
        switch self {
            case .existing(let columnKey):
                return .dict([
                    "state": .string("existing"),
                    "column-key": .stringOrNull(columnKey),
                ])
            case .willCreate(let columnKey):
                return .dict([
                    "state": .string("will-create"),
                    "column-key": .string(columnKey),
                    "reason": .string("card does not exist yet; a match creates it in the active scene's default column"),
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

extension RuleConfig {
    @MainActor
    func evaluate(index: Int, window: Window) async throws -> RuleEvaluation {
        let cardName = card ?? "<missing>"
        return RuleEvaluation(
            index: index,
            card: cardName,
            matcher: try await matcher.evaluate(window),
            target: card.map { evaluateRuleCardTarget($0, forWindow: window) } ?? .willCreate(columnKey: "<unresolved: missing required 'card' key>"),
            focus: focus,
            checkFurtherRules: checkFurtherRules,
        )
    }
}

@MainActor
private func evaluateRuleCardTarget(_ cardName: String, forWindow window: Window) -> RuleCardTargetEvaluation {
    if let existing = Workspace.existing(byName: cardName) {
        return .existing(columnKey: winMuxWorkspaceState.columnDecks.columnKey(of: existing.id))
    }
    guard let display = window.nodeMonitor else {
        return .willCreate(columnKey: "<unresolved: window has no monitor>")
    }
    return .willCreate(columnKey: ruleCardColumnDeckKey(onDisplay: display))
}
