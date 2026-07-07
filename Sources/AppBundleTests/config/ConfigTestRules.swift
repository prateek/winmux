@testable import AppBundle
import Common
import XCTest

extension ConfigTest {
    func testParseRulesReusesMatcherEngineAndKeepsDeclaredOrder() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            card = 'Chat'

            [[rules]]
            if.app-id = 'com.apple.mail'
            card = 'Mail'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.rules, [
            RuleConfig(matcher: WindowDetectedCallbackMatcher().copy(\.appId, "com.tinyspeck.slackmacgap"), card: "Chat"),
            RuleConfig(matcher: WindowDetectedCallbackMatcher().copy(\.appId, "com.apple.mail"), card: "Mail"),
        ])
    }

    func testRuleRequiresACard() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            """,
        )

        assertEquals(parsed.rules, [])
        assertTrue(errors.descriptions.contains(where: { $0.contains("Missing required key") }))
    }

    func testRuleAcceptsATitleRegexMatcher() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.window-title-regex-substring = 'Inbox|Mail'
            card = 'Chat'
            """,
        )

        assertEquals(errors, [])
        // The matcher's Equatable dies on a non-nil regex, so assert the shape without comparing it.
        assertEquals(parsed.rules.count, 1)
        assertEquals(parsed.rules.first?.card, "Chat")
        assertTrue(parsed.rules.first?.matcher.windowTitleRegexSubstring != nil)
    }

    func testRuleParsesFocusAndCheckFurtherRules() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            card = 'Chat'
            focus = true
            check-further-rules = true
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.rules, [
            RuleConfig(matcher: WindowDetectedCallbackMatcher().copy(\.appId, "com.tinyspeck.slackmacgap"), card: "Chat", focus: true, checkFurtherRules: true),
        ])
    }

    func testRuleFocusAndCheckFurtherRulesDefaultToFalse() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            card = 'Chat'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.rules.first?.focus, false)
        assertEquals(parsed.rules.first?.checkFurtherRules, false)
    }

    // A rule's `card` is never checked against known cards at parse time: naming one that doesn't
    // exist yet is the point of a rule.
    func testRuleCardIsNotValidatedAgainstKnownCards() {
        let (parsed, errors) = parseConfig(
            """
            [[rules]]
            if.app-id = 'com.tinyspeck.slackmacgap'
            card = 'DoesNotExistYet'
            """,
        )

        assertEquals(errors, [])
        assertEquals(parsed.rules.first?.card, "DoesNotExistYet")
    }
}
