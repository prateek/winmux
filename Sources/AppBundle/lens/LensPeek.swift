import AppKit
import Common
import SwiftUI

@MainActor
final class LensPeekCapture: ObservableObject {
    typealias Capture = @Sendable (UInt32, CGSize) async throws -> CGImage
    @Published private(set) var image: CGImage?
    private(set) var windowId: UInt32?
    private var generation = 0
    private(set) var task: Task<Void, Never>?
    private let capture: Capture
    var completed: (Double) -> Void = { _ in }

    init(capture: @escaping Capture = { try await WindowScreenshot.capture($0, pixelSize: $1) }) { self.capture = capture }

    /// The capture asked for while another is still running. ScreenCaptureKit cannot cancel a
    /// screenshot, so at most one runs and only the latest request waits for it.
    private var waiting: (id: UInt32, pixelSize: CGSize)?

    func select(_ id: UInt32?, frozen: Bool = false, pixelSize: CGSize = .zero) {
        guard id != windowId else { return }
        generation += 1
        image = nil
        windowId = id
        waiting = nil
        guard let id, !frozen else { return }
        if task != nil { waiting = (id, pixelSize) }
        else { start(id, pixelSize: pixelSize) }
    }

    private func start(_ id: UInt32, pixelSize: CGSize) {
        let ticket = generation
        let capture = capture
        let started = LensTimebase.now()
        task = Task { @MainActor [weak self] in
            let image = try? await capture(id, pixelSize)
            guard let self else { return }
            self.task = nil
            if self.generation == ticket, self.windowId == id {
                self.image = image
                // A failed capture has no time to report.
                if image != nil { self.completed((LensTimebase.now() - started) * 1000) }
            } else if let next = self.waiting {
                self.waiting = nil
                self.start(next.id, pixelSize: next.pixelSize)
            }
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

private final class PeekPanel: NSPanelHud {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LensPeekController {
    let panel: NSPanelHud = PeekPanel()
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
        panel.ignoresMouseEvents = true
        panel.applyWinMuxLayer(.overlay)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LensPeekView(drawing: drawing, capture: capture))
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
        panel.orderOut(nil)
    }

    func update(_ model: LensSession, relativeTo lens: NSWindow) {
        guard lens.isVisible, model.peekedId != nil || showing != nil else { return }
        self.model = model
        self.lens = lens
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
        follow = follows
        showing = item.id
        capture.select(item.id, frozen: drawing.frozen, pixelSize: CGSize(width: real.width * screen.backingScaleFactor, height: real.height * screen.backingScaleFactor))
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
                .background(Color(white: 34.0 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { if !drawing.follow { RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 4) } }
                .shadow(color: .black.opacity(0.6), radius: 55, y: 40)
                .overlay(alignment: .bottom) {
                    if drawing.labelShown {
                        Text(drawing.label).font(.system(size: 16)).foregroundStyle(.white).lineLimit(1)
                            .padding(.vertical, 6).padding(.horizontal, 14)
                            .background(Color(red: 20.0 / 255, green: 22.0 / 255, blue: 28.0 / 255).opacity(0.86), in: RoundedRectangle(cornerRadius: 9))
                            .fixedSize().offset(y: peekLabelOffset(pictureBottom: rect.maxY, screenHeight: proxy.size.height))
                    }
                }
                .position(x: rect.midX, y: rect.midY)
                .opacity(drawing.opacity)
        }
        .allowsHitTesting(false)
    }
}

private struct PeekPicture: View {
    let thumbnail: WindowThumbnail?
    let fullImage: CGImage?
    let icon: NSImage?
    let frozen: Bool
    let look: String
    var body: some View {
        if let thumbnail { PeekThumbnail(thumbnail: thumbnail, fullImage: fullImage, icon: icon, frozen: frozen, look: look) }
        else if let icon { Image(nsImage: icon).resizable().scaledToFit().padding(30) }
        else { Image(systemName: "macwindow").resizable().scaledToFit().padding(30).foregroundStyle(.white) }
    }
}

private struct PeekThumbnail: View {
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
            else { Image(systemName: "macwindow").resizable().scaledToFit().padding(30).foregroundStyle(.white) }
            if let badge = appearance.badge {
                Group { if badge == "pause" { Image(systemName: "pause.fill") } else { Text(badge) } }
                    .font(.system(size: 12)).foregroundStyle(.white).padding(6).background(.black.opacity(0.6)).padding(8)
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
