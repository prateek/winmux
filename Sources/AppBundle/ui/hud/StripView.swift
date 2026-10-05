import AppKit
import SwiftUI

struct StripView: View {
    @ObservedObject var model: LensSession

    var body: some View {
        let layout = model.stripLayout
        let items = model.results
        let widths = model.stripWidths
        let height = model.tileMetrics.height(kind: model.tileKind, rowHeight: model.stripRowHeight)
        ZStack {
            if model.stripSummonAvailable, let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 24 * model.tileMetrics.scale) {
                HStack(spacing: model.tileMetrics.stripGap) {
                    if items.isEmpty { Text("No windows").frame(width: 330 * model.tileMetrics.scale, height: model.tileMetrics.textHeight) }
                    ForEach(Array(layout.range), id: \.self) { index in
                        let item = items[index]
                        TileView(entry: item.tile, kind: model.tileKind, presentation: "strip", metrics: model.tileMetrics,
                                 size: CGSize(width: widths[index], height: height),
                                 settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                                 hint: index == model.selection && model.stripSummonAvailable && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil)
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
                    (Text(selected.title.isEmpty ? selected.appName : selected.title).fontWeight(.semibold).foregroundColor(.white)
                     + Text(" · \(selected.appName) · \(model.selection + 1) of \(items.count)").foregroundColor(.white.opacity(0.62)))
                        .font(.system(size: 15 * model.tileMetrics.scale)).lineLimit(1)
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
            .frame(width: layout.rowWidth)
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
    }
}
