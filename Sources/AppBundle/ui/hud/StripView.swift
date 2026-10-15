import AppKit
import SwiftUI

struct StripView: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession

    var body: some View {
        let items = model.results
        let snapshot = model.stripSnapshot(items: items)
        let layout = snapshot.layout
        let scale = model.tileMetrics.scale
        let metrics = TileMetrics(scale: layout.tileScale)
        let footerHeight = GridLayout.Sizing.stripFooterHeight * scale
        let summonAvailable = model.summonHintsShown && model.stripSummonAvailable(items: items)
        ZStack {
            if summonAvailable, let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
                    .allowsHitTesting(false)
            }
            // The panel includes 22 points below the footer; the banner completes its 24-point gap.
            VStack(spacing: 2 * scale) {
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { point in
                            model.clickTile(at: point, event: NSApp.currentEvent)
                        }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let tile = layout.tiles[index]
                        TileView(entry: item.tile, kind: model.tileKind, presentation: "strip", metrics: metrics,
                                 size: tile.frame.size, settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                                 hint: model.summonLabel(for: item.id, destination: focus.workspace.name),
                                 pictureSize: tile.pictureSize, controlsVisible: model.hoveredTileId == item.id, workspaceHint: model.workspaceHint(for: item), hintsShown: model.hintsShown)
                            .position(x: tile.frame.midX, y: tile.frame.midY)
                            .zIndex(index == model.selection ? 1 : 0)
                            .allowsHitTesting(false)
                    }
                    LensSelectionFooter(model: model, items: items)
                        .padding(.horizontal, 44 * scale)
                        .frame(width: layout.panelSize.width, height: footerHeight)
                        .position(x: layout.panelSize.width / 2, y: layout.panelSize.height - GridLayout.Sizing.stripFooterBottom * scale - footerHeight / 2)
                }
                .frame(width: layout.panelSize.width, height: layout.panelSize.height)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(lensWindowCoordinateSpace))
                } action: { frame in
                    model.tilesFrameInWindow = frame
                }
                if let banner = model.banner {
                    Text(banner).font(.caption).foregroundStyle(.orange)
                        .padding(.bottom, GridLayout.Sizing.stripFooterBottom * scale)
                }
            }
            .foregroundStyle(theme.text)
            .background {
                LensPanelSurface(shape: RoundedRectangle(cornerRadius: 30 * scale))
                    .opacity(model.panelGlassOpacity)
            }
            .frame(width: layout.panelSize.width)
            LensHintOverlay(model: model, panelBottom: (model.miniatureSize.height + layout.panelSize.height) / 2)
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
    }
}
