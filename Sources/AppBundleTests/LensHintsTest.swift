@testable import AppBundle
import AppKit
import Common
import XCTest
import SwiftUI

@MainActor
final class LensHintsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests(); enterModeForTests("browse") }
    private func session(_ presentation: String, hints: String = "held", key: String = "alt") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        settings.hints = hints; settings.hintsKey = key
        return LensSession(name: "test", settings: settings, items: [], search: "")
    }

    func testSummonChordExcludesInvokingModifiersUntilLetterEndsHold() {
        for (modifier, expected): (NSEvent.ModifierFlags, String) in [(.option, "⇧↩ Summon to 1"), (.command, "⌥↩ Summon to 1")] {
            let model = session("strip")
            model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: modifier))
            model.updateHintModifiers(modifier.union(.option))
            XCTAssertEqual(model.summonHint(destination: "1"), expected)
            XCTAssertEqual(model.summonHintsShown, modifier == .command)
            XCTAssertEqual(model.hintLegend.first { $0.phrase == "summon here" }?.chords, ["⌥↩", "⇧↩"])
            model.enterBrowseForTests()
            XCTAssertEqual(model.summonHint(destination: "1"), "⌥↩ Summon to 1")
        }
        var settings = LensConfig(); settings.presentation = "strip"; testModeBindings = ["alt-enter": ["summon"]]
        let model = LensSession(name: "only-option", settings: settings, items: [], search: "")
        model.enterHeldModeForTests(ModeInvocation(keyCode: 48, invoking: .option))
        XCTAssertFalse(model.hintsShown)
        XCTAssertFalse(model.summonHintsShown)
        XCTAssertNil(model.summonHint(destination: "1"))
        model.enterBrowseForTests()
        XCTAssertTrue(model.summonHintsShown)
        XCTAssertEqual(model.summonHint(destination: "1"), "⌥↩ Summon to 1")
    }


    func testLiveFlagsWinOverAHoldReleaseRecordedWhileOpening() {
        for presentation in ["list", "grid", "miniatures"] {
            let model = session(presentation)
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _, _ in }, closeThumbnails: { _ in }, flags: { .option })
            let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
            defer { owner.dismiss() }
            let ticket = owner.begin("test", toggle: false)!
            owner.openingModifiersChanged([])
            owner.complete(model, ticket: ticket)
            XCTAssertFalse(model.isHeld, presentation)
            XCTAssertTrue(model.hintsShown, "Option went down after Cmd was released: \(presentation)")
        }
    }

    func testListLegendFollowsLayoutUntilMeasuredAndStaysInsideTheWindow() {
        let model = session("list")
        XCTAssertEqual(model.hintPanelBottom, model.listLayout.topOffset + model.listLayout.height, "Before the first measurement")
        model.listPanelHeight = model.listLayout.panelHeight + 50
        XCTAssertEqual(model.hintPanelBottom, model.listLayout.topOffset + model.listLayout.panelHeight, "Content clipped by the window")
    }

    func testSidebarClearanceOnlyWhereTheSidebarCoversTheCanvas() {
        XCTAssertEqual(LensHintGeometry.sidebarClearance(presentation: "grid", monitorInset: 56, scale: 1), 64)
        XCTAssertEqual(LensHintGeometry.sidebarClearance(presentation: "strip", monitorInset: 56, scale: 0.5), 60)
        XCTAssertEqual(LensHintGeometry.sidebarClearance(presentation: "miniatures", monitorInset: 56, scale: 1), 0)
        XCTAssertEqual(LensHintGeometry.sidebarClearance(presentation: "grid", monitorInset: 0, scale: 1), 0)
    }

    func testIconFallbackGetsNoBackingWhileHintsShow() throws {
        var entry = TileEntry(title: "Note", appName: "Notes", aspect: 1)
        entry.picture = WindowThumbnail(); entry.frozen = true
        let tile = TileView(entry: entry, kind: .picture, presentation: "grid", metrics: TileMetrics(scale: 1), size: CGSize(width: 300, height: 200), settings: LensConfig(), selected: false, marked: false, hint: nil, hintsShown: true)
        let image = try XCTUnwrap(ImageRenderer(content: tile).cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let opaque = (0..<image.width).flatMap { x in (0..<image.height).map { (x, $0) } }
            .filter { (try? XCTUnwrap(bitmap.colorAt(x: $0.0, y: $0.1)))?.alphaComponent ?? 0 > 0.99 }.count
        XCTAssertLessThan(Double(opaque) / Double(image.width * image.height), 0.5, "An icon is not translucent and gets no plate")
    }

    func testListLegendUsesPaintedHeightIncludingDiagnosticRows() {
        let model = session("list")
        model.listPanelHeight = 350
        XCTAssertEqual(model.hintPanelBottom, model.listLayout.topOffset + 350)
        model.listPanelHeight = 380
        XCTAssertEqual(model.hintPanelBottom, model.listLayout.topOffset + 380)
        XCTAssertEqual(LensHintGeometry.legendTop(panelBottom: model.hintPanelBottom, screenHeight: 1080, legendHeight: 36, scale: 1), model.hintPanelBottom + 14)
    }

    func testLegendWidthLeavesScaledScreenInsets() {
        XCTAssertEqual(LensHintGeometry.legendMaxWidth(screenWidth: 1920, scale: 1), 1856)
        XCTAssertEqual(LensHintGeometry.legendMaxWidth(screenWidth: 960, scale: 0.5), 928)
        XCTAssertEqual(LensHintGeometry.legendMaxWidth(screenWidth: 1280, scale: 2.0 / 3, occupiedSideInset: 56), 1168)
        XCTAssertEqual(LensHintGeometry.legendMaxWidth(screenWidth: 1280, scale: 2.0 / 3), 1280 - 128.0 / 3, accuracy: 0.001)
    }

    func testWorkspaceChipClearsFrozenBadgeWithItsUsualInset() {
        XCTAssertEqual(LensHintGeometry.workspaceChipBottomInset(badgeHeight: 0, scale: 1), 8)
        XCTAssertEqual(LensHintGeometry.workspaceChipBottomInset(badgeHeight: 18, scale: 1), 26)
        XCTAssertEqual(LensHintGeometry.workspaceChipBottomInset(badgeHeight: 9, scale: 0.5), 13)
    }

    func testDimmedPictureRendersOpaqueOverDeskOnlyWhenHintsShow() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let thumbnail = WindowThumbnail()
        thumbnail.accept(try XCTUnwrap(context.makeImage()))
        var entry = TileEntry(title: "Note", appName: "Notes", aspect: 1)
        entry.picture = thumbnail; entry.frozen = true
        for presentation in ["grid", "strip"] {
            for shown in [false, true] {
                let tile = TileView(entry: entry, kind: .picture, presentation: presentation, metrics: TileMetrics(scale: 1), size: CGSize(width: 300, height: 200), settings: LensConfig(), selected: false, marked: false, hint: nil, hintsShown: shown)
                let renderer = ImageRenderer(content: tile)
                let image = try XCTUnwrap(renderer.cgImage)
                let bitmap = NSBitmapImageRep(cgImage: image)
                let alpha = try XCTUnwrap(bitmap.colorAt(x: image.width / 2, y: image.height / 2)).alphaComponent
                if shown { XCTAssertEqual(alpha, 1, accuracy: 0.01, presentation) }
                else { XCTAssertLessThan(alpha, 0.9, "Hidden hints preserve the original translucent picture") }
                XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.1, "Backing stays inside the fitted picture")
            }
        }
    }

    func testDimmedPicturesHaveBackingOnlyWhileHintsShow() {
        for look in ["dimmed", "pause-badge", "age-badge"] {
            for frozen in [false, true] {
                var entry = TileEntry(title: "Note", appName: "Notes"); entry.frozen = frozen
                var settings = LensConfig(); settings.frozenThumbnail = look
                for shown in [false, true] {
                    let tile = TileView(entry: entry, kind: .picture, presentation: "grid", metrics: TileMetrics(scale: 1), size: CGSize(width: 300, height: 200), settings: settings, selected: false, marked: false, hint: nil, hintsShown: shown)
                    XCTAssertEqual(tile.pictureBackingRequired, shown && frozen && look == "dimmed")
                }
            }
        }
    }

    func testEnterAndClicksUseModeModifiersInEveryPresentation() {
        for presentation in ["list", "grid", "strip", "miniatures"] {
            for held in [false, true] {
                for (extra, command): (NSEvent.ModifierFlags, String) in [([], "focus"), (.option, "summon"), (.shift, "summon")] {
                    let model = session(presentation)
                    if held { model.enterHeldModeForTests(.init(keyCode: 48, invoking: .command)) }
                    else { model.enterBrowseForTests() }
                    let flags = held ? extra.union(.command) : extra
                    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
                    let click = model.key(for: event, click: true).flatMap { model.actionCommandsForTests(for: $0).first }
                    XCTAssertEqual(click, held && extra == .shift ? "focus" : command)
                    var action: String?
                    model.onAction = { action = model.actionCommandsForTests(for: $0).first }
                    model.pressForTests(event)
                    XCTAssertEqual(action, command, "\(presentation), \(held), \(extra)")
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


    func testReadinessSamplesPhysicalModifiersInEveryPresentation() {
        for presentation in ["strip", "list", "grid", "miniatures"] {
            let model = session(presentation)
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _, _ in }, closeThumbnails: { _ in }, flags: { [.command, .option] })
            let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
            defer { owner.dismiss() }
            let gesture = ModeInvocation(keyCode: 48, invoking: .command)
            let ticket = owner.begin("test", toggle: false)!
            owner.complete(model, ticket: ticket)
            XCTAssertTrue(model.hintsShown, "Readiness reads physical Option; the live Command Hold still subtracts only Command")
        }
    }



    func testHintSnapshotsAreReusedAcrossSectionAndPresentationChanges() {
        let model = session("grid")
        let grouped = model.hintSnapshot
        XCTAssertTrue(model.hintSnapshot === grouped)
        model.changeSections("app")
        XCTAssertTrue(model.hintSnapshot === grouped)
        model.changePresentation("strip")
        let ungrouped = model.hintSnapshot
        XCTAssertFalse(ungrouped === grouped)
        XCTAssertFalse(ungrouped.legend.contains { $0.phrase == "group" })
        XCTAssertTrue(model.hintSnapshot === ungrouped)
        model.changePresentation("list")
        XCTAssertFalse(model.hintSnapshot === grouped)
        XCTAssertTrue(model.hintLegend.contains { $0.phrase == "group" })
    }

    func testLegendReadsCurrentModeBindingsForEveryLens() {
        let original = session("grid")
        XCTAssertEqual(original.hintLegend.first { $0.phrase == "close" }?.chords, ["⌘W"])
        testModeBindings["cmd-w"] = []; testModeBindings["cmd-d"] = ["close"]
        let changed = session("grid")
        for model in [original, changed, session("strip")] {
            XCTAssertEqual(model.hintLegend.first { $0.phrase == "close" }?.chords, ["⌘D"])
        }
        XCTAssertFalse(session("strip").hintLegend.contains { $0.phrase == "group" })
    }

    func testShippedModeLegendKeepsTheSixActionGroupsAndOmitsViewControls() {
        for mode in ["browse", "search"] {
            enterModeForTests(mode)
            XCTAssertEqual(session("grid").hintLegend.map(\.phrase), ["focus", "summon here", "send to workspace", "close", "peek", "group"], mode)
        }
    }

    func testLegendGroupsCommandsAndDigitsWithoutInventingKeys() {
        var commands: [String: [String]] = ["enter": ["focus"], "alt-enter": ["summon"], "shift-enter": ["summon"], "cmd-w": ["close"], "space": ["peek"], "cmd-y": ["peek"], "cmd-g": ["sections next"]]
        for n in 1...9 { commands["cmd-\(n)"] = ["move-node-to-workspace \(n)"] }
        func legend() -> [LensHintEntry] { lensHintLegend(keys: LensKeyBinding.resolve(commands), commands: commands) }
        XCTAssertEqual(legend().map(\.phrase), ["focus", "summon here", "send to workspace", "close", "peek", "group"])
        XCTAssertEqual(legend().first { $0.phrase == "summon here" }?.chords, ["⌥↩", "⇧↩"])
        XCTAssertEqual(legend().first { $0.phrase == "send to workspace" }?.chords, ["⌘1–9"])
        XCTAssertFalse(session("strip").hintLegend.contains { $0.phrase == "group" })
        commands["cmd-w"] = []; commands["cmd-d"] = ["close"]
        XCTAssertEqual(legend().first { $0.phrase == "close" }?.chords, ["⌘D"])
        for n in [3,5,6,7,8,9] { commands["cmd-\(n)"] = [] }
        XCTAssertEqual(legend().first { $0.phrase == "send to workspace" }?.chords, ["⌘1", "⌘2", "⌘4"])
        commands["ctrl-x"] = ["workspace 2", "focus left"]; commands["ctrl-y"] = commands["ctrl-x"]
        XCTAssertEqual(legend().last?.phrase, "workspace 2; focus left")
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
        var settings = LensConfig(); testModeBindings = ["ctrl-s": ["summon"], "cmd-2": ["move-node-to-workspace 2", "focus"]]
        let custom = LensSession(name: "custom", settings: settings, items: [], search: "")
        XCTAssertNil(custom.workspaceHint(workspace: "2"))
        XCTAssertEqual(custom.summonHint(destination: "3"), "⌃S Summon to 3")
        testModeBindings["a"] = ["summon", "focus"]
        let ordered = LensSession(name: "legend-order", settings: settings, items: [], search: "")
        XCTAssertEqual(ordered.summonHint(destination: "3"), "⌃S Summon to 3", "The dedicated Summon entry precedes custom command lists in the legend")
    }

    func testWorkspaceChipOnlyOnPictureAndCardTilesWhileShownAndUsesTheShownWindow() {
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
        XCTAssertEqual(model.workspaceHint(for: second), "⌘3", "An app entry's chip is its shown window's workspace")
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
