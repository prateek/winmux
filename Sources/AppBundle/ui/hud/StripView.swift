import AppKit
import SwiftUI

struct StripView: View {
    @ObservedObject var model: LensSession

    var body: some View {
        let snapshot = model.stripSnapshot
        let layout = snapshot.layout
        let items = snapshot.items
        let widths = snapshot.widths
        let height = model.tileMetrics.height(kind: model.tileKind, rowHeight: snapshot.rowHeight)
        let summonAvailable = model.stripSummonAvailable(items: items)
        ZStack {
            if summonAvailable, let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 24 * model.tileMetrics.scale) {
                HStack(spacing: model.tileMetrics.stripGap) {
                    ForEach(Array(layout.range), id: \.self) { index in
                        let item = items[index]
                        TileView(entry: item.tile, kind: model.tileKind, presentation: "strip", metrics: model.tileMetrics,
                                 size: CGSize(width: widths[index], height: height),
                                 settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                                 hint: index == model.selection && summonAvailable && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil)
                        .zIndex(index == model.selection ? 1 : 0)
                        .onContinuousHover { phase in
                            if case .active = phase { model.hover(item.id, at: NSEvent.mouseLocation) }
                        }
                        .onTapGesture {
                            model.hover(item.id)
                            if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                        }
                    }
                }
                .overlay(alignment: .leading) {
                    if layout.before > 0 { Text("+\(layout.before)").offset(x: -32 * model.tileMetrics.scale) }
                }
                .overlay(alignment: .trailing) {
                    if layout.after > 0 { Text("+\(layout.after)").offset(x: 32 * model.tileMetrics.scale) }
                }
                if items.indices.contains(model.selection) {
                    let selected = items[model.selection]
                    HStack(spacing: model.tileMetrics.gap) {
                        Text(selected.tile.displayTitle).fontWeight(.semibold).foregroundStyle(.white).lineLimit(1)
                        if model.tileKind == .picture {
                            TileChips(entry: selected.tile, metrics: model.tileMetrics, enabled: model.settings.badges)
                        }
                        Text((selected.tile.footerAppName.map { "· \($0) " } ?? "") + "· \(model.selection + 1) of \(items.count)")
                            .foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    }
                    .font(.system(size: 15 * model.tileMetrics.scale))
                } else {
                    Text("No windows").font(.system(size: 15 * model.tileMetrics.scale))
                }
                if let banner = model.banner { Text(banner).font(.caption).foregroundStyle(.orange) }
            }
            .padding(.horizontal, 44 * model.tileMetrics.scale)
            .padding(.top, 26 * model.tileMetrics.scale)
            .padding(.bottom, 22 * model.tileMetrics.scale)
            .foregroundStyle(.white)
            .background {
                GlassSurface(shape: RoundedRectangle(cornerRadius: 30 * model.tileMetrics.scale), style: config.workspaceSidebar.chromeStyle, solidColor: config.workspaceSidebar.resolvedSolidChromeColor)
            }
            .frame(width: max(layout.rowWidth, snapshot.minimumWidth))
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
    }
}
