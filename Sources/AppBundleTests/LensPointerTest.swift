@testable import AppBundle
import AppKit
import Clocks
import XCTest

@MainActor
final class LensPointerTest: XCTestCase {
    private func items(_ count: Int = 4, wide: Bool = false) -> [SwitcherPaletteItem] {
        (1...count).map {
            SwitcherPaletteItem(id: UInt32($0), title: "Window \($0)", appName: "Demo", icon: nil,
                                workspaceName: $0 < 3 ? "1" : "2", isFocused: $0 == 1,
                                tile: TileEntry(title: "Window \($0)", appName: "Demo", aspect: wide ? 3.5 : 4 / 3,
                                                realSize: CGSize(width: wide ? 3500 : 800, height: wide ? 1000 : 600)))
        }
    }

    func testMovingPointerSelectsEveryStripAndGridTileAndIgnoresChrome() {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation; settings.sections = "workspace"
            let session = LensSession(name: "pointer", settings: settings, items: items(), search: "")
            let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
            for (index, tile) in layout.tiles.enumerated() {
                session.hoverTile(at: CGPoint(x: tile.frame.midX, y: tile.frame.midY),
                                  pointerLocation: CGPoint(x: 10000 + index * 10, y: 10000))
                XCTAssertEqual(session.selectedId, session.results[index].id, presentation)
            }
            let selected = session.selectedId
            let gap = CGPoint(x: (layout.tiles[0].frame.maxX + layout.tiles[1].frame.minX) / 2,
                              y: layout.tiles[0].frame.midY)
            for point in [gap, CGPoint(x: 1, y: 1), CGPoint(x: layout.panelSize.width / 2, y: layout.panelSize.height - 1)] +
                layout.headers.map({ CGPoint(x: $0.frame.midX, y: $0.frame.midY) }) {
                XCTAssertNil(session.tileHitTest(at: point), "\(presentation): \(point)")
                session.hoverTile(at: point, pointerLocation: CGPoint(x: 11000, y: 11000))
                XCTAssertEqual(session.selectedId, selected)
            }
        }
    }

    func testSelectedScaledTileWinsItsOverlapWithANeighbour() {
        for presentation in ["strip", "grid"] {
            for aspect: CGFloat in [3.5, 4] {
                var settings = LensConfig(); settings.presentation = presentation; settings.grid.tileSize = "real"
                let entries = items(2, wide: true).map { item in
                    var item = item
                    item.tile.aspect = aspect
                    let width: CGFloat = presentation == "grid" ? 2500 : 3500
                    item.tile.realSize = CGSize(width: width, height: width / aspect)
                    return item
                }
                let session = LensSession(name: "overlap", settings: settings, items: entries, search: "")
                session.miniatureSize = CGSize(width: 1920, height: 1080)
                session.send(.selectionChanged(0))
                let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
                let frame = layout.tiles[0].frame
                let lift = TileMetrics(scale: layout.tileScale).selectionScale
                let overlap = frame.insetBy(dx: -frame.width * (lift - 1) / 2, dy: -frame.height * (lift - 1) / 2)
                    .intersection(layout.tiles[1].frame)
                XCTAssertFalse(overlap.isNull, presentation)
                let point = CGPoint(x: overlap.midX, y: overlap.midY)
                session.hoverTile(at: point, pointerLocation: CGPoint(x: 10000, y: 10000))
                XCTAssertEqual(session.selectedId, 1, "\(presentation), aspect=\(aspect)")
                session.send(.selectionChanged(1))
                session.hoverTile(at: CGPoint(x: frame.midX, y: frame.midY), pointerLocation: CGPoint(x: 11000, y: 11000))
                XCTAssertEqual(session.selectedId, 1, presentation)
            }
        }
    }

    func testClickSelectsTheHitTileBeforeRunningItsKeyAndGapDoesNothing() throws {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "click", settings: settings, items: items(), search: "")
            let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
                                                       timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
            var targets: [UInt32] = []
            session.onAction = { targets += session.targets(for: $0) }
            let frame = layout.tiles[3].frame
            session.clickTile(at: CGPoint(x: frame.midX, y: frame.midY), event: event)
            XCTAssertEqual(targets, [4], presentation)
            session.clickTile(at: CGPoint(x: 1, y: 1), event: event)
            XCTAssertEqual(targets, [4])
        }
    }

    func testLastPointerOrTabInputIsTheReleaseTarget() {
        for presentation in ["strip", "grid"] {
            for pointerLast in [false, true] {
                var settings = LensConfig(); settings.presentation = presentation
                let session = LensSession(name: "release", settings: settings, items: items(), search: "")
                let owner = testLensLifecycle(); defer { owner.dismiss() }
                let gesture = StripGesture(keyCode: 48, invoking: .command)
                let ticket = owner.begin(session.name, toggle: false, strip: presentation == "strip" ? gesture : nil,
                                         invocation: gesture, settings: settings)!
                var targets: [UInt32] = []
                session.onAction = { targets += session.targets(for: $0) }
                owner.complete(session, ticket: ticket)
                let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
                let frame = layout.tiles[0].frame
                if pointerLast { session.perform(.step(1)) }
                session.hoverTile(at: CGPoint(x: frame.midX, y: frame.midY), pointerLocation: CGPoint(x: 10000, y: 10000))
                if !pointerLast { session.perform(.step(1)) }
                owner.stripFlagsChanged([], from: session)
                if presentation == "grid" {
                    // A grid stays open on release; Return commits the last input.
                    XCTAssertEqual(targets, [], "grid, pointerLast=\(pointerLast)")
                    XCTAssertTrue(owner.session === session)
                    session.onAction?("enter")
                }
                XCTAssertEqual(targets, [pointerLast ? 1 : 2], "\(presentation), pointerLast=\(pointerLast)")
            }
        }
    }

    func testLineWheelStepsStripWithWrappingAndGridWithBounds() {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "wheel", settings: settings, items: items(), search: "")
            var paging = LensScrollStepper()
            for time in [0.0, 0.01, 0.02] {
                session.scrollTiles(delta: -1, phase: [], momentum: [], time: time, precise: false, paging: &paging)
            }
            XCTAssertEqual(session.selectedId, presentation == "strip" ? 1 : 4)
            session.scrollTiles(delta: 1, phase: [], momentum: [], time: 0.03, precise: false, paging: &paging)
            XCTAssertEqual(session.selectedId, presentation == "strip" ? 4 : 3)
        }
    }
    func testTrackpadThresholdMomentumAndKeyboardReanchoringThroughSession() {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            var pointer = CGPoint.zero
            let session = LensSession(name: "trackpad", settings: settings, items: items(), search: "", pointerLocation: { pointer })
            pointer.x = 2
            session.hover(1, at: pointer)
            var paging = LensScrollStepper()
            session.scrollTiles(delta: -2, phase: .began, momentum: [], time: 0, precise: true, paging: &paging)
            XCTAssertEqual(session.selectedId, 1)
            session.scrollTiles(delta: -2, phase: .changed, momentum: [], time: 0.01, precise: true, paging: &paging)
            XCTAssertEqual(session.selectedId, 2)
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 2, "Scroll re-arms the still pointer")
            session.scrollTiles(delta: -20, phase: .changed, momentum: [], time: 0.02, precise: true, paging: &paging)
            session.scrollTiles(delta: -20, phase: [], momentum: .changed, time: 0.03, precise: true, paging: &paging)
            XCTAssertEqual(session.selectedId, 2)
            pointer.x += 1
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 2)
            pointer.x += 0.1
            session.hover(3, at: pointer)
            XCTAssertEqual(session.selectedId, 3)
            session.scrollTiles(delta: 4, phase: .began, momentum: [], time: 1, precise: true, paging: &paging)
            XCTAssertEqual(session.selectedId, 2)
        }
    }

    func testSearchReselectionAndInlineResultRearmMovingPointer() {
        var pointer = CGPoint.zero
        let session = LensSession(name: "search", settings: LensConfig(), items: items(), search: "", pointerLocation: { pointer })
        pointer.x = 2
        session.hover(4, at: pointer)
        session.send(.searchChanged("Window 2"))
        XCTAssertEqual(session.selectedId, 2)
        session.send(.searchChanged(""))
        session.hover(4, at: pointer)
        XCTAssertEqual(session.selectedId, 1)
        pointer.x += 2
        session.hover(4, at: pointer)
        XCTAssertEqual(session.selectedId, 4)
        session.send(.searchChanged("= true"))
        pointer.x += 2
        session.hover(4, at: pointer)
        session.acceptInlineResult([1, 2])
        session.hover(1, at: pointer)
        XCTAssertEqual(session.selectedId, 2)
    }

    func testGridReleaseWhileOpeningLeavesTheGridOpen() {
        let owner = testLensLifecycle(); defer { owner.dismiss() }
        var settings = LensConfig(); settings.presentation = "grid"
        let gesture = StripGesture(keyCode: 48, invoking: .command)
        let ticket = owner.begin("early", toggle: false, invocation: gesture, settings: settings)!
        owner.openingFlagsChanged([])
        let session = LensSession(name: "early", settings: settings, items: items(), search: "")
        var targets: [UInt32] = []
        session.onAction = { targets += session.targets(for: $0) }
        owner.complete(session, ticket: ticket)
        XCTAssertEqual(targets, [])
        XCTAssertTrue(owner.session === session)
    }

    func testHeldGridClickSubtractsTriggerModifiersAndRunsFocus() throws {
        var settings = LensConfig(); settings.presentation = "grid"
        let session = LensSession(name: "click-hold", settings: settings, items: items(), search: "")
        session.startHold(StripGesture(keyCode: 48, invoking: .command))
        let frame = session.gridLayout.tiles[3].frame
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: .command,
                                                   timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        var keys: [String] = []
        session.onAction = { keys.append($0) }
        session.clickTile(at: CGPoint(x: frame.midX, y: frame.midY), event: event)
        let shifted = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [.command, .shift],
                                                     timestamp: 1, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        session.clickTile(at: CGPoint(x: frame.midX, y: frame.midY), event: shifted)
        XCTAssertEqual(session.selectedId, 4)
        XCTAssertEqual(keys, ["enter", "shift-enter"])
    }

    func testMiniaturePageTurnReanchorsEvenWhenItsSelectionDoesNotChange() {
        setUpWorkspacesForTests()
        var settings = LensConfig(); settings.presentation = "miniatures"; settings.miniatures.fit = "page"
        var pointer = CGPoint.zero
        let workspace = Workspace.get(byName: "1")
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let entries = [SwitcherPaletteItem(id: 1, title: "Window", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
            miniature: MiniatureWindow(workspace: "1", frame: CGRect(x: 0, y: 0, width: 500, height: 300), tray: false,
                                       frozen: false, accessory: false, floating: false, window: window))] + items().dropFirst()
        let session = LensSession(name: "page", settings: settings, items: entries, search: "", pointerLocation: { pointer })
        session.miniatureWorkspaces = (1...50).map { MiniatureWorkspace(name: String($0), title: String($0), source: CGRect(x: 0, y: 0, width: 1000, height: 600), current: $0 == 1) }
        session.miniatureSize = CGSize(width: 800, height: 600)
        pointer.x = 2
        session.hover(1, at: pointer)
        session.turnMiniaturePage(1)
        XCTAssertEqual(session.miniaturePage, 1)
        pointer.x += 0.5
        session.hover(3, at: pointer)
        XCTAssertEqual(session.selectedId, 1)
        pointer.x += 0.6
        session.hover(3, at: pointer)
        XCTAssertEqual(session.selectedId, 3)
    }

    func testTileStillUnderPointerAfterKeyStepCannotReplaceSelection() {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            var pointer = CGPoint.zero
            let session = LensSession(name: "sliding", settings: settings, items: items(), search: "", pointerLocation: { pointer })
            let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
            let frame = layout.tiles[0].frame
            let point = CGPoint(x: frame.midX, y: frame.midY)
            pointer = point
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertEqual(session.selectedId, 1)
            session.perform(.step(1))
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertEqual(session.selectedId, 2, "Selection redraw under a still pointer is not pointer input")
            pointer.x += 1
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertEqual(session.selectedId, 2)
            pointer.x += 0.1
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertEqual(session.selectedId, 1)
        }
    }

    func testSearchReselectingSameWindowStillReanchors() {
        var pointer = CGPoint.zero
        let session = LensSession(name: "same-search", settings: LensConfig(), items: items(), search: "", pointerLocation: { pointer })
        pointer.x = 2
        session.hover(1, at: pointer)
        session.send(.searchChanged("Window"))
        XCTAssertEqual(session.selectedId, 1)
        pointer.x += 0.5
        session.hover(3, at: pointer)
        XCTAssertEqual(session.selectedId, 1)
    }

    func testNonTileMovementCannotSelectATileThatSlidesUnderStillPointer() {
        var pointer = CGPoint.zero
        let session = LensSession(name: "gap", settings: LensConfig(), items: items(), search: "", pointerLocation: { pointer })
        pointer.x = 2
        session.hover(1, at: pointer)
        pointer.x = 100
        session.hover(nil, at: pointer)
        XCTAssertEqual(session.selectedId, 1)
        session.hover(3, at: pointer)
        XCTAssertEqual(session.selectedId, 1)
    }

    func testArrowAtGridOrMiniatureEdgeReanchorsPointer() {
        for presentation in ["grid", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            var pointer = CGPoint.zero
            let session = LensSession(name: "edge", settings: settings, items: items(), search: "", pointerLocation: { pointer })
            pointer.x = 2
            session.hover(4, at: pointer)
            session.perform(.arrow(124))
            XCTAssertEqual(session.selectedId, 4)
            pointer.x += 0.5
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 4)
        }
    }

    func testFirstPresentationReanchorsAfterDisplayDelayButRedisplayDoesNot() {
        for presentation in ["strip", "grid", "list", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            var pointer = CGPoint.zero
            let session = LensSession(name: "delay", settings: settings, items: items(), search: "", pointerLocation: { pointer })
            let owner = testLensLifecycle(); defer { owner.dismiss() }
            let ticket = owner.begin(session.name, toggle: false, settings: settings)!
            pointer = CGPoint(x: 10000, y: 10000)
            owner.complete(session, ticket: ticket)
            let initial = session.selectedId
            session.hover(4, at: pointer)
            XCTAssertEqual(session.selectedId, initial, presentation)
            pointer.x += 1
            session.hover(4, at: pointer)
            XCTAssertEqual(session.selectedId, initial, presentation)
            pointer.x += 0.1
            session.hover(4, at: pointer)
            XCTAssertEqual(session.selectedId, 4, presentation)
            owner.presented(session)
            pointer.x += 0.1
            session.hover(1, at: pointer)
            XCTAssertEqual(session.selectedId, 1, "Redisplay must not reanchor an armed pointer")
        }
    }

    func testStripShownAfterItsDisplayDelayReanchorsAPointerThatMovedDuringTheDelay() async throws {
        let clock = TestClock<Duration>()
        var pointer = CGPoint.zero
        var settings = LensConfig(); settings.presentation = "strip"
        let owner = testLensLifecycle(clock: clock); defer { owner.dismiss() }
        let ticket = owner.begin("delay", toggle: false, strip: StripGesture(keyCode: 48, invoking: .command, clock: clock), settings: settings)!
        let session = LensSession(name: "delay", settings: settings, items: items(), search: "", pointerLocation: { pointer })
        owner.complete(session, ticket: ticket)
        guard case .ready = owner.state else { return XCTFail("Expected the strip to wait for its display delay") }
        pointer = CGPoint(x: 50, y: 0)
        await clock.advance(by: .milliseconds(100))
        guard case .presented = owner.state else { return XCTFail("Expected the strip to be shown") }
        let initial = session.selectedId
        session.hover(4, at: pointer)
        XCTAssertEqual(session.selectedId, initial, "A pointer resting where it stopped during the delay selects nothing")
        pointer.x += 2
        session.hover(4, at: pointer)
        XCTAssertEqual(session.selectedId, 4)
    }

    func testHeldListAndMiniatureClicksSubtractInvokingModifiers() throws {
        for presentation in ["list", "miniatures"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "held-click", settings: settings, items: items(), search: "")
            session.startHold(StripGesture(keyCode: 48, invoking: .command))
            for (flags, expected): (NSEvent.ModifierFlags, String) in [(.command, "enter"), ([.command, .shift], "shift-enter")] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: flags,
                    timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
                session.hover(4)
                XCTAssertEqual(session.key(for: event, click: true), expected, presentation)
                session.updateSummonModifiers(flags)
                XCTAssertEqual(session.summonHeld, flags.contains(.shift), presentation)
                XCTAssertEqual(session.targets(for: expected), [4])
            }
        }
    }

    func testWindowPointConvertsToTilesAndOutsideDoesNothingAfterLayoutMoves() throws {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "coordinates", settings: settings, items: items(), search: "", pointerLocation: { .zero })
            let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
            let tile = layout.tiles[3].frame
            for origin in [CGPoint(x: 100, y: 200), CGPoint(x: 210, y: 80)] {
                let frame = CGRect(origin: origin, size: layout.panelSize)
                let content = CGPoint(x: origin.x + tile.midX, y: origin.y + tile.midY)
                let point = try XCTUnwrap(lensTilePoint(content, in: frame))
                session.hoverTile(at: point, pointerLocation: content)
                XCTAssertEqual(session.selection, 3)
                XCTAssertNil(lensTilePoint(CGPoint(x: frame.minX - 1, y: frame.midY), in: frame))
                XCTAssertNil(lensTilePoint(CGPoint(x: frame.midX, y: frame.maxY + 1), in: frame))
            }
        }
    }

    func testSharedPointerThresholdIsStrictEuclideanDistance() {
        let anchor = CGPoint(x: 100, y: 200)
        XCTAssertFalse(pointerMovedBeyondThreshold(from: anchor, to: anchor))
        XCTAssertFalse(pointerMovedBeyondThreshold(from: anchor, to: CGPoint(x: 101, y: 200)))
        XCTAssertFalse(pointerMovedBeyondThreshold(from: .zero, to: CGPoint(x: 0.6, y: 0.8)))
        XCTAssertTrue(pointerMovedBeyondThreshold(from: anchor, to: CGPoint(x: 100.8, y: 200.8)))
        XCTAssertTrue(pointerMovedBeyondThreshold(from: anchor, to: CGPoint(x: 101.01, y: 200)))
    }

    func testTileHitTestUsesDrawnChromeInsetsAtEveryPanelScale() {
        for presentation in ["strip", "grid"] {
            var settings = LensConfig(); settings.presentation = presentation
            let session = LensSession(name: "insets", settings: settings, items: items(), search: "")
            for size in [CGSize(width: 800, height: 600), CGSize(width: 1920, height: 1080)] {
                session.miniatureSize = size
                let layout = presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
                let scale = session.tileMetrics.scale
                let sizing = presentation == "strip" ? GridLayout.Sizing.strip : .grid
                let tile = layout.tiles[session.selection].frame
                let x = tile.midX
                let footerTop = layout.panelSize.height - sizing.pointerBottomInset * scale
                XCTAssertNil(session.tileHitTest(at: CGPoint(x: x, y: footerTop)))
                XCTAssertNil(session.tileHitTest(at: CGPoint(x: x, y: layout.panelSize.height - 1)))
                if sizing.pointerTopInset > 0 {
                    XCTAssertNil(session.tileHitTest(at: CGPoint(x: x, y: sizing.pointerTopInset * scale - 0.1)))
                }
                XCTAssertEqual(session.tileHitTest(at: CGPoint(x: x, y: tile.midY))?.index, session.selection)
            }
        }
    }

}
