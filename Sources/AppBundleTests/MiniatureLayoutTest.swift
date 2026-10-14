@testable import AppBundle
import AppKit
import XCTest

final class MiniatureLayoutTest: XCTestCase {
    func testScaleUsesWorkspaceOriginAndKeepsFloatingPosition() {
        let source = CGRect(x: 100, y: 200, width: 1000, height: 500)
        let target = CGRect(x: 20, y: 40, width: 200, height: 100)
        XCTAssertEqual(MiniatureLayout.scale(CGRect(x: 600, y: 250, width: 400, height: 200), from: source, to: target), CGRect(x: 120, y: 50, width: 80, height: 40))
    }

    func testPagesKeepSidebarOrderAtReadableFloorAndScrollClamps() {
        let layout = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: CGSize(width: 800, height: 600), aspect: 2, fit: "page")
        XCTAssertGreaterThan(layout.pageCount, 1)
        XCTAssertGreaterThanOrEqual(layout.workspaceHeight, 110)
        XCTAssertEqual(layout.cells(on: 0).map(\.workspace), Array((1 ... layout.capacity).map(String.init)))
        XCTAssertEqual(layout.cells(on: 1).first?.workspace, String(layout.capacity + 1))
        XCTAssertEqual(layout.turnedPage(0, delta: -1), 0)
        XCTAssertEqual(layout.turnedPage(0, delta: 1), 1)
        let shrink = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: CGSize(width: 800, height: 600), aspect: 2, fit: "shrink")
        XCTAssertEqual(shrink.pageCount, 1)
        XCTAssertEqual(shrink.cells(on: 0).count, 50)
        for cell in shrink.cells(on: 0) {
            XCTAssertLessThanOrEqual(cell.frame.maxX.rounded(), 800 - 24)
            XCTAssertLessThanOrEqual(cell.tray.maxY + 24, 600)
        }
    }

    func testPagedCellsKeepFullPageGeometryAtReadableFloor() {
        let layout = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: CGSize(width: 800, height: 600), aspect: 2, fit: "page")
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.capacity, 6)
        XCTAssertEqual(layout.workspaceHeight, 704.0 / 6, accuracy: 0.001)
        let first = layout.cells(on: 0)
        let last = layout.cells(on: layout.pageCount - 1)
        XCTAssertEqual(last.count, 2)
        for (a, b) in zip(first, last) {
            XCTAssertEqual(a.frame, b.frame)
            XCTAssertEqual(a.tray, b.tray)
        }
        XCTAssertEqual(layout.page(for: "50"), 8)
    }

    func testShrinkFiftyKeepsEveryWorkspaceAndTrayInsidePanel() {
        for size in [CGSize(width: 800, height: 600), CGSize(width: 200, height: 150)] {
            let layout = MiniatureLayout(workspaces: (1 ... 50).map(String.init), size: size, aspect: 2, fit: "shrink")
            XCTAssertEqual(layout.pageCount, 1)
            XCTAssertEqual(layout.cells(on: 0).map(\.workspace), (1 ... 50).map(String.init))
            for cell in layout.cells(on: 0) {
                XCTAssertGreaterThan(cell.frame.width, 0)
                XCTAssertGreaterThanOrEqual(cell.frame.minX, 24)
                XCTAssertLessThanOrEqual(cell.frame.maxX, size.width - 24 + 0.001)
                XCTAssertLessThanOrEqual(cell.tray.maxY, size.height - 24 + 0.001)
            }
        }
    }

    func testOneWorkspaceOnLargeMonitorFillsItsCell() {
        for fit in ["page", "shrink"] {
            let layout = MiniatureLayout(workspaces: ["1"], size: CGSize(width: 4000, height: 3000), aspect: 2, fit: fit)
            XCTAssertEqual(layout.columns, 1)
            XCTAssertEqual(layout.workspaceHeight, 1976)
            XCTAssertEqual(layout.cells(on: 0)[0].frame.width, 3952)
        }
    }

    func testArrangementTableUsesLargestWorkspacesInReadingOrderAndCentresRows() throws {
        for (size, aspect, expectedColumns) in [
            (CGSize(width: 1920, height: 1080), CGFloat(16.0 / 9), [1, 2, 2, 4]),
            (CGSize(width: 3440, height: 1440), CGFloat(43.0 / 18), [1, 2, 2, 3]),
        ] {
            for (count, columns) in zip([1, 2, 4, 7], expectedColumns) {
                for fit in ["page", "shrink"] {
                    let names = (1 ... count).map(String.init)
                    let layout = MiniatureLayout(workspaces: names, size: size, aspect: aspect, fit: fit)
                    let cells = layout.cells(on: 0)
                    let rows = (count + columns - 1) / columns
                    XCTAssertEqual(layout.columns, columns, "\(size), \(count), \(fit)")
                    XCTAssertEqual(layout.pageCount, 1)
                    XCTAssertEqual(cells.map(\.workspace), names)
                    XCTAssertEqual(Set(cells.map { $0.frame.minY }).count, rows)
                    let first = try XCTUnwrap(cells.first)
                    let right = cells.prefix(columns).map { $0.frame.maxX }.max()!
                    XCTAssertEqual((first.frame.minX + right) / 2, size.width / 2, accuracy: 0.001)
                    let last = try XCTUnwrap(cells.last)
                    XCTAssertEqual((first.frame.minY - 24 + last.frame.maxY + 60) / 2, (68 + size.height - 32) / 2, accuracy: 0.001)
                    for (index, cell) in cells.enumerated() {
                        XCTAssertGreaterThanOrEqual(cell.frame.minX, 24 - 0.001)
                        XCTAssertLessThanOrEqual(cell.frame.maxX, size.width - 24 + 0.001)
                        XCTAssertGreaterThanOrEqual(cell.frame.minY - 24, 68 - 0.001)
                        XCTAssertLessThanOrEqual(cell.tray.maxY + 28, size.height - 32 + 0.001)
                        XCTAssertEqual(cell.frame.width / cell.frame.height, aspect, accuracy: 0.001)
                        if index % columns == 0 { XCTAssertEqual(cell.frame.minX, first.frame.minX) }
                        else { XCTAssertGreaterThan(cell.frame.minX, cells[index - 1].frame.maxX) }
                        if index >= columns { XCTAssertGreaterThan(cell.frame.minY, cells[index - columns].frame.maxY) }
                    }
                }
            }
        }
    }

    func testEqualWorkspaceWidthsChooseFewerRows() {
        let layout = MiniatureLayout(workspaces: ["1", "2"], size: CGSize(width: 304, height: 500), aspect: 1, fit: "page")
        XCTAssertEqual(layout.columns, 2)
        XCTAssertEqual(layout.workspaceHeight, 116)
    }

    func testDirectionalMovementUsesGeometryAndOnlyMatches() {
        let frames: [UInt32: CGRect] = [1: CGRect(x: 0, y: 0, width: 20, height: 20), 2: CGRect(x: 50, y: 0, width: 20, height: 20), 3: CGRect(x: 0, y: 50, width: 20, height: 20)]
        XCTAssertEqual(MiniatureLayout.nearest(from: 1, direction: .right, frames: frames, matches: [1, 2, 3]), 2)
        XCTAssertEqual(MiniatureLayout.nearest(from: 1, direction: .down, frames: frames, matches: [1, 2, 3]), 3)
        XCTAssertNil(MiniatureLayout.nearest(from: 1, direction: .right, frames: frames, matches: [1, 3]))
    }
}

@MainActor
final class MiniatureSessionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func session() -> LensSession {
        let workspace = Workspace.get(byName: "1")
        let other = Workspace.get(byName: "2")
        var settings = LensConfig()
        settings.presentation = "miniatures"
        let windows = [TestWindow.new(id: 1, parent: workspace.rootTilingContainer), TestWindow.new(id: 2, parent: workspace), TestWindow.new(id: 3, parent: macosMinimizedWindowsContainer), TestWindow.new(id: 4, parent: other.rootTilingContainer)]
        let items = windows.enumerated().map { index, window in
            SwitcherPaletteItem(id: window.windowId, title: ["Alpha", "Beta", "Gamma", "Delta"][index], appName: "Demo", icon: nil, workspaceName: index == 3 ? "2" : "1", isFocused: false,
                                miniature: MiniatureWindow(workspace: index == 3 ? "2" : "1", frame: CGRect(x: CGFloat(index % 2) * 500, y: 0, width: 500, height: 500), tray: index == 2, frozen: index >= 2, accessory: false, floating: index == 1, window: window))
        }
        let model = LensSession(name: "overview", settings: settings, items: items, search: "")
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "One", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: true), MiniatureWorkspace(name: "2", title: "Two", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: false)]
        return model
    }

    func testSearchDimsInPlaceRanksSelectionAndNavigationOnlyMatches() {
        let model = session()
        let frames = model.miniatureFrames
        XCTAssertFalse(model.miniatureSearchVisible)
        model.send(.searchChanged("Beta"))
        XCTAssertTrue(model.miniatureSearchVisible)
        XCTAssertEqual(model.selectedId, 2)
        XCTAssertEqual(model.miniatureOpacity(1), 0.18)
        XCTAssertEqual(model.miniatureOpacity(2), 1)
        XCTAssertEqual(model.miniatureFrames, frames)
        model.moveMiniatureSelection(.left)
        XCTAssertEqual(model.selectedId, 2)
        model.send(.searchChanged(""))
        XCTAssertFalse(model.miniatureSearchVisible)
        model.hover(1)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 2)
    }

    func testTrayBelongsToRetainedWorkspaceAndDoesNotMoveOtherFrames() throws {
        let model = session()
        let tray = try XCTUnwrap(model.miniatureFrames[3])
        let cell = try XCTUnwrap(model.miniatureLayout.cells(on: 0).first)
        XCTAssertEqual(tray.minY, cell.tray.minY)
        XCTAssertLessThanOrEqual(tray.maxX, cell.tray.maxX)
        XCTAssertEqual(model.items[2].miniature?.workspace, "1")
    }

    func testUngroupedFramesKeepRealPositionsAndTraySizeThroughSearch() throws {
        let model = session()
        let cell = try XCTUnwrap(model.miniatureCells(on: 0).first)
        let frames = model.miniatureFrames
        XCTAssertEqual(frames[1], MiniatureLayout.scale(CGRect(x: 0, y: 0, width: 500, height: 500), from: model.miniatureWorkspaces[0].source, to: cell.frame))
        XCTAssertEqual(frames[3]?.size, CGSize(width: 48, height: 28))
        XCTAssertEqual(frames[3]?.origin, cell.tray.origin)
        model.send(.searchChanged("a"))
        XCTAssertEqual(model.results.count, 4)
        XCTAssertEqual(model.miniatureFrames, frames)
        model.send(.searchChanged("Beta"))
        XCTAssertEqual(model.results.map(\.id), [2])
        XCTAssertEqual(model.miniatureFrames, frames)
    }

    func testUngroupedPointerHitTestKeepsFloatingPriorityTrayAndSearch() throws {
        let original = session()
        var items = original.items
        let floating = original.items[1].miniature!.window
        items[1] = SwitcherPaletteItem(id: 2, title: "Beta", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
            miniature: MiniatureWindow(workspace: "1", frame: original.items[0].miniature!.frame, tray: false, frozen: false, accessory: false, floating: true, window: floating))
        var pointer = CGPoint.zero
        let model = LensSession(name: "pointer", settings: original.settings, items: items, search: "", pointerLocation: { pointer })
        model.miniatureWorkspaces = original.miniatureWorkspaces
        XCTAssertTrue(model.items.allSatisfy { $0.miniature?.tab == nil })
        let top = try XCTUnwrap(model.miniatureFrames[1])
        let point = CGPoint(x: top.midX, y: top.midY)
        XCTAssertEqual(model.miniatureHitTest(at: point), 2)
        pointer = CGPoint(x: 10000, y: 10000)
        let owner = ownLens(model)
        defer { owner.dismiss() }
        pointer.x += 2
        model.hoverMiniature(at: point, pointerLocation: pointer)
        XCTAssertEqual(model.selectedId, 2)
        model.hover(1)
        model.hoverMiniature(at: point, pointerLocation: pointer)
        XCTAssertEqual(model.selectedId, 1)
        let tray = try XCTUnwrap(model.miniatureFrames[3])
        XCTAssertEqual(model.miniatureHitTest(at: CGPoint(x: tray.midX, y: tray.midY)), 3)
        model.send(.searchChanged("Alpha"))
        // The dimmed floating window no longer takes the pointer from the match under it
        XCTAssertEqual(model.miniatureHitTest(at: point), 1)
        XCTAssertEqual(model.selectedId, 1)
    }

    func testByWorkspaceAndOverrideIgnoreAppGrouping() {
        let original = session()
        var settings = original.settings
        settings.entries = "app"
        settings.miniatures.arrowKeys = "by-workspace"
        let model = LensSession(name: "override", settings: settings, items: original.items, search: "")
        model.miniatureWorkspaces = original.miniatureWorkspaces
        XCTAssertEqual(model.results.count, 4)
        model.hover(1)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 2)
        model.moveMiniatureSelection(.down)
        XCTAssertEqual(model.selectedId, 4)
        model.moveMiniatureSelection(.up)
        XCTAssertEqual(model.selectedId, 1)
    }

    func testSelectionRevealsItsPageWithoutChangingLastPageCellSize() throws {
        let original = session()
        let window = original.items[3].miniature!.window
        let item = SwitcherPaletteItem(id: 4, title: "Last", appName: "Demo", icon: nil, workspaceName: "50", isFocused: false,
            miniature: MiniatureWindow(workspace: "50", frame: CGRect(x: 0, y: 0, width: 500, height: 500), tray: false, frozen: true, accessory: false, floating: false, window: window))
        let model = LensSession(name: "pages", settings: original.settings, items: [original.items[0], item], search: "")
        model.miniatureSize = CGSize(width: 800, height: 600)
        model.miniatureWorkspaces = (1 ... 50).map { MiniatureWorkspace(name: String($0), title: String($0), source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: $0 == 1) }
        model.hover(4)
        model.revealMiniatureSelection()
        XCTAssertEqual(model.miniaturePage, 8)
        let lastFrame = try XCTUnwrap(model.miniatureFrames[4])
        XCTAssertEqual(model.miniatureHitTest(at: CGPoint(x: lastFrame.midX, y: lastFrame.midY - 8 * model.miniatureSize.height)), 4)
        XCTAssertEqual(model.miniatureCells(on: 8).map(\.frame), Array(model.miniatureCells(on: 0).prefix(2)).map(\.frame))
        model.turnMiniaturePage(-1)
        XCTAssertEqual(model.miniaturePage, 7)
        model.turnMiniaturePage(-10)
        XCTAssertEqual(model.miniaturePage, 0)
        XCTAssertEqual(model.selectedId, 1)
    }

    func testHiddenCurrentAndListOverridePreserveSelectionAndMarks() {
        let model = session()
        model.send(.excludedChanged([1, 2, 3]))
        XCTAssertEqual(model.selectedId, 4)
        model.toggleMark()
        model.changePresentation("list")
        XCTAssertEqual(model.selectedId, 4)
        XCTAssertEqual(model.marks, [4])
        XCTAssertEqual(model.results.count, 4)
    }

    private func tabSession(drawing indices: [Int], active: Int) -> LensSession {
        let group = Workspace.get(byName: "1").rootTilingContainer
        let items = indices.map { index in
            let window = TestWindow.new(id: UInt32(index + 1), parent: group)
            return SwitcherPaletteItem(id: window.windowId, title: "Tab \(index)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: .zero, tray: false, frozen: false, accessory: false, floating: false, window: window,
                    tab: MiniatureTabSnapshot(group: ObjectIdentifier(group), frame: CGRect(x: 0, y: 0, width: 500, height: 500), index: index, count: 3, activeIndex: active)))
        }
        var settings = LensConfig()
        settings.presentation = "miniatures"
        let model = LensSession(name: "tabs", settings: settings, items: items, search: "")
        model.miniatureSize = CGSize(width: 1000, height: 700)
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "One", source: CGRect(x: 0, y: 0, width: 1000, height: 500), current: true)]
        return model
    }

    func testAFilteredLensFansOnlyTheTabsItDraws() throws {
        let all = tabSession(drawing: [0, 1, 2], active: 1).miniatureFrames
        let model = tabSession(drawing: [0, 2], active: 1)
        let frames = model.miniatureFrames
        let cell = try XCTUnwrap(model.miniatureCells(on: 0).first)
        let group = MiniatureLayout.scale(CGRect(x: 0, y: 0, width: 500, height: 500), from: CGRect(x: 0, y: 0, width: 1000, height: 500), to: cell.frame)
        // With the active tab not drawn, the first drawn tab takes the front at the group's origin
        XCTAssertEqual(frames[1]?.origin, group.origin)
        XCTAssertEqual(frames[1], MiniatureLayout.fan(group, count: 2, index: 0, activeIndex: -1, cellWidth: cell.frame.width))
        XCTAssertEqual(frames[3], MiniatureLayout.fan(group, count: 2, index: 1, activeIndex: -1, cellWidth: cell.frame.width))
        XCTAssertGreaterThan(try XCTUnwrap(frames[1]).width, try XCTUnwrap(all[1]).width)
    }

    func testPointerOverADimmedFrontTabSelectsTheMatchingTabBehindIt() throws {
        let model = tabSession(drawing: [0, 1, 2], active: 1)
        model.send(.searchChanged("Tab 2"))
        let behind = try XCTUnwrap(model.miniatureFrames[3])
        let front = try XCTUnwrap(model.miniatureFrames[2])
        let point = CGPoint(x: behind.midX, y: behind.midY)
        XCTAssertTrue(front.contains(point))
        model.hover(3)
        XCTAssertEqual(model.miniatureHitTest(at: point), 3)
    }

    func testTabSessionFramesDrawOrderSearchAndBothArrowModes() throws {
        let workspace = Workspace.get(byName: "1")
        let group = workspace.rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: group) }
        let source = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let groupFrame = CGRect(x: 0, y: 0, width: 500, height: 500)
        let items = windows.enumerated().map { index, window in
            let tab = index < 3 ? MiniatureTabSnapshot(group: ObjectIdentifier(group), frame: groupFrame, index: index, count: 3, activeIndex: 1) : nil
            return SwitcherPaletteItem(id: window.windowId, title: "Tab \(index)", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: index == 3 ? CGRect(x: 500, y: 0, width: 500, height: 500) : .zero,
                    tray: false, frozen: false, accessory: false, floating: false, window: window, tab: tab))
        }
        for (mode, size) in [("nearest", CGSize(width: 1000, height: 700)), ("by-workspace", CGSize(width: 1000, height: 700)), ("nearest", CGSize(width: 60, height: 150))] {
            var settings = LensConfig()
            settings.presentation = "miniatures"
            settings.miniatures.arrowKeys = mode
            settings.miniatures.fit = "shrink"
            let model = LensSession(name: "tabs", settings: settings, items: items, search: "")
            model.miniatureSize = size
            model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "One", source: source, current: true)]
            let frames = model.miniatureFrames
            XCTAssertNotEqual(frames[1], frames[2])
            XCTAssertNotEqual(frames[2], frames[3])
            XCTAssertNotEqual(frames[1], frames[3])
            let cell = try XCTUnwrap(model.miniatureCells(on: 0).first)
            XCTAssertEqual(frames[4], MiniatureLayout.scale(items[3].miniature!.frame, from: source, to: cell.frame))
            XCTAssertEqual(miniatureDrawOrder(items).filter { $0.id <= 3 }.map(\.id), [3, 1, 2])
            let frontToBack = miniatureDrawOrder(items).reversed()
            for id: UInt32 in [1, 2, 3] {
                let frame = try XCTUnwrap(frames[id])
                let exposedEdge = CGPoint(x: frame.maxX - 0.1, y: frame.midY)
                XCTAssertEqual(frontToBack.first { frames[$0.id]?.contains(exposedEdge) == true }?.id, id)
                XCTAssertEqual(model.miniatureHitTest(at: exposedEdge), id)
                model.hoverMiniature(at: exposedEdge, pointerLocation: CGPoint(x: CGFloat(id) + 10000, y: 10000))
                XCTAssertEqual(model.selectedId, id)
            }
            model.hover(2)
            model.moveMiniatureSelection(.right)
            XCTAssertEqual(model.selectedId, 1)
            model.moveMiniatureSelection(.right)
            XCTAssertEqual(model.selectedId, 3)
            model.moveMiniatureSelection(.left)
            XCTAssertEqual(model.selectedId, 1)
            model.moveMiniatureSelection(.left)
            XCTAssertEqual(model.selectedId, 2)
            model.send(.searchChanged("Tab 2"))
            XCTAssertEqual(model.selectedId, 3)
            XCTAssertEqual(model.miniatureOpacity(1), 0.18)
            XCTAssertEqual(model.miniatureOpacity(3), 1)
            XCTAssertEqual(model.miniatureFrames, frames)
        }
    }

    func testGroupedAccessoryTabsStayInsideGroupInsteadOfEnlargingAndClampingTogether() throws {
        let workspace = Workspace.get(byName: "1")
        let group = workspace.rootTilingContainer
        let groupFrame = CGRect(x: 950, y: 400, width: 50, height: 100)
        let source = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let items = (0 ..< 2).map { index in
            let window = TestWindow.new(id: UInt32(index + 1), parent: group)
            return SwitcherPaletteItem(id: window.windowId, title: "Accessory", appName: "Demo", icon: nil, workspaceName: "1", isFocused: false,
                miniature: MiniatureWindow(workspace: "1", frame: groupFrame, tray: false, frozen: false, accessory: true, floating: false, window: window,
                    tab: MiniatureTabSnapshot(group: ObjectIdentifier(group), frame: groupFrame, index: index, count: 2, activeIndex: 0)))
        }
        var settings = LensConfig()
        settings.presentation = "miniatures"
        let model = LensSession(name: "accessory-tabs", settings: settings, items: items, search: "")
        model.miniatureWorkspaces = [MiniatureWorkspace(name: "1", title: "One", source: source, current: true)]
        let cell = try XCTUnwrap(model.miniatureCells(on: 0).first)
        let scaledGroup = MiniatureLayout.scale(groupFrame, from: source, to: cell.frame)
        for frame in model.miniatureFrames.values { XCTAssertTrue(scaledGroup.contains(frame)) }
        model.hover(1)
        model.moveMiniatureSelection(.right)
        XCTAssertEqual(model.selectedId, 2)
    }

    func testSummonModifierComesFromConfiguredCommands() {
        let original = session()
        var settings = original.settings
        settings.keys["shift-enter"] = ["close"]
        settings.keys["ctrl-enter"] = ["summon"]
        let model = LensSession(name: "custom", settings: settings, items: original.items, search: "")
        model.updateSummonModifiers(.shift)
        XCTAssertFalse(model.summonHeld)
        model.updateSummonModifiers(.control)
        XCTAssertTrue(model.summonHeld)
        model.updateSummonModifiers([])
        XCTAssertFalse(model.summonHeld)
    }

    func testLandingPreviewDoesNotMutateTabTreeAndIsOnlyComputedWhenHeld() {
        let model = session()
        let root = focus.workspace.rootTilingContainer
        root.layout = .tabGroup
        let children = root.children
        model.hover(4)
        XCTAssertNil(model.miniatureLanding)
        let owner = ownLens(model)
        defer { owner.dismiss() }
        model.send(.summonChanged(true))
        XCTAssertNotNil(model.miniatureLanding)
        XCTAssertEqual(root.children, children)
        XCTAssertTrue(focus.workspace.rootTilingContainer === root)
        model.send(.summonChanged(false))
        XCTAssertNil(model.miniatureLanding)
    }
}
