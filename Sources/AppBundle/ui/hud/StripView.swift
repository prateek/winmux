import AppKit
import SwiftUI

struct StripView: View {
    @ObservedObject var model: LensSession

    var body: some View {
        let snapshot = model.stripSnapshot
        let layout = snapshot.layout
        let items = snapshot.items
        let scale = model.tileMetrics.scale
        let metrics = TileMetrics(scale: layout.tileScale)
        let summonAvailable = model.stripSummonAvailable(items: items)
        ZStack {
            if summonAvailable, let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
                    .allowsHitTesting(false)
            }
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let tile = layout.tiles[index]
                    TileView(entry: item.tile, kind: model.tileKind, presentation: "strip", metrics: metrics,
                             size: tile.frame.size, settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                             hint: index == model.selection && summonAvailable && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil,
                             pictureSize: tile.pictureSize)
                        .position(x: tile.frame.midX, y: tile.frame.midY)
                        .zIndex(index == model.selection ? 1 : 0)
                        .onContinuousHover { phase in
                            if case .active = phase { model.hover(item.id, at: NSEvent.mouseLocation) }
                        }
                        .onTapGesture {
                            model.hover(item.id)
                            if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                        }
                }
                VStack(spacing: 3 * scale) {
                    LensSelectionFooter(model: model, items: items)
                    if let banner = model.banner { Text(banner).font(.caption).foregroundStyle(.orange) }
                }
                .padding(.horizontal, 44 * scale)
                .frame(width: layout.panelSize.width, height: 22 * scale + (model.banner == nil ? 0 : 18 * scale))
                .position(x: layout.panelSize.width / 2, y: layout.panelSize.height - 33 * scale + (model.banner == nil ? 0 : 9 * scale))
            }
            .foregroundStyle(.white)
            .frame(width: layout.panelSize.width, height: layout.panelSize.height + (model.banner == nil ? 0 : 18 * scale))
            .background {
                GlassSurface(shape: RoundedRectangle(cornerRadius: 30 * scale), style: config.workspaceSidebar.chromeStyle, solidColor: config.workspaceSidebar.resolvedSolidChromeColor)
            }
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
    }
}
