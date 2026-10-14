@testable import AppBundle
import AppKit
import Common
import XCTest

@MainActor
final class LensHintsTest: XCTestCase {
    private func session(_ presentation: String, hints: String = "held", key: String = "alt") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        settings.hints = hints; settings.hintsKey = key
        return LensSession(name: "test", settings: settings, items: [], search: "")
    }

    func testEnterAndModifiedClicksKeepTheirCommandsWithAndWithoutHoldInEveryPresentation() {
        for presentation in ["list", "grid", "strip", "miniatures"] {
            for held in [false, true] {
                let model = session(presentation)
                let gesture = StripGesture(keyCode: 48, invoking: .command)
                if held { model.startHold(gesture); if presentation == "strip" { model.stripGesture = gesture } }
                else if presentation == "strip" { model.startHold(gesture); model.endHoldByKey() }
                for (extra, command): (NSEvent.ModifierFlags, String) in [([], "focus"), (.option, "summon"), (.shift, "summon")] {
                    let flags = held ? extra.union(.command) : extra
                    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                                windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
                    var action: String?
                    model.onAction = { action = model.commands(for: $0).first }
                    model.perform(model.meaning(for: event))
                    XCTAssertEqual(action, command, "\(presentation), hold=\(held), \(extra)")
                    XCTAssertEqual(model.key(for: event, click: true).flatMap { model.commands(for: $0).first }, held && presentation == "strip" && extra == .shift ? "focus" : command, "\(presentation), hold=\(held), click \(extra)")
                }
                if held && presentation == "strip" {
                    XCTAssertEqual(model.stripReleaseKey(flags: []).flatMap { model.commands(for: $0).first }, "focus")
                    XCTAssertEqual(model.stripReleaseKey(flags: .option).flatMap { model.commands(for: $0).first }, "summon")
                }
            }
        }
    }

    func testHintsKeyAlwaysAndShiftAlone() {
        for presentation in ["list", "grid", "strip", "miniatures"] {
            let model = session(presentation)
            XCTAssertFalse(model.hintsShown)
            XCTAssertEqual(model.panelGlassOpacity, 1)
            model.updateHintModifiers(.shift); XCTAssertFalse(model.hintsShown)
            model.updateHintModifiers([.option, .shift]); XCTAssertTrue(model.hintsShown)
            XCTAssertEqual(model.panelGlassOpacity, presentation == "miniatures" ? 1 : 0.55)
            model.updateHintModifiers([]); XCTAssertFalse(model.hintsShown)
            XCTAssertEqual(model.panelGlassOpacity, 1)
            let always = session(presentation, hints: "always")
            XCTAssertTrue(always.hintsShown)
            always.updateHintModifiers(.option); always.updateHintModifiers([])
            XCTAssertTrue(always.hintsShown)
            let control = session(presentation, key: "ctrl")
            control.updateHintModifiers(.option); XCTAssertFalse(control.hintsShown)
            control.updateHintModifiers(.control); XCTAssertTrue(control.hintsShown)
        }
    }

    func testReleaseAndNonHoldTriggerCountEachModifierAtTheRightTime() {
        for presentation in ["list", "grid", "strip", "miniatures"] {
            let held = session(presentation, key: "shift")
            held.startHold(StripGesture(keyCode: 31, invoking: [.option, .shift]))
            XCTAssertEqual(held.hintsShown, presentation == "strip")
            held.endHold(flags: .shift)
            XCTAssertTrue(held.hintsShown, "After Option releases, still-held Shift counts")
            held.updateHintModifiers([])
            XCTAssertFalse(held.hintsShown)
            let trigger = session(presentation, key: "shift")
            trigger.startHold(StripGesture(keyCode: nil, invoking: [.option, .shift]))
            trigger.updateHintModifiers(.option)
            XCTAssertFalse(trigger.hintsShown)
            trigger.updateHintModifiers([.option, .shift])
            XCTAssertTrue(trigger.hintsShown, "Repressed Shift counts even before the Trigger's Option releases")
        }
    }

    func testOnlyStripSamplesPhysicalModifiersAtOpening() {
        for presentation in ["strip", "list", "grid", "miniatures"] {
            let model = session(presentation)
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { [.command, .option] })
            let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
            defer { owner.dismiss() }
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = owner.begin("test", toggle: false, strip: presentation == "strip" ? gesture : nil, invocation: gesture)!
            owner.complete(model, ticket: ticket)
            XCTAssertEqual(model.hintsShown, presentation == "strip", "Only the strip reads the physical Option pressed during opening")
        }
    }

    func testPresentationConversionReevaluatesStripExceptionWithoutChangingActions() {
        let model = session("strip")
        model.startHold(StripGesture(keyCode: 48, invoking: .option))
        XCTAssertTrue(model.hintsShown)
        model.changePresentation("grid")
        XCTAssertFalse(model.hintsShown)
        model.endHoldByKey()
        XCTAssertTrue(model.hintsShown)
    }

    func testTriggerModifiersAreIgnoredUntilEachReleasedExceptStrip() {
        for presentation in ["list", "grid", "miniatures", "strip"] {
            let model = session(presentation)
            model.startHold(StripGesture(keyCode: nil, invoking: [.option, .shift]))
            XCTAssertEqual(model.hintsShown, presentation == "strip")
            model.updateHintModifiers(.option)
            XCTAssertEqual(model.hintsShown, presentation == "strip")
            model.updateHintModifiers([]); XCTAssertFalse(model.hintsShown)
            model.updateHintModifiers(.option); XCTAssertTrue(model.hintsShown)
        }
    }

    func testLegendUsesActiveSnapshotAndAnotherLensOwnKeys() {
        var settings = LensConfig()
        let original = LensSession(name: "old", settings: settings, items: [], search: "")
        settings.keys["cmd-w"] = []; settings.keys["cmd-d"] = ["close"]
        let changed = LensSession(name: "new", settings: settings, items: [], search: "")
        XCTAssertEqual(changed.hintLegend.first { $0.phrase == "close" }?.chords, ["⌘D"])
        XCTAssertEqual(original.hintLegend.first { $0.phrase == "close" }?.chords, ["⌘W"])
        let other = session("strip")
        XCTAssertFalse(other.hintLegend.contains { $0.phrase == "group" })
        XCTAssertEqual(other.hintLegend.first { $0.phrase == "close" }?.chords, ["⌘W"])
    }

    func testLegendGroupsCommandsAndDigitsWithoutInventingKeys() {
        var settings = LensConfig()
        func legend() -> [LensHintEntry] { lensHintLegend(keys: LensKeyBinding.resolve(settings.keys), commands: settings.keys) }
        XCTAssertEqual(legend().map(\.phrase), ["focus", "summon here", "send to workspace", "close", "group"])
        XCTAssertEqual(legend().first { $0.phrase == "summon here" }?.chords, ["⌥↩", "⇧↩"])
        XCTAssertEqual(legend().first { $0.phrase == "send to workspace" }?.chords, ["⌘1–9"])
        var stripSettings = settings; stripSettings.presentation = "strip"
        let strip = LensSession(name: "no-sections", settings: stripSettings, items: [], search: "")
        XCTAssertFalse(lensHintLegend(keys: strip.activeKeyBindings, commands: stripSettings.keys).contains { $0.phrase == "group" })
        settings.keys["cmd-w"] = []; settings.keys["cmd-d"] = ["close"]
        XCTAssertEqual(legend().first { $0.phrase == "close" }?.chords, ["⌘D"])
        settings.keys["cmd-3"] = []; settings.keys["cmd-5"] = []; settings.keys["cmd-6"] = []
        settings.keys["cmd-7"] = []; settings.keys["cmd-8"] = []; settings.keys["cmd-9"] = []
        XCTAssertEqual(legend().first { $0.phrase == "send to workspace" }?.chords, ["⌘1", "⌘2", "⌘4"])
        settings.keys["ctrl-x"] = ["workspace 2", "focus left"]
        XCTAssertEqual(legend().last?.phrase, "workspace 2; focus left")
        settings.keys["ctrl-y"] = settings.keys["ctrl-x"]
        XCTAssertEqual(legend().last?.chords, ["⌃X", "⌃Y"])
    }

    func testLegendSharesIdenticalWorkspaceCommandsWithDigitAliases() {
        let commands = ["cmd-1": ["move-node-to-workspace 1"], "cmd-2": ["move-node-to-workspace 2"], "ctrl-s": ["move-node-to-workspace 2"]]
        let legend = lensHintLegend(keys: LensKeyBinding.resolve(commands), commands: commands)
        XCTAssertEqual(legend.count, 1)
        XCTAssertEqual(legend.first?.phrase, "send to workspace")
        XCTAssertEqual(legend.first?.chords, ["⌘1–2", "⌃S"])
    }

    func testWorkspaceChipRequiresExactCommandAndSummonChordPrefersHintsKey() {
        let model = session("grid")
        XCTAssertEqual(model.workspaceHint(workspace: "2"), "⌘2")
        XCTAssertNil(model.workspaceHint(workspace: "elsewhere"))
        XCTAssertEqual(model.summonHint(destination: "1"), "⌥↩ Summon to 1")
        var settings = LensConfig(); settings.keys = ["ctrl-s": ["summon"], "cmd-2": ["move-node-to-workspace 2", "focus"]]
        let custom = LensSession(name: "custom", settings: settings, items: [], search: "")
        XCTAssertNil(custom.workspaceHint(workspace: "2"))
        XCTAssertEqual(custom.summonHint(destination: "3"), "⌃S Summon to 3")
        settings.keys["a"] = ["summon", "focus"]
        let ordered = LensSession(name: "legend-order", settings: settings, items: [], search: "")
        XCTAssertEqual(ordered.summonHint(destination: "3"), "⌃S Summon to 3", "The dedicated Summon entry precedes custom command lists in the legend")
    }

    func testWorkspaceChipOnlyOnPictureAndCardTilesWhileShownAndUsesFirstAppWindow() {
        let item = SwitcherPaletteItem(id: 1, title: "Demo", appName: "Demo", icon: nil, workspaceName: "2", appIdentity: "app", isFocused: false)
        for presentation in ["strip", "grid", "list", "miniatures"] {
            for kind in ["picture", "card", "text"] {
                var settings = LensConfig(); settings.presentation = presentation; settings.tile = kind
                let model = LensSession(name: "chips", settings: settings, items: [item], search: "")
                XCTAssertNil(model.workspaceHint(for: item))
                model.updateHintModifiers(.option)
                XCTAssertEqual(model.workspaceHint(for: item), (presentation == "strip" || presentation == "grid") && kind != "text" ? "⌘2" : nil)
            }
        }
        var settings = LensConfig(); settings.entries = "app"; settings.presentation = "grid"
        let second = SwitcherPaletteItem(id: 2, title: "Later", appName: "Demo", icon: nil, workspaceName: "3", appIdentity: "app", isFocused: false)
        let model = LensSession(name: "apps", settings: settings, items: [item, second], search: "")
        model.updateHintModifiers(.option)
        XCTAssertEqual(model.workspaceHint(for: second), "⌘2")
        let empty = SwitcherPaletteItem(id: 3, title: "Empty", appName: "Empty", icon: nil, workspaceName: "", appIdentity: "empty", isFocused: false)
        XCTAssertNil(model.workspaceHint(for: empty))
    }

    func testLegendSitsBelowPanelWithBottomClearanceAtPanelScale() {
        XCTAssertEqual(LensHintGeometry.legendTop(panelBottom: 600, screenHeight: 1080, legendHeight: 36, scale: 1), 614)
        XCTAssertEqual(LensHintGeometry.legendTop(panelBottom: 1080, screenHeight: 1080, legendHeight: 36, scale: 1), 992)
        XCTAssertEqual(LensHintGeometry.legendTop(panelBottom: 540, screenHeight: 540, legendHeight: 18, scale: 0.5), 496)
    }

    func testConfigDefaultsForShippedAndUserLensAndProfileOverrides() throws {
        let shipped = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))
        XCTAssertEqual(parseConfig(shipped).config.lenses["search"]?.hints, "held")
        XCTAssertEqual(parseConfig(shipped).config.lenses["search"]?.hintsKey, "alt")
        let user = try XCTUnwrap(parseConfig(.object(["lenses": .object(["user": .object([:])])])).config.lenses["user"])
        XCTAssertEqual(user.hints, "held"); XCTAssertEqual(user.hintsKey, "alt")
        let profile = LensConfig(.object(["hints": .string("always"), "when": .object(["default": .object(["hints-key": .string("ctrl")])])]))
        XCTAssertEqual(profile.json["hints"], .string("always"))
        XCTAssertEqual(profile.json["hints-key"], .string("ctrl"))
    }
}
