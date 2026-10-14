@testable import AppBundle
import AppKit
import Common
import XCTest
import SwiftUI

@MainActor
final class LensHintsTest: XCTestCase {
    private func session(_ presentation: String, hints: String = "held", key: String = "alt") -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation
        settings.hints = hints; settings.hintsKey = key
        return LensSession(name: "test", settings: settings, items: [], search: "")
    }

    func testSummonChordExcludesInvokingModifiersUntilLetterEndsHold() {
        for (modifier, expected): (NSEvent.ModifierFlags, String) in [(.option, "⇧↩ Summon to 1"), (.command, "⌥↩ Summon to 1")] {
            let model = session("strip")
            model.startHold(StripGesture(keyCode: 48, invoking: modifier))
            model.updateHintModifiers(modifier.union(.option))
            XCTAssertEqual(model.summonHint(destination: "1"), expected)
            XCTAssertTrue(model.summonHintsShown)
            XCTAssertEqual(model.hintLegend.first { $0.phrase == "summon here" }?.chords, ["⌥↩", "⇧↩"])
            model.endHoldByKey()
            XCTAssertEqual(model.summonHint(destination: "1"), "⌥↩ Summon to 1")
        }
        var settings = LensConfig(); settings.presentation = "strip"; settings.keys = ["alt-enter": ["summon"]]
        let model = LensSession(name: "only-option", settings: settings, items: [], search: "")
        model.startHold(StripGesture(keyCode: 48, invoking: .option))
        XCTAssertTrue(model.hintsShown)
        XCTAssertFalse(model.summonHintsShown)
        XCTAssertNil(model.summonHint(destination: "1"))
        model.endHoldByKey()
        XCTAssertTrue(model.summonHintsShown)
        XCTAssertEqual(model.summonHint(destination: "1"), "⌥↩ Summon to 1")
    }

    func testReleasedTriggerDuringOpeningAllowsFirstHintsPress() {
        for presentation in ["list", "grid", "miniatures"] {
            for liveFlags: NSEvent.ModifierFlags in [[], .option] {
                let model = session(presentation)
                let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { liveFlags })
                let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
                defer { owner.dismiss() }
                let gesture = StripGesture(keyCode: nil, invoking: .option)
                let ticket = owner.begin("test", toggle: false, invocation: gesture)!
                owner.complete(model, ticket: ticket)
                XCTAssertFalse(model.hintsShown)
                model.updateHintModifiers(.option)
                XCTAssertEqual(model.hintsShown, liveFlags.isEmpty, presentation)
                model.updateHintModifiers([])
                model.updateHintModifiers(.option)
                XCTAssertTrue(model.hintsShown)
            }
        }
    }

    func testLiveFlagsWinOverAHoldReleaseRecordedWhileOpening() {
        for presentation in ["list", "grid", "miniatures"] {
            let model = session(presentation)
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { .option })
            let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
            defer { owner.dismiss() }
            let ticket = owner.begin("test", toggle: false, invocation: StripGesture(keyCode: 48, invoking: .command))!
            owner.openingFlagsChanged([])
            owner.complete(model, ticket: ticket)
            XCTAssertNil(model.hold, presentation)
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

    func testReadinessSamplesPhysicalModifiersInEveryPresentation() {
        for presentation in ["strip", "list", "grid", "miniatures"] {
            let model = session(presentation)
            let dependencies = LensLifecycle.Dependencies(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { [.command, .option] })
            let owner = LensLifecycle(dependencies: dependencies, emit: { _ in }, show: { _ in }, hide: {})
            defer { owner.dismiss() }
            let gesture = StripGesture(keyCode: 48, invoking: .command)
            let ticket = owner.begin("test", toggle: false, strip: presentation == "strip" ? gesture : nil, invocation: gesture)!
            owner.complete(model, ticket: ticket)
            XCTAssertTrue(model.hintsShown, "Readiness reads physical Option; the live Command Hold still subtracts only Command")
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
        XCTAssertTrue(model.hintSnapshot === grouped)
        XCTAssertTrue(model.hintLegend.contains { $0.phrase == "group" })
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
