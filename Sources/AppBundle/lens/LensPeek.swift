import AppKit
import Common
import SwiftUI

@MainActor
final class LensPeekCapture: ObservableObject {
    typealias Capture = @Sendable (UInt32, CGSize) async throws -> CGImage
    @Published private(set) var image: CGImage?
    private(set) var windowId: UInt32?
    private var frozen = false
    private var pixelSize = CGSize.zero
    private var target: WindowCaptureTarget?
    /// Bumped each time a window turns Frozen, so a capture taken before cannot stand in for one
    /// taken after it is restored.
    private var freezes: [UInt32: Int] = [:]
    /// The selected window still needs a picture: no capture of it has returned since it was chosen.
    private var wanted = false
    /// Captures not yet returned. ScreenCaptureKit cannot cancel a screenshot, so a new capture
    /// starts only when none is out, or the one out is past its deadline. Two out and none starts.
    private var outstanding: [(serial: Int, id: UInt32, freezes: Int, expired: Bool)] = []
    private var serial = 0
    private(set) var task: Task<Void, Never>?
    private let capture: WindowImageCapture
    let deadline: Duration
    var completed: (Double) -> Void = { _ in }

    init(capture: @escaping Capture, deadline: Duration = .seconds(1)) {
        self.capture = { try await capture($0.id, $1) }
        self.deadline = deadline
    }

    init(captureWindow: @escaping WindowImageCapture = { try await WindowScreenshot.capture($0, pixelSize: $1) }, deadline: Duration = .seconds(1)) {
        self.capture = captureWindow
        self.deadline = deadline
    }

    var outstandingCount: Int { outstanding.count }

    func select(_ id: UInt32?, frozen: Bool = false, pixelSize: CGSize = .zero, target: WindowCaptureTarget? = nil) {
        self.target = target ?? id.map { WindowCaptureTarget(id: $0) }
        guard id != windowId || frozen != self.frozen else { return }
        if let id, frozen { freezes[id, default: 0] += 1 }
        image = nil
        windowId = id
        self.frozen = frozen
        self.pixelSize = pixelSize
        // A Frozen window shows its thumbnail; one restored from the tray is captured again.
        wanted = id != nil && !frozen
        pump()
    }

    private func pump() {
        guard wanted, let id = windowId, let target else { return }
        let epoch = freezes[id] ?? 0
        // A capture of this window is already out and inside its deadline: its image will do.
        if outstanding.contains(where: { $0.id == id && $0.freezes == epoch && !$0.expired }) { return }
        guard outstanding.isEmpty || (outstanding.count == 1 && outstanding[0].expired) else { return }
        serial += 1
        let ticket = serial, size = pixelSize, capture = capture
        let started = LensTimebase.now()
        outstanding.append((ticket, id, epoch, false))
        task = Task { @MainActor [weak self] in
            let image = try? await capture(target, size)
            guard let self else { return }
            self.outstanding.removeAll { $0.serial == ticket }
            if self.windowId == id, !self.frozen, self.freezes[id] ?? 0 == epoch {
                // Whether it brought a picture or failed, this window has had its capture.
                self.wanted = false
                if self.image == nil, let image {
                    self.image = image
                    self.completed((LensTimebase.now() - started) * 1000)
                }
            }
            self.pump()
        }
        Task { @MainActor [weak self, deadline] in
            try? await Task.sleep(for: deadline)
            guard let self, let index = self.outstanding.firstIndex(where: { $0.serial == ticket }) else { return }
            self.outstanding[index].expired = true
            self.pump()
        }
    }
}

func peekLabel(title: String, app: String, workspace: String) -> String {
    let place = workspace.hasPrefix("Workspace ") ? workspace : "Workspace \(workspace)"
    return "\(title) · \(app) · \(place)"
}

/// The label's bottom sits 44 points below the picture, as in the prototype, but never closer than
/// 12 points to the bottom of the screen: a full-height window would otherwise push it off screen.
func peekLabelOffset(pictureBottom: CGFloat, screenHeight: CGFloat) -> CGFloat {
    min(44, screenHeight - 12 - pictureBottom)
}

func peekFittedRect(aspect: CGFloat, in frame: CGRect) -> CGRect {
    let aspect = max(0.01, aspect)
    let height = min(frame.height, frame.width / aspect)
    let size = CGSize(width: height * aspect, height: height)
    return CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height)
}

func peekTileOnScreen(_ rect: CGRect?, lensFrame: CGRect, screen: CGRect) -> CGRect? {
    guard let rect else { return nil }
    let global = CGRect(x: lensFrame.minX + rect.minX, y: lensFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
    guard screen.contains(CGPoint(x: global.midX, y: global.midY)) else { return nil }
    return CGRect(x: global.minX - screen.minX, y: screen.maxY - global.maxY, width: global.width, height: global.height)
}

struct PeekOpening {
    let rect: CGRect
    let opacity: Double
    init(tile: CGRect?, destination: CGRect, follow: Bool, reduceMotion: Bool) {
        rect = !follow && !reduceMotion ? tile ?? destination : destination
        opacity = !follow && (tile == nil || reduceMotion) ? 0 : 1
    }
}

extension LensSession {
    var peekItem: SwitcherPaletteItem? { results.first { $0.id == peekedId } }

    func peekTileRect() -> CGRect? {
        guard let id = selectedId, let index = results.firstIndex(where: { $0.id == id }) else { return nil }
        if settings.presentation == "list" { return listRowRects[id] }
        if settings.presentation == "miniatures" {
            guard let rect = miniatureFrames[id] else { return nil }
            let visible = rect.offsetBy(dx: 0, dy: -CGFloat(miniaturePage) * miniatureSize.height)
            return CGRect(origin: .zero, size: miniatureSize).intersects(visible) ? visible : nil
        }
        let layout = settings.presentation == "strip" ? stripSnapshot(items: results).layout : gridLayout
        guard layout.tiles.indices.contains(index) else { return nil }
        let tile = layout.tiles[index]
        let rect: CGRect
        if tileKind == .text { rect = tile.frame }
        else {
            let picture = tilePictureRect(entry: results[index].tile, kind: tileKind, size: tile.frame.size, pictureSize: tile.pictureSize,
                                          metrics: TileMetrics(scale: layout.tileScale), presentation: settings.presentation, selected: true)
                .offsetBy(dx: tile.frame.minX, dy: tile.frame.minY)
            rect = scaledTileRect(picture, about: tile.frame, by: TileMetrics(scale: layout.tileScale).selectionScale)
        }
        guard !tilesFrameInWindow.isEmpty else { return nil }
        return rect.offsetBy(dx: tilesFrameInWindow.minX, dy: tilesFrameInWindow.minY)
    }
}

final class PeekPanel: NSPanelHud {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    var onMouseDown: () -> Void = {}
    /// While a zoom covers the screen the panel takes the mouse, so a click lands on nothing
    /// underneath, the Lens or another app.
    var takesMouse = false { didSet { updateIgnoresMouse() } }
    private var buttonsDown = 0

    /// Each button's down ends the zoom, and the whole click is eaten: the panel keeps the mouse
    /// until the last button is up, so no up or drag reaches what was under the picture.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                buttonsDown += 1
                updateIgnoresMouse()
                onMouseDown()
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                buttonsDown = max(0, buttonsDown - 1)
                updateIgnoresMouse()
            case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: break
            default: super.sendEvent(event)
        }
    }

    private func updateIgnoresMouse() { ignoresMouseEvents = !(takesMouse || buttonsDown > 0) }

    /// Ordered out mid-click, the panel may never see that click's mouse-up.
    func forgetButtons() {
        buttonsDown = 0
        updateIgnoresMouse()
    }
}

@MainActor
final class LensPeekController {
    let panel = PeekPanel()
    private let drawing = LensPeekDrawing()
    private let capture = LensPeekCapture()
    private var hideTask: Task<Void, Never>?
    private var showing: UInt32?
    private var screenFrame = CGRect.zero
    private weak var model: LensSession?
    private weak var lens: NSWindow?
    private var follow = false

    init() {
        panel.identifier = NSUserInterfaceItemIdentifier("WinMux.lensPeek")
        panel.hasShadow = false
        panel.takesMouse = false
        panel.applyWinMuxLayer(.overlay)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LensPeekView(drawing: drawing, capture: capture))
        panel.onMouseDown = { [weak self] in _ = self?.model?.endZoomForClick() }
        capture.completed = { [weak self] ms in
            guard let self, let model = self.model, let lens = self.lens else { return }
            model.peekCaptureMs = ms
            if self.capture.image != nil { self.update(model, relativeTo: lens) }
        }
    }

    func hide() {
        hideTask?.cancel(); hideTask = nil
        capture.select(nil)
        showing = nil
        model = nil
        lens = nil
        drawing.thumbnail = nil
        panel.takesMouse = false
        panel.forgetButtons()
        panel.orderOut(nil)
    }

    func update(_ model: LensSession, relativeTo lens: NSWindow) {
        guard lens.isVisible, model.peekedId != nil || showing != nil else { return }
        self.model = model
        self.lens = lens
        if drawing.theme != model.theme || panel.appearance == nil {
            panel.appearance = model.theme.nsAppearance
            drawing.theme = model.theme
        }
        guard let item = model.peekItem, let window = item.miniature?.window ?? Window.get(byId: item.id) else {
            if showing != nil { shrink(model, lens: lens) }
            return
        }
        let real = miniatureWindowFrame(window)
        let appKitFrame = CGRect(x: real.minX, y: appKitScreenMaxY() - real.maxY, width: real.width, height: real.height)
        let screen = NSScreen.screens.max { a, b in
            max(0, a.frame.intersection(appKitFrame).width) * max(0, a.frame.intersection(appKitFrame).height) < max(0, b.frame.intersection(appKitFrame).width) * max(0, b.frame.intersection(appKitFrame).height)
        } ?? NSScreen.main
        guard let screen else { return }
        let changedSelection = showing != item.id
        let first = showing == nil || !panel.isVisible
        let changedScreen = screenFrame != screen.frame
        let follows = model.followsPeek
        hideTask?.cancel(); hideTask = nil
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let thumbnail = item.tile.picture ?? window.thumbnail
        let image = capture.windowId == item.id ? capture.image ?? thumbnail.image : thumbnail.image
        let aspect = image.map { CGFloat($0.width) / CGFloat(max(1, $0.height)) } ?? real.width / max(1, real.height)
        let destination = local(peekFittedRect(aspect: aspect, in: appKitFrame), screen: screen.frame)
        if changedScreen || first {
            screenFrame = screen.frame
            panel.setFrame(screen.frame, display: false)
        }
        drawing.thumbnail = thumbnail
        drawing.icon = item.icon
        drawing.frozen = item.tile.frozen || item.miniature?.frozen == true
        drawing.look = model.settings.frozenThumbnail
        drawing.label = peekLabel(title: item.title, app: item.appName, workspace: item.workspaceName)
        drawing.follow = follows
        drawing.labelShown = !follows
        let origin = tileRect(model, lens: lens, screen: screen.frame)
        if first {
            let opening = PeekOpening(tile: origin, destination: destination, follow: follows, reduceMotion: reduce)
            drawing.rect = opening.rect
            drawing.opacity = opening.opacity
        } else if changedScreen {
            drawing.rect = destination
            drawing.opacity = 0
        }
        panel.order(follows ? .below : .above, relativeTo: lens.windowNumber)
        panel.takesMouse = !follows
        follow = follows
        showing = item.id
        capture.select(item.id, frozen: drawing.frozen, pixelSize: CGSize(width: real.width * screen.backingScaleFactor, height: real.height * screen.backingScaleFactor), target: window.captureTarget)
        if reduce, !first, changedSelection {
            drawing.rect = destination
            drawing.opacity = 0
        }
        let animate = { [weak self] in
            guard let self, self.showing == item.id else { return }
            if reduce { self.drawing.rect = destination }
            else {
                withAnimation(follows ? .easeInOut(duration: 0.2) : .timingCurve(0.2, 0.9, 0.25, 1.04, duration: 0.26)) {
                    self.drawing.rect = destination
                }
            }
            withAnimation(.easeOut(duration: 0.18)) { self.drawing.opacity = 1 }
        }
        if first || reduce { DispatchQueue.main.async(execute: animate) } else { animate() }
    }

    private func shrink(_ model: LensSession, lens: NSWindow) {
        showing = nil
        panel.takesMouse = false
        capture.select(nil)
        drawing.labelShown = false
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let origin = tileRect(model, lens: lens, screen: screenFrame)
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1.04, duration: 0.26)) {
            if !reduce, !follow, let origin { drawing.rect = origin }
        }
        if reduce || follow || origin == nil {
            withAnimation(.easeOut(duration: 0.18)) { drawing.opacity = 0 }
        }
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func local(_ rect: CGRect, screen: CGRect) -> CGRect {
        CGRect(x: rect.minX - screen.minX, y: screen.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
    private func tileRect(_ model: LensSession, lens: NSWindow, screen: CGRect) -> CGRect? {
        peekTileOnScreen(model.peekTileRect(), lensFrame: lens.frame, screen: screen)
    }
}

@MainActor
final class LensPeekDrawing: ObservableObject {
    @Published var theme = LensTheme.dark
    @Published var rect = CGRect.zero
    @Published var opacity = 0.0
    @Published var thumbnail: WindowThumbnail?
    @Published var icon: NSImage?
    @Published var frozen = false
    @Published var look = "dimmed"
    @Published var label = ""
    @Published var labelShown = false
    @Published var follow = false
}

struct LensPeekView: View {
    @ObservedObject var drawing: LensPeekDrawing
    @ObservedObject var capture: LensPeekCapture
    var body: some View {
        GeometryReader { proxy in
            let rect = drawing.rect
            PeekPicture(thumbnail: drawing.thumbnail, fullImage: capture.image, icon: drawing.icon, frozen: drawing.frozen, look: drawing.look)
                .frame(width: max(1, rect.width), height: max(1, rect.height))
                .background(drawing.theme.peekPlate)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { if !drawing.follow { RoundedRectangle(cornerRadius: 12).stroke(drawing.theme.selectionRing, lineWidth: 4) } }
                .shadow(color: .black.opacity(0.6), radius: 55, y: 40)
                .overlay(alignment: .bottom) {
                    if drawing.labelShown {
                        Text(drawing.label).font(.system(size: 16)).foregroundStyle(drawing.theme.text).lineLimit(1)
                            .padding(.vertical, 6).padding(.horizontal, 14)
                            .background(drawing.theme.peekLabel, in: RoundedRectangle(cornerRadius: 9))
                            .fixedSize().offset(y: peekLabelOffset(pictureBottom: rect.maxY, screenHeight: proxy.size.height))
                    }
                }
                .position(x: rect.midX, y: rect.midY)
                .opacity(drawing.opacity)
        }
        .environment(\.lensTheme, drawing.theme)
        .environment(\.colorScheme, drawing.theme.colorScheme)
        .allowsHitTesting(false)
    }
}

private struct PeekPicture: View {
    @Environment(\.lensTheme) private var theme
    let thumbnail: WindowThumbnail?
    let fullImage: CGImage?
    let icon: NSImage?
    let frozen: Bool
    let look: String
    var body: some View {
        if let thumbnail { PeekThumbnail(thumbnail: thumbnail, fullImage: fullImage, icon: icon, frozen: frozen, look: look) }
        else if let icon { Image(nsImage: icon).resizable().scaledToFit().padding(30) }
        else { Image(systemName: "macwindow").resizable().scaledToFit().padding(30).foregroundStyle(theme.text) }
    }
}

private struct PeekThumbnail: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var thumbnail: WindowThumbnail
    let fullImage: CGImage?
    let icon: NSImage?
    let frozen: Bool
    let look: String
    var body: some View {
        let appearance = ThumbnailAppearance(frozen: frozen, look: look, capturedAt: thumbnail.capturedAt, now: Date())
        ZStack(alignment: .bottomTrailing) {
            if let image = fullImage ?? thumbnail.image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
                    .saturation(appearance.saturation).colorMultiply(Color(white: appearance.brightness)).opacity(appearance.opacity)
            } else if let icon { Image(nsImage: icon).resizable().scaledToFit().padding(30) }
            else { Image(systemName: "macwindow").resizable().scaledToFit().padding(30).foregroundStyle(theme.text) }
            if let badge = appearance.badge {
                Group { if badge == "pause" { Image(systemName: "pause.fill") } else { Text(badge) } }
                    .font(.system(size: 12)).foregroundStyle(LensTheme.dark.text).padding(6).background(.black.opacity(0.6)).padding(8)
            }
        }
    }
}

struct LensPeekDim<Content: View>: View {
    @ObservedObject var model: LensSession
    let content: Content
    var body: some View {
        content.opacity(model.zoomPeeking ? 0.28 : 1)
            .animation(.easeOut(duration: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.18 : 0.26), value: model.zoomPeeking)
    }
}
