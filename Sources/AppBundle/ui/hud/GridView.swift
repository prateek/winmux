import AppKit
import SwiftUI

struct GridView: View {
    @ObservedObject var model: LensSession
    @FocusState private var searchFocused: Bool

    var body: some View {
        let layout = model.gridLayout
        let items = model.results
        let scale = model.tileMetrics.scale
        let metrics = TileMetrics(visibleSize: CGSize(width: 1920 * layout.tileScale, height: 1080 * layout.tileScale))
        let summonAvailable = model.stripSummonAvailable(items: items)
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let tile = layout.tiles[index]
                TileView(entry: item.tile, kind: model.tileKind, presentation: "grid", metrics: metrics, size: tile.frame.size,
                         settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
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
            HStack(spacing: 8 * scale) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.62))
                TextField("Search windows…", text: Binding(get: { model.query }, set: { model.send(.searchChanged($0)) }))
                    .textFieldStyle(.plain).focused($searchFocused)
            }
            .font(.system(size: 16 * scale)).padding(.horizontal, 28 * scale)
            .frame(width: layout.panelSize.width, height: 36 * scale)
            VStack(spacing: 3 * scale) {
                if items.indices.contains(model.selection) {
                    let selected = items[model.selection]
                    HStack(spacing: 8 * scale) {
                        Text(selected.tile.displayTitle).fontWeight(.semibold).lineLimit(1)
                        if model.tileKind == .picture {
                            TileChips(entry: selected.tile, metrics: model.tileMetrics, enabled: model.settings.badges)
                        }
                        Text((selected.tile.footerAppName.map { "· \($0) " } ?? "") + "· \(model.selection + 1) of \(items.count)")
                            .foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    }
                } else { Text("No windows") }
                if let error = model.searchError ?? model.banner {
                    Text(error.components(separatedBy: .newlines).first ?? error).font(.system(size: 11 * scale)).foregroundStyle(.orange).lineLimit(1)
                }
            }
            .font(.system(size: 15 * scale)).padding(.horizontal, 28 * scale)
            .frame(width: layout.panelSize.width, height: 46 * scale)
            .position(x: layout.panelSize.width / 2, y: layout.panelSize.height - 25 * scale)
        }
        .foregroundStyle(.white)
        .frame(width: layout.panelSize.width, height: layout.panelSize.height)
        .background {
            GlassSurface(shape: RoundedRectangle(cornerRadius: 30 * scale), style: config.workspaceSidebar.chromeStyle,
                         solidColor: config.workspaceSidebar.resolvedSolidChromeColor)
        }
        .overlay {
            if model.searchError != nil { RoundedRectangle(cornerRadius: 30 * scale).stroke(.orange, lineWidth: 1) }
        }
        .onAppear { searchFocused = true }
    }
}

struct GridLandingView: View {
    @ObservedObject var model: LensSession
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if model.stripSummonAvailable(items: model.results), let landing = model.miniatureLanding,
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
