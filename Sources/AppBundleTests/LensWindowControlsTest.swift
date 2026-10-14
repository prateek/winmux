@testable import AppBundle
import AppKit
import Combine
import XCTest

@MainActor
final class LensWindowControlsTest: XCTestCase {
    private func session(_ presentation: String, kind: String = "picture", narrow: Bool = false, availability: TileControlAvailability = .all, pointer: @escaping () -> CGPoint = { .zero }) -> LensSession {
        var settings = LensConfig(); settings.presentation = presentation; settings.tile = kind; settings.sections = "none"
        let items: [SwitcherPaletteItem] = (1...4).map { id in
            let aspect: CGFloat = narrow && id == 1 ? 0.02 : 4 / 3
            let size = narrow && id == 1 ? CGSize(width: 20, height: 1000) : CGSize(width: 800, height: 600)
            let entry = TileEntry(title: "Window \(id)", appName: "Demo", aspect: aspect, realSize: size, controls: availability)
            return SwitcherPaletteItem(id: UInt32(id), title: "Window \(id)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                tile: entry)
        }
        let session = LensSession(name: "controls", settings: settings, items: items, search: "", pointerLocation: pointer)
        session.miniatureSize = CGSize(width: 1920, height: 1080)
        return session
    }
    private func layout(_ session: LensSession) -> GridLayout {
        session.settings.presentation == "strip" ? session.stripSnapshot.layout : session.gridLayout
    }
    private func centre(_ rect: CGRect) -> CGPoint { CGPoint(x: rect.midX, y: rect.midY) }

    func testExistingHitTestsAndPictureClicksStillSelectAndCommitWithControlsOff() throws {
        for presentation in ["strip", "grid"] {
            let session = session(presentation)
            let layout = layout(session)
            for (index, tile) in layout.tiles.enumerated() {
                XCTAssertEqual(session.tileHitTest(at: centre(tile.frame))?.index, index)
                XCTAssertNil(session.tileHitTest(at: centre(tile.frame))?.control)
            }
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
            var committed: [UInt32] = []
            session.onAction = { committed += session.targets(for: $0) }
            session.clickTile(at: centre(layout.tiles[3].frame), event: event)
            XCTAssertEqual(committed, [4])
            XCTAssertEqual(session.selectedId, 4)
        }
    }

    func testControlHitTestingUsesPictureGeometryAndSelectedScaleInStripAndGrid() throws {
        for presentation in ["strip", "grid"] {
            for kind in ["picture", "card"] {
                let session = session(presentation, kind: kind)
                let layout = layout(session)
                for index in [0, 2] {
                    let frame = layout.tiles[index].frame
                    session.hoverTile(at: centre(frame), pointerLocation: CGPoint(x: 100 + index * 10, y: 100))
                    session.send(.selectionChanged(0))
                    let rectangles = session.controlRects(index: index, layout: layout)
                    XCTAssertEqual(rectangles.count, 3)
                    for (control, rect) in rectangles {
                        let hit = try XCTUnwrap(session.tileHitTest(at: centre(rect)))
                        XCTAssertEqual(hit.index, index)
                        XCTAssertEqual(hit.control, control)
                    }
                    XCTAssertNil(session.tileHitTest(at: centre(frame))?.control)
                }
            }
        }
        for presentation in ["strip", "grid"] {
            let narrow = session(presentation, narrow: true)
            let layout = layout(narrow)
            narrow.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: CGPoint(x: 2, y: 0))
            XCTAssertEqual(narrow.controlRects(index: 0, layout: layout).count, 0)
            XCTAssertNil(narrow.tileHitTest(at: centre(layout.tiles[0].frame))?.control)
        }
        let prototypeSlots = tileControlRects(in: CGRect(x: 100, y: 200, width: 192, height: 108), scale: 1)
        XCTAssertEqual(prototypeSlots.map { $0.1 }, [CGRect(x: 108, y: 208, width: 16, height: 16),
                                                   CGRect(x: 130, y: 208, width: 16, height: 16),
                                                   CGRect(x: 152, y: 208, width: 16, height: 16)])
        let entry = TileEntry(title: "Card", appName: "Demo", aspect: 4 / 3)
        XCTAssertEqual(tilePictureRect(entry: entry, kind: .card, size: CGSize(width: 420, height: 356), pictureSize: nil,
                                       metrics: TileMetrics(scale: 1), presentation: "grid", selected: false),
                       CGRect(x: 10, y: 46, width: 400, height: 300))
        XCTAssertEqual(tileControlRects(in: CGRect(x: 0, y: 0, width: 45, height: 30), scale: 1).count, 0)
        XCTAssertEqual(tileControlRects(in: CGRect(x: 0, y: 0, width: 100, height: 30), scale: 0.5).count, 0)
        for presentation in ["strip", "grid"] {
            let small = session(presentation)
            small.miniatureSize = CGSize(width: 800, height: 600)
            XCTAssertEqual(small.controlRects(index: 0, layout: layout(small)).count, 0)
        }
        let shrunk = tileControlRects(in: CGRect(x: 0, y: 0, width: 60, height: 30), scale: 1)
        XCTAssertEqual(shrunk.count, 3)
        XCTAssertLessThan(shrunk[0].1.width, 16)
    }

    func testHoverIsIndependentOfSelectionClearsOffTilesAndNeedsOneMovementCall() {
        for presentation in ["strip", "grid"] {
            var pointer = CGPoint.zero
            let session = session(presentation, pointer: { pointer })
            let layout = layout(session)
            let point = centre(layout.tiles[2].frame)
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertNil(session.hoveredTileId)
            pointer.x = 1
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertNil(session.hoveredTileId)
            pointer.x = 1.1
            session.hoverTile(at: point, pointerLocation: pointer)
            XCTAssertEqual(session.hoveredTileId, 3)
            XCTAssertEqual(session.selectedId, 3)
            session.moveSelection(1)
            XCTAssertEqual(session.hoveredTileId, 3)
            pointer.x += 2
            session.hoverTile(at: nil, pointerLocation: pointer)
            XCTAssertNil(session.hoveredTileId)
            XCTAssertEqual(session.selectedId, 4)
            pointer.x += 2
            session.hoverTile(at: point, pointerLocation: pointer)
            session.send(.itemsRemoved([3]))
            XCTAssertNil(session.hoveredTileId)
            pointer.x += 2
            session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
            session.send(.searchChanged("Window 4"))
            XCTAssertNil(session.hoveredTileId)
            session.send(.searchChanged(""))
            pointer.x += 2
            session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
            session.send(.searchChanged("= true"))
            session.acceptInlineResult([4])
            XCTAssertNil(session.hoveredTileId)
            session.send(.searchChanged(""))
            pointer.x += 2
            session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
            session.changePresentation("list")
            XCTAssertNil(session.hoveredTileId)
        }
    }

    func testMovesWithinTheHoveredTileDoNotRedrawThePanel() {
        for presentation in ["strip", "grid"] {
            var pointer = CGPoint.zero
            let session = session(presentation, pointer: { pointer })
            let frame = layout(session).tiles[2].frame
            pointer.x = 2
            session.hoverTile(at: centre(frame), pointerLocation: pointer)
            XCTAssertEqual(session.hoveredTileId, 3)
            var changes = 0
            let subscription = session.objectWillChange.sink { changes += 1 }
            for step in 1...5 {
                pointer.x += 2
                session.hoverTile(at: CGPoint(x: frame.midX + CGFloat(step), y: frame.midY), pointerLocation: pointer)
            }
            XCTAssertEqual(changes, 0)
            subscription.cancel()
        }
    }

    func testControlsBypassSelectionMarksModifiersAndClickKeyAndRemainOpenAfterAction() throws {
        for presentation in ["strip", "grid"] {
            for control in TileWindowControl.allCases {
                var pointer = CGPoint.zero
                let session = session(presentation, pointer: { pointer })
                let owner = testLensLifecycle(); defer { owner.dismiss() }
                let gesture = StripGesture(keyCode: 48, invoking: .command)
                let ticket = owner.begin(session.name, toggle: false, invocation: gesture, settings: session.settings)!
                owner.complete(session, ticket: ticket)
                let layout = layout(session)
                pointer.x = 2
                session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
                session.moveSelection(1)
                session.toggleMark()
                var acted: [(TileWindowControl, UInt32)] = []
                session.onControl = { acted.append(($0, $1)) }
                session.onAction = { _ in XCTFail("A control must not run the click key") }
                let rect = try XCTUnwrap(session.controlRects(index: 0, layout: layout).first { $0.0 == control }?.1)
                let event = NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0)
                session.clickTile(at: centre(rect), event: event)
                XCTAssertEqual(acted.map { $0.0 }, [control])
                XCTAssertEqual(acted.map { $0.1 }, [1])
                XCTAssertEqual(session.selectedId, 2)
                XCTAssertTrue(owner.session === session)
                XCTAssertNil(session.hoveredTileId)
                session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
                XCTAssertNil(session.hoveredTileId)
                pointer.x += 1
                session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
                XCTAssertNil(session.hoveredTileId)
                pointer.x += 0.1
                session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: pointer)
                XCTAssertEqual(session.hoveredTileId, 1)
                if control == .fullscreen {
                    session.refreshTile(windowId: 1, windowClass: .fullscreen,
                                        controls: TileControlAvailability(buttons: .all, windowClass: .fullscreen))
                    XCTAssertFalse(session.results[0].tile.controls.minimize)
                    XCTAssertFalse(session.results[0].tile.badges.minimized)
                }
                if control == .minimize {
                    session.refreshTile(windowId: 1, windowClass: .minimized,
                                        controls: TileControlAvailability(buttons: .all, windowClass: .minimized))
                    XCTAssertTrue(session.results[0].tile.badges.minimized)
                    XCTAssertTrue(session.results[0].tile.frozen)
                    XCTAssertFalse(session.results[0].tile.controls.minimize)
                    XCTAssertTrue(session.results[0].tile.controls.fullscreen)
                }
            }
        }
    }

    func testHiddenControlsKeepTheirSlotsAndTextListMiniaturesNeverHitControls() {
        XCTAssertFalse(TileControlAvailability(close: false, minimize: true, fullscreen: true).allows(.close))
        for presentation in ["strip", "grid"] {
            let full = session(presentation)
            let hidden = session(presentation, availability: TileControlAvailability(close: false, minimize: true, fullscreen: true))
            let layout = layout(hidden)
            let slots = full.controlRects(index: 0, layout: layout)
            let remaining = hidden.controlRects(index: 0, layout: layout)
            XCTAssertEqual(remaining.map { $0.0 }, [.minimize, .fullscreen])
            XCTAssertEqual(remaining.map { $0.1 }, Array(slots.dropFirst()).map { $0.1 })
        }
        for presentation in ["list", "miniatures"] { XCTAssertNil(session(presentation).tileHitTest(at: .zero)) }
        for presentation in ["strip", "grid"] {
            let session = session(presentation, kind: "text")
            let layout = layout(session)
            session.hoverTile(at: centre(layout.tiles[0].frame), pointerLocation: CGPoint(x: 2, y: 0))
            XCTAssertEqual(session.controlRects(index: 0, layout: layout).count, 0)
        }
    }
}
