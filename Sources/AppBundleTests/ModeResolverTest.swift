@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor final class ModeResolverTest: XCTestCase {
    func testContextVariablesOperatorsAbsenceAndSpecificity() throws {
        let context = KeyContext(mode: "browse", app: "com.mitchellh.ghostty", lensOpen: true, lens: nil, presentation: "strip", columns: nil)
        for expression in ["mode == browse", "app == 'com.mitchellh.ghostty'", "lens", "lens != recent", "columns != 2", "profile == default", "!columns", "presentation == strip && (mode == browse || mode == cmd-tab)"] {
            XCTAssertTrue(try KeyCondition(expression).matches(context), expression)
        }
        for expression in ["lens == recent", "columns", "columns == 2", "mode != browse"] {
            XCTAssertFalse(try KeyCondition(expression).matches(context), expression)
        }
        XCTAssertEqual(try KeyCondition("presentation == strip && (mode == browse || mode == cmd-tab)").specificity, 2)
        XCTAssertThrowsError(try KeyCondition("unknown == x"))
        XCTAssertThrowsError(try KeyCondition("mode = browse"))
    }

    private func map(_ records: String) throws -> [KeymapBlock] {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data("{\"mode\":{\"main\":{}},\"keymap\":{\(records)}}".utf8))
        let parsed = parseConfig(json)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        return parsed.config.keymap
    }
    private func command(_ result: ModeKeyResolution) -> [String] { result.commands.map { $0.args.description } }

    func testSpecificityThenPriorityAndAppPassUseOneWinner() throws {
        let keymap = try map(#"""
        "main":{"context":"mode == main","priority":0,"bindings":{"ctrl-h":"focus left"}},
        "override":{"context":"mode == main","bindings":{"ctrl-h":"focus right"}},
        "app":{"context":"mode == main && app == 'terminal'","bindings":{"ctrl-h":"pass"}}
        """#)
        let chord = ModeChord(code: 4, modifiers: .control)
        let normal = resolveModeKey(keymap: keymap, context: .init(mode: "main"), mode: .zero, chord: chord)
        XCTAssertEqual(command(normal), ["focus right"])
        let pass = resolveModeKey(keymap: keymap, context: .init(mode: "main", app: "terminal"), mode: .zero, chord: chord)
        XCTAssertEqual(pass.kind, .pass)
    }

    func testEqualTiesAndWholeChordSequencePrefixesAreErrorsButDisjointModesAreValid() throws {
        for (a, b, key, valid) in [("mode == main", "mode == window", "h", true),
                                   ("mode == main", "app == terminal", "h", false),
                                   ("mode == main", "app == terminal", "h j", false)] {
            let json = try JSONDecoder().decode(JSONValue.self, from: Data("""
            {"keymap":{"a":{"context":"\(a)","bindings":{"h":"focus left"}},"b":{"context":"\(b)","bindings":{"\(key)":"focus right"}}}}
            """.utf8))
            XCTAssertEqual(parseConfig(json).errors.isEmpty, valid)
        }
    }
    func testModeSugarCannotSilentlyReplaceANamedKeymapBlock() throws {
        for binding in [#"{}"#, #"{"h":"focus left"}"#] {
            let value = try JSONDecoder().decode(JSONValue.self, from: Data("""
            {"mode":{"main":{"binding":\(binding)}},"keymap":{"mode-main":{"context":"mode == main","bindings":{"h":"focus right"}}}}
            """.utf8))
            let parsed = parseConfig(value)
            if binding == "{}" {
                XCTAssertTrue(parsed.errors.isEmpty)
                let result = resolveModeKey(keymap: parsed.config.keymap, context: .init(mode: "main"), mode: .zero, chord: .init(code: 4))
                XCTAssertEqual(command(result), ["focus right"])
            } else { XCTAssertTrue(parsed.errors.contains { $0.description.contains("mode-main") }) }
        }
    }
    func testSpaceSequencesInModeBindingsUseTheSameGrammarAsKeymapBlocks() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"mode":{"main":{},"sequence":{"binding":{"g t":"focus left","ctrl-g shift-t u":"focus right"}}}}"#.utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        XCTAssertEqual(parsed.config.modes["sequence"]?.sequenceBindings.count, 2)
        let first = resolveModeKey(keymap: parsed.config.keymap, context: .init(mode: "sequence"), mode: .zero, chord: .init(code: 5))
        XCTAssertEqual(first.kind, .pending)
        let last = resolveModeKey(keymap: parsed.config.keymap, context: .init(mode: "sequence"), mode: .zero, chord: .init(code: 17), pending: first.pending)
        XCTAssertEqual(command(last), ["focus left"])
    }

    func testModeBindingSugarAcceptsPassAndOnlyLensOpenersChangeUnboundDefault() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"mode":{"main":{},"custom":{"binding":{"ctrl-u":"pass","g t":"pass"},"on-enter":"lens step next"},"opener":{"on-enter":"lens windows"}}}"#.utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        XCTAssertEqual(parsed.config.modes["custom"]?.unbound, .pass)
        XCTAssertEqual(parsed.config.modes["opener"]?.unbound, .consume)
        let result = resolveModeKey(keymap: parsed.config.keymap, context: .init(mode: "custom"), mode: .zero, chord: .init(code: 32, modifiers: .control))
        XCTAssertEqual(result.kind, .pass)
        XCTAssertFalse(modeRegistrationChords(keymap: parsed.config.keymap, context: .init(mode: "custom"), mode: .zero).contains(.init(code: 32, modifiers: .control)))
    }

    func testSequenceContinuationsWinAndNonContinuationIsFreshAndEscapeOnlyCancelsPending() throws {
        let keymap = try map(#""keys":{"context":"mode == window","bindings":{"m a":"focus left","a":"focus right","j":"focus down"}}"#)
        let context = KeyContext(mode: "window")
        let first = resolveModeKey(keymap: keymap, context: context, mode: .zero, chord: .init(code: 46))
        XCTAssertEqual(first.kind, .pending)
        XCTAssertEqual(command(resolveModeKey(keymap: keymap, context: context, mode: .zero, chord: .init(code: 0), pending: first.pending)), ["focus left"])
        XCTAssertEqual(command(resolveModeKey(keymap: keymap, context: context, mode: .zero, chord: .init(code: 38), pending: first.pending)), ["focus down"])
        XCTAssertEqual(resolveModeKey(keymap: keymap, context: context, mode: .zero, chord: .init(code: 53), pending: first.pending).kind, .consume)
    }

    func testCountsOnlyUseUnboundDigitsAndRepeatWholeCommandListInOrder() throws {
        let keymap = try map(#""keys":{"context":"mode == window","bindings":{"l":["focus right","focus down"],"1":"workspace 1"}}"#)
        var mode = Mode.zero; mode.count = true
        let context = KeyContext(mode: "window")
        let count = resolveModeKey(keymap: keymap, context: context, mode: mode, chord: .init(code: 20), characters: "3")
        XCTAssertEqual(count.count, 3)
        let repeated = resolveModeKey(keymap: keymap, context: context, mode: mode, chord: .init(code: 37), count: count.count)
        XCTAssertEqual(repeated.repetitions, 3)
        XCTAssertEqual(command(repeated), ["focus right", "focus down"])
        XCTAssertEqual(resolveModeKey(keymap: keymap, context: context, mode: mode, chord: .init(code: 18), characters: "1").kind, .run)
    }

    func testUnboundEscapeCancelsLatchedAndTransientAndMainPassesIt() {
        for lifetime in [Mode.Lifetime.latched, .transient] {
            var mode = Mode.zero; mode.lifetime = lifetime
            XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "window"), mode: mode, chord: .init(code: 53)).kind, .cancel)
        }
        XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "main"), mode: .zero, chord: .init(code: 53)).kind, .pass)
    }

    func testHeldMatchingDiscountsEntryModifiersAndForeignModifiersLeave() throws {
        let keymap = try map(#""keys":{"context":"mode == cmd-tab","bindings":{"tab":"lens step next","shift-tab":"lens step prev","w":"lens close-window","enter":"lens focus"}}"#)
        var mode = Mode.zero; mode.lifetime = .held; mode.unbound = .latch
        for (code, flags, expected) in [(UInt16(48), NSEvent.ModifierFlags.command, "lens step next"),
                                        (48, [.command, .shift], "lens step prev"), (13, .command, "lens close-window"),
                                        (36, .command, "lens focus")] {
            XCTAssertEqual(command(resolveModeKey(keymap: keymap, context: .init(mode: "cmd-tab"), mode: mode, chord: .init(code: code, modifiers: flags), entryModifiers: .command)), [expected])
        }
        XCTAssertEqual(resolveModeKey(keymap: keymap, context: .init(mode: "cmd-tab"), mode: mode, chord: .init(code: 4, modifiers: [.command, .option]), entryModifiers: .command).kind, .global)
    }

    func testLatchOnlyReinterpretsLettersAndConsumesOtherUnboundKeys() {
        var mode = Mode.zero; mode.unbound = .latch; mode.latchTo = "search"
        XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "held"), mode: mode, chord: .init(code: 1), characters: "s").target, "search")
        for text in ["1", " ", "!", ""] {
            XCTAssertEqual(resolveModeKey(keymap: [], context: .init(mode: "held"), mode: mode, chord: .init(code: 18), characters: text).kind, .consume)
        }
    }

    func testSearchBoundKeysWinAndUnboundClipboardAndLettersType() throws {
        let keymap = try map(#""keys":{"context":"mode == search","bindings":{"x":"lens peek","cmd-w":"lens close-window"}}"#)
        var mode = Mode.zero; mode.unbound = .type
        XCTAssertEqual(command(resolveModeKey(keymap: keymap, context: .init(mode: "search"), mode: mode, chord: .init(code: 7), characters: "x")), ["lens peek"])
        for (code, flags) in [(UInt16(0), NSEvent.ModifierFlags.command), (9, .command), (1, [])] {
            XCTAssertEqual(resolveModeKey(keymap: keymap, context: .init(mode: "search"), mode: mode, chord: .init(code: code, modifiers: flags)).kind, .type)
        }
    }
}
