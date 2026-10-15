import AppKit
import SwiftUI

struct GridView: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession

    var body: some View {
        let items = model.results
        let layout = model.gridLayout(items: items)
        let scale = model.tileMetrics.scale
        let metrics = TileMetrics(scale: layout.tileScale)
        let summonAvailable = model.summonHintsShown && model.stripSummonAvailable(items: items)
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { point in
                    model.clickTile(at: point, event: NSApp.currentEvent)
                }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let tile = layout.tiles[index]
                TileView(entry: item.tile, kind: model.tileKind, presentation: "grid", metrics: metrics, size: tile.frame.size,
                         settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                         hint: model.summonLabel(for: item.id, destination: focus.workspace.name),
                         pictureSize: tile.pictureSize, controlsVisible: model.hoveredTileId == item.id, workspaceHint: model.workspaceHint(for: item), hintsShown: model.hintsShown)
                    .position(x: tile.frame.midX, y: tile.frame.midY)
                    .zIndex(index == model.selection ? 1 : 0)
                    .allowsHitTesting(false)
            }
            ForEach(Array(layout.headers.enumerated()), id: \.offset) { _, header in
                LensSectionHeader(label: header.label, current: header.current, scale: layout.tileScale)
                    .frame(width: header.frame.width, height: header.frame.height)
                    .position(x: header.frame.midX, y: header.frame.midY)
            }
            HStack(spacing: 8 * scale) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.secondaryText)
                LensSearchRow(model: model)
                    .frame(minWidth: 180 * scale)
                LensGroupingControl(model: model)
            }
            .font(.system(size: 16 * scale)).padding(.horizontal, 28 * scale)
            .frame(width: layout.panelSize.width, height: GridLayout.Sizing.gridSearchHeight * scale)
            VStack(spacing: 3 * scale) {
                LensSelectionFooter(model: model, items: items)
                if let error = model.searchError ?? model.banner {
                    Text(error.components(separatedBy: .newlines).first ?? error).font(.system(size: 11 * scale)).foregroundStyle(.orange).lineLimit(1)
                }
            }
            .font(.system(size: 15 * scale)).padding(.horizontal, 28 * scale)
            .frame(width: layout.panelSize.width, height: GridLayout.Sizing.gridFooterHeight * scale)
            .position(x: layout.panelSize.width / 2, y: layout.panelSize.height - (GridLayout.Sizing.gridFooterHeight / 2 + GridLayout.Sizing.gridFooterBottom) * scale)
        }
        .foregroundStyle(theme.text)
        .frame(width: layout.panelSize.width, height: layout.panelSize.height)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(lensWindowCoordinateSpace))
        } action: { frame in
            model.tilesFrameInWindow = frame
        }
        .background {
            LensPanelSurface(shape: RoundedRectangle(cornerRadius: 30 * scale))
                    .opacity(model.panelGlassOpacity)
        }
        .overlay {
            if model.searchError != nil { RoundedRectangle(cornerRadius: 30 * scale).stroke(.orange, lineWidth: 1) }
        }
    }
}

struct GridLandingView: View {
    @ObservedObject var model: LensSession
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            LensHintOverlay(model: model, panelBottom: model.hintPanelBottom)
            if model.summonHintsShown, model.stripSummonAvailable(items: model.results), let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
            }
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
        .allowsHitTesting(false)
    }
}
