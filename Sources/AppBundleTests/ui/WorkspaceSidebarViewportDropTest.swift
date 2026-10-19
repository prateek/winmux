import AppKit
import Common
@testable import AppBundle
import XCTest

final class WorkspaceSidebarViewportDropTest: XCTestCase {
    private let viewport = CGRect(x: 0, y: 50, width: 320, height: 300)
    private let slop = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

    private func clippedTargets() -> [WorkspaceSidebarDropTarget] {
        let sections: [WorkspaceSidebarDropTargetFrame] = [
            .init(kind: .workspace("edge"), frame: CGRect(x: 0, y: 20, width: 320, height: 360)),
            .init(kind: .workspace("visible"), frame: CGRect(x: 20, y: 120, width: 280, height: 50)),
            .init(kind: .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display"), frame: CGRect(x: 20, y: 240, width: 280, height: 40)),
            .init(kind: .workspace("hidden"), frame: CGRect(x: 0, y: 380, width: 320, height: 40)),
        ]
        let frames = workspaceSidebarVisibleTargets(sections, viewport: viewport)
        let targets = frames.map {
            WorkspaceSidebarDropTarget(kind: $0.kind, rect: rect($0.frame), viewport: $0.viewport.map(rect))
        }
        return targets + [.init(kind: .monitor("display"), rect: Rect(topLeftX: 20, topLeftY: 0, width: 120, height: 24))]
    }

    private func rect(_ frame: CGRect) -> Rect {
        Rect(topLeftX: frame.minX, topLeftY: frame.minY, width: frame.width, height: frame.height)
    }

    func testSidebarRowAndTitleBarResolversRejectBothChromeBands() {
        let targets = clippedTargets()
        for (insets, includesTreeTargets) in [(NSEdgeInsets(), true), (slop, false)] {
            for y: CGFloat in [40, 49, 351, 360, 390] {
                XCTAssertNil(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 160, y: y), targets: targets, hitSlop: insets, includesTreeTargets: includesTreeTargets), "Chrome at y=\(y)")
            }
            for y: CGFloat in [51, 349] {
                XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 160, y: y), targets: targets, hitSlop: insets, includesTreeTargets: includesTreeTargets)?.kind, .workspace("edge"))
            }
        }
    }

    func testVisibleControlsAndMonitorSlopKeepTheirDestinations() {
        let targets = clippedTargets()
        for insets in [NSEdgeInsets(), slop] {
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 60, y: 12), targets: targets, hitSlop: insets)?.kind, .monitor("display"))
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 160, y: 140), targets: targets, hitSlop: insets)?.kind, .workspace("visible"))
            XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 160, y: 260), targets: targets, hitSlop: insets)?.kind, .newWorkspace(projectId: workspaceProjectDefaultId, monitorScopeId: "display"))
        }
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 60, y: 34), targets: targets, hitSlop: slop)?.kind, .monitor("display"))
        let visible = targets.filter { $0.kind == .workspace("visible") }
        XCTAssertEqual(resolveWorkspaceSidebarDropTarget(at: CGPoint(x: 160, y: 110), targets: visible, hitSlop: slop)?.kind, .workspace("visible"))
    }

    @MainActor
    func testTitleBarDestinationInteractionStaysInsideViewport() throws {
        setUpWorkspacesForTests()
        let window = TestWindow.new(id: 810, parent: Workspace.get(byName: "1").rootTilingContainer)
        let target = try XCTUnwrap(clippedTargets().first { $0.kind == .workspace("edge") })
        let destination = try XCTUnwrap(sidebarWorkspaceDropDestination(sourceWindow: window, mouseLocation: CGPoint(x: 160, y: 340), subject: .window, target: target))
        XCTAssertFalse(destination.interactionRect.contains(CGPoint(x: 160, y: 351)))
        XCTAssertFalse(destination.interactionRect.contains(CGPoint(x: 160, y: 49)))
        XCTAssertTrue(destination.interactionRect.contains(CGPoint(x: 160, y: 51)))
        XCTAssertTrue(destination.interactionRect.contains(CGPoint(x: 160, y: 349)))
    }
}
