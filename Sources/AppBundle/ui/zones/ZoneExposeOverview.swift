import AppKit
import Common
import ScreenCaptureKit
import SwiftUI

struct ZoneExposeTile: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let preview: NSImage?
    let icon: NSImage?
    let select: @MainActor () -> Void
}

/// The overview header: `expose display` shows the active scene's columns, `expose card` shows the
/// focused card's windows.
func exposeOverviewTitle(for scope: ExposeScope) -> String {
    switch scope {
        case .display: "Columns"
        case .card: "Windows"
    }
}

/// Pre-captured per-zone previews, FlashSpace-style: the display is captured when a refresh
/// settles (never at overview-open time), cropped per zone, and downscaled, so opening the
/// overview renders cached bitmaps only. Capture stays fully disarmed until the first
/// overview use, keeping zero standing cost for users who never touch the feature.
@MainActor
final class ZoneExposePreviewCache {
    static let shared = ZoneExposePreviewCache()
    private init() {}

    private(set) var armed = false
    private var previews: [String: NSImage] = [:]
    private var lastCaptureKey: String = ""
    private var captureInFlight = false

    static func previewKey(monitorTopLeft: CGPoint, zoneId: String?, workspaceName: String) -> String {
        "\(monitorTopLeft.x),\(monitorTopLeft.y)|\(zoneId ?? "display")|\(workspaceName)"
    }

    func arm() {
        armed = true
    }

    func preview(forKey key: String) -> NSImage? {
        previews[key]
    }

    /// Called when a refresh session finishes. Cheap unless armed, permitted, and the visible
    /// zone/workspace arrangement actually changed since the last capture.
    func noteRefreshCompleted() {
        guard armed else { return }
        guard #available(macOS 14.0, *) else { return }
        // Never capture while the overview covers the display, or the first armed capture
        // poisons every zone preview with a screenshot of the overlay itself.
        guard !ZoneExposePanelController.shared.isVisible else { return }
        let physical = focus.workspace.workspaceMonitor.physicalMonitor
        let zones = zoneViewports(onPhysicalMonitor: physical)
        let captureKey = zones.map {
            Self.previewKey(
                monitorTopLeft: physical.rect.topLeftCorner,
                zoneId: $0.zoneId,
                workspaceName: $0.activeWorkspace.name,
            )
        }.joined(separator: ";")
        guard captureKey != lastCaptureKey, !captureInFlight else { return }
        // Preflight last: it is an out-of-process TCC check, so unchanged arrangements and
        // permission-denied installs must not pay it on every session end.
        guard CGPreflightScreenCaptureAccess() else { return }
        captureInFlight = true
        let displayRect = physical.rect
        let crops = zones.map { (key: Self.previewKey(
            monitorTopLeft: physical.rect.topLeftCorner,
            zoneId: $0.zoneId,
            workspaceName: $0.activeWorkspace.name,
        ), rect: $0.rect) }
        Task { @MainActor in
            defer { captureInFlight = false }
            guard let image = try? await Self.captureDisplayImage(displayRect: displayRect) else { return }
            let scaleX = CGFloat(image.width) / displayRect.width
            let scaleY = CGFloat(image.height) / displayRect.height
            for crop in crops {
                let cropRect = CGRect(
                    x: (crop.rect.topLeftX - displayRect.topLeftX) * scaleX,
                    y: (crop.rect.topLeftY - displayRect.topLeftY) * scaleY,
                    width: crop.rect.width * scaleX,
                    height: crop.rect.height * scaleY,
                )
                guard let cropped = image.cropping(to: cropRect) else { continue }
                previews[crop.key] = NSImage(cgImage: cropped, size: NSSize(width: crop.rect.width / 4, height: crop.rect.height / 4))
            }
            lastCaptureKey = captureKey
        }
    }

    @available(macOS 14.0, *)
    private static func captureDisplayImage(displayRect: Rect) async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let nsScreen = NSScreen.screens.first(where: { $0.frame == displayRect.toAppKitScreenRect }),
              let displayId = nsScreen.displayId,
              let scDisplay = content.displays.first(where: { $0.displayID == displayId })
        else { return nil }
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        // Quarter resolution: the tiles are small and the cache should stay cheap.
        configuration.width = scDisplay.width / 2
        configuration.height = scDisplay.height / 2
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}

@MainActor
func zoneViewports(onPhysicalMonitor physical: Monitor) -> [Monitor] {
    monitors
        .filter { $0.physicalMonitor.rect.topLeftCorner == physical.rect.topLeftCorner }
        .sorted { $0.rect.topLeftX < $1.rect.topLeftX }
}

private final class ZoneExposePanel: NSPanelHud {
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        MainActor.assumeIsolated {
            if !ZoneExposePanelController.shared.handleKeyDown(event) {
                super.keyDown(with: event)
            }
        }
    }

    override func cancelOperation(_ sender: Any?) {
        MainActor.assumeIsolated {
            ZoneExposePanelController.shared.hide()
        }
    }
}

@MainActor
final class ZoneExposePanelController: ObservableObject {
    static let shared = ZoneExposePanelController()

    @Published private(set) var tiles: [ZoneExposeTile] = []
    @Published var selectedIndex = 0
    private(set) var scope: ExposeScope = .card

    private let panel = ZoneExposePanel()
    private var hostingView: NSHostingView<AnyView>?

    private init() {
        panel.identifier = NSUserInterfaceItemIdentifier("WinMux.zoneExpose")
        panel.isFloatingPanel = true
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.applyWinMuxLayer(.workspaceSidebar)
        let hosting = NSHostingView(rootView: AnyView(ZoneExposeView(controller: self)))
        panel.contentView = hosting
        hostingView = hosting
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(scope: ExposeScope) {
        if isVisible, self.scope == scope {
            hide()
        } else {
            show(scope: scope)
        }
    }

    func show(scope: ExposeScope) {
        ZoneExposePreviewCache.shared.arm()
        if !CGPreflightScreenCaptureAccess() {
            // One-time system prompt on explicit user action; previews stay placeholders
            // until granted.
            CGRequestScreenCaptureAccess()
        }
        self.scope = scope
        tiles = buildTiles(scope: scope)
        selectedIndex = 0
        let monitorRect = focus.workspace.workspaceMonitor.physicalMonitor.rect
        panel.setFrame(monitorRect.toAppKitScreenRect, display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        tiles = []
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
            case 53: // escape
                hide()
                return true
            case 123: // left arrow
                selectedIndex = max(0, selectedIndex - 1)
                return true
            case 124: // right arrow
                selectedIndex = min(max(0, tiles.count - 1), selectedIndex + 1)
                return true
            case 125: // down arrow
                selectedIndex = min(max(0, tiles.count - 1), selectedIndex + 1)
                return true
            case 126: // up arrow
                selectedIndex = max(0, selectedIndex - 1)
                return true
            case 36, 49: // return, space
                selectTile(at: selectedIndex)
                return true
            default:
                if let digit = event.charactersIgnoringModifiers.flatMap(Int.init), digit >= 1, digit <= tiles.count {
                    selectTile(at: digit - 1)
                    return true
                }
                return false
        }
    }

    func selectTile(at index: Int) {
        guard tiles.indices.contains(index) else { return }
        let tile = tiles[index]
        hide()
        tile.select()
    }

    func setTilesForTests(_ tiles: [ZoneExposeTile], scope: ExposeScope) {
        self.scope = scope
        self.tiles = tiles
        selectedIndex = 0
    }

    private func buildTiles(scope: ExposeScope) -> [ZoneExposeTile] {
        switch scope {
            case .display:
                let physical = focus.workspace.workspaceMonitor.physicalMonitor
                return zoneViewports(onPhysicalMonitor: physical).map { viewport in
                    let workspace = viewport.activeWorkspace
                    let key = ZoneExposePreviewCache.previewKey(
                        monitorTopLeft: physical.rect.topLeftCorner,
                        zoneId: viewport.zoneId,
                        workspaceName: workspace.name,
                    )
                    let target = viewport.zoneId ?? workspace.name
                    return ZoneExposeTile(
                        id: key,
                        title: viewport.zoneName ?? viewport.zoneId ?? viewport.name,
                        subtitle: workspace.name,
                        preview: ZoneExposePreviewCache.shared.preview(forKey: key),
                        icon: nil,
                        select: { focusZoneOrWorkspaceFromExpose(zoneId: viewport.zoneId, target: target) },
                    )
                }
            case .card:
                let workspace = focus.workspace
                return workspace.allLeafWindowsRecursive.map { window in
                    ZoneExposeTile(
                        id: String(window.windowId),
                        title: cachedWindowTitle(for: window) ?? window.app.name ?? "Window \(window.windowId)",
                        subtitle: window.app.name ?? "",
                        preview: nil,
                        icon: (window.app as? MacApp)?.nsApp.icon,
                        select: { focusWindowFromExpose(window) },
                    )
                }
        }
    }
}

@MainActor
private func focusZoneOrWorkspaceFromExpose(zoneId: String?, target: String) {
    Task { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.menuBarButton, token) {
            if zoneId != nil {
                _ = try await FocusColumnCommand(args: FocusColumnCmdArgs(column: ZoneSelector(target)))
                    .run(.defaultEnv, .emptyStdin)
            }
        }
    }
}

@MainActor
private func focusWindowFromExpose(_ window: Window) {
    Task { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        try await runLightSession(.menuBarButton, token) {
            // Tiles freeze window references at open time; re-resolve so selecting a
            // since-closed window no-ops instead of raising a zombie.
            guard let liveWindow = Window.get(byId: window.windowId) else { return }
            _ = liveWindow.focusWindow()
            liveWindow.nativeFocus()
        }
    }
}

private struct ZoneExposeView: View {
    @ObservedObject var controller: ZoneExposePanelController

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: 18) {
                Text(exposeOverviewTitle(for: controller.scope))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(controller.tiles.enumerated()), id: \.element.id) { index, tile in
                        tileView(tile, index: index, selected: index == controller.selectedIndex)
                            .onTapGesture { controller.selectTile(at: index) }
                    }
                }
                .padding(.horizontal, 32)
                if controller.tiles.isEmpty {
                    Text("Nothing here")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func tileView(_ tile: ZoneExposeTile, index: Int, selected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                if let preview = tile.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let icon = tile.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                }
            }
            .frame(minWidth: 160, maxWidth: 320, minHeight: 100, maxHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: selected ? 3 : 1)
            )
            Text("\(index + 1)  \(tile.title)")
                .lineLimit(1)
                .foregroundStyle(.white)
            Text(tile.subtitle)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
