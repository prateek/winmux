@testable import AppBundle
import AppKit
import XCTest

final class MiniatureRegressionTest: XCTestCase {
    func testOnePagePerTrackpadGestureIncludingMomentumAndSlowStart() {
        var paging = MiniatureScrollPaging()
        XCTAssertNil(paging.turn(delta: -0.2, phase: .began, momentum: [], time: 0))
        XCTAssertNil(paging.turn(delta: -2, phase: .changed, momentum: [], time: 0.01))
        XCTAssertEqual(paging.turn(delta: -2, phase: .changed, momentum: [], time: 0.02), 1)
        XCTAssertNil(paging.turn(delta: -12, phase: .changed, momentum: [], time: 0.03))
        XCTAssertNil(paging.turn(delta: 0, phase: .ended, momentum: [], time: 0.04))
        XCTAssertNil(paging.turn(delta: -12, phase: [], momentum: .began, time: 0.05))
        XCTAssertNil(paging.turn(delta: -12, phase: [], momentum: .changed, time: 0.06))
        XCTAssertEqual(paging.turn(delta: 5, phase: .began, momentum: [], time: 1), -1)
    }

    func testSidewaysSwipeWithVerticalJitterTurnsNoPage() {
        var paging = MiniatureScrollPaging()
        XCTAssertNil(paging.turn(delta: -2, sideways: 30, phase: .began, momentum: [], time: 0))
        XCTAssertNil(paging.turn(delta: -3, sideways: 40, phase: .changed, momentum: [], time: 0.01))
    }

    func testOnePagePerBurstOfWheelEvents() {
        var paging = MiniatureScrollPaging()
        XCTAssertEqual(paging.turn(delta: -1, phase: [], momentum: [], time: 10), 1)
        XCTAssertNil(paging.turn(delta: -0.4, phase: [], momentum: [], time: 10.05))
        XCTAssertNil(paging.turn(delta: -0.4, phase: [], momentum: [], time: 10.2))
        XCTAssertEqual(paging.turn(delta: -1, phase: [], momentum: [], time: 10.5), 1)
        XCTAssertEqual(paging.turn(delta: 1, phase: [], momentum: [], time: 11), -1)
    }

    func testFloatingWindowsAreCapturedAtTheirOwnShapeNotTheirLastTile() {
        let tile = CGRect(x: 0, y: 0, width: 1800, height: 1000), actual = CGRect(x: 40, y: 40, width: 600, height: 900)
        XCTAssertEqual(ThumbnailCache.captureFrame(floating: true, layout: tile, parked: nil, actual: actual), actual)
        XCTAssertEqual(ThumbnailCache.captureFrame(floating: false, layout: tile, parked: actual, actual: actual), tile)
        XCTAssertEqual(ThumbnailCache.captureFrame(floating: true, layout: tile, parked: actual, actual: nil), actual)
    }

    func testQueuedParkRequestKeepsItsPlaceAndAMinimizeRequestGoesFirst() {
        var gate = ThumbnailCaptureGate()
        gate.enqueue(8, now: 0); gate.enqueue(9, now: 0)
        XCTAssertEqual(gate.start(now: 0), [8, 9])
        gate.enqueue(1, now: 0); gate.enqueue(2, now: 0); gate.enqueue(3, now: 0)
        gate.enqueue(1, now: 0)
        gate.enqueue(3, now: 0, force: true)
        gate.finish(8); gate.finish(9)
        XCTAssertEqual(gate.start(now: 0), [3, 1])
    }

    func testVisibleWorkspaceOnOtherDisplayIsLive() {
        XCTAssertFalse(miniatureIsFrozen(tray: false, fullscreen: false, workspaceVisible: true, parked: false))
        XCTAssertTrue(miniatureIsFrozen(tray: false, fullscreen: false, workspaceVisible: false, parked: false))
        XCTAssertTrue(miniatureIsFrozen(tray: false, fullscreen: true, workspaceVisible: false, parked: false))
        XCTAssertTrue(miniatureIsFrozen(tray: true, fullscreen: false, workspaceVisible: true, parked: false))
    }

    @MainActor
    func testRetainedOriginsStayDistinctFromRenumberedSidebarWorkspaces() async throws {
        let source = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let current = MiniatureWorkspace(name: "3", title: "Workspace 1", source: source, current: true)
        let previous = MiniatureWorkspace(name: "1", title: "Workspace 1", source: source, current: false)
        let snapshots = appendingRetainedMiniatureWorkspaces([current], retained: [previous, previous, current])
        XCTAssertEqual(snapshots.map(\.name), ["3", "1"])
        XCTAssertEqual(snapshots.map(\.title), ["Workspace 1", "Previous Workspace 1"])
        XCTAssertTrue(snapshots[0].current)
        XCTAssertFalse(snapshots[1].current)

        setUpWorkspacesForTests()
        let oldWorkspace = Workspace.get(byName: "1")
        let currentWorkspace = Workspace.get(byName: "2")
        config.workspaceSidebar.workspaceLabels = ["1": "Workspace 1", "2": "Workspace 1"]
        let hidden = TestWindow.new(id: 1, parent: MacosHiddenAppsWindowsContainer(parent: oldWorkspace))
        let focused = TestWindow.new(id: 2, parent: currentWorkspace.rootTilingContainer)
        _ = focused.focusWindow()
        let maybeRecord = try await hidden.windowRecord()
        let record = try XCTUnwrap(maybeRecord)
        let entry = LensWindow(record: record, window: hidden, spatialIndex: 0, workspaceIndex: 0)
        let actual = miniatureWorkspaceSnapshot([entry])
        XCTAssertEqual(actual.map(\.name), [currentWorkspace.name, oldWorkspace.name])
        XCTAssertEqual(actual.map(\.title), ["Workspace 1", "Previous Workspace 1"])
    }

    func testFloatingLandingUsesDestinationDisplayAndClamps() {
        let source = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let destination = CGRect(x: 0, y: 24, width: 1000, height: 700)
        let frame = CGRect(x: 2880, y: 540, width: 600, height: 400)
        XCTAssertEqual(miniatureFloatingLanding(frame, from: source, to: destination), CGRect(x: 400, y: 324, width: 600, height: 400))
    }
}

@MainActor
final class MiniatureSelectionRegressionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    func testSearchFocusFindsEditableFieldThroughHostingContainers() {
        let root = NSView(); let content = NSView(); root.addSubview(content)
        content.addSubview(NSTextField(labelWithString: "Overview"))
        let search = NSTextField(); content.addSubview(search)
        XCTAssertTrue(lensSearchField(in: root) === search)
    }

    func testOpensOnPreviousWindowAndItsPageAndListConversionKeepsTheSessionOrder() {
        let windows = (1...30).map { TestWindow.new(id: UInt32($0), parent: Workspace.get(byName: String($0)).rootTilingContainer) }
        let items = windows.enumerated().map { index, window in
            SwitcherPaletteItem(id: window.windowId, title: String(format: "%02d", index), appName: "Demo", icon: nil, workspaceName: String(index + 1), lastFocusedSeq: index, isFocused: index == 29,
              miniature: MiniatureWindow(workspace: String(index + 1), frame: CGRect(x: 0, y: 0, width: 500, height: 500), tray: false, frozen: false, accessory: false, floating: false, window: window))
        }
        var settings = LensConfig(); settings.presentation = "miniatures"; settings.sort = ["title"]; settings.sections = "none"
        let model = LensSession(name: "demo", settings: settings, items: items, search: "")
        model.miniatureWorkspaces = windows.enumerated().map { MiniatureWorkspace(name: String($0.offset + 1), title: "Demo", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: $0.offset == 29) }
        model.revealMiniatureSelection()
        XCTAssertEqual(model.selectedId, 29)
        XCTAssertEqual(model.miniaturePage, model.miniatureLayout.page(for: "29"))
        model.changePresentation("list")
        XCTAssertEqual(model.results.map(\.id), Array(1...30).map(UInt32.init))
        XCTAssertEqual(model.selectedId, 29)
    }

    func testHidingTheCurrentWorkspaceStillOpensOnThePreviousWindow() {
        // Sort order is MRU: the focused window, then the previous one, then an older one.
        let items = [(1, 30, true), (2, 20, false), (3, 10, false)].map { id, seq, focused in
            let window = TestWindow.new(id: UInt32(id), parent: Workspace.get(byName: String(id)).rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "w\(id)", appName: "Demo", icon: nil, workspaceName: String(id), lastFocusedSeq: seq, isFocused: focused,
              miniature: MiniatureWindow(workspace: String(id), frame: CGRect(x: 0, y: 0, width: 500, height: 500), tray: false, frozen: false, accessory: false, floating: false, window: window))
        }
        var settings = LensConfig(); settings.presentation = "miniatures"; settings.miniatures.currentWorkspace = "hide"
        let model = LensSession(name: "demo", settings: settings, items: items, search: "")
        XCTAssertEqual(model.selectedId, 2)
        model.send(.excludedChanged([1]))
        XCTAssertEqual(model.selectedId, 2)
    }

    func testByWorkspaceArrowsFollowPositionAndRecentFloatingWindowsDrawOnTop() {
        let workspace = Workspace.get(byName: "1")
        // Sort order is MRU, which is right to left here.
        let items = [(1, 500.0, true), (2, 0.0, true), (3, 250.0, false)].map { id, x, floating in
            let window = TestWindow.new(id: UInt32(id), parent: workspace.rootTilingContainer)
            return SwitcherPaletteItem(id: window.windowId, title: "w\(id)", appName: "Demo", icon: nil, workspaceName: "1", lastFocusedSeq: 10 - id, isFocused: false,
              miniature: MiniatureWindow(workspace: "1", frame: CGRect(x: x, y: 0, width: 250, height: 500), tray: false, frozen: false, accessory: false, floating: floating, window: window))
        }
        var settings = LensConfig(); settings.presentation = "miniatures"; settings.miniatures.arrowKeys = "by-workspace"
        let model = LensSession(name: "demo", settings: settings, items: items, search: "")
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "Demo", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: true)]
        model.hover(2)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 3)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 1)
        XCTAssertEqual(miniatureDrawOrder(items).map(\.id), [3, 2, 1])
    }
}
