import AppKit
import SwiftUI

struct MiniaturesView: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession

    var body: some View {
        let layout = model.miniatureLayout
        let page = min(model.miniaturePage, layout.pageCount - 1)
        let frames = model.miniatureFrames(layout: layout)
        let results = model.results
        let matchedIds = Set(results.map(\.id))
        let selectedId = results.indices.contains(model.selection) ? results[model.selection].id : nil
        ZStack(alignment: .topLeading) {
            if model.settings.miniatures.blur { MiniatureBackdrop(material: theme.isDark ? .hudWindow : .underWindowBackground).allowsHitTesting(false) }
            theme.miniatureScrim.opacity(model.settings.miniatures.darkness).allowsHitTesting(false)
            ForEach(model.miniatureCells(on: page, layout: layout), id: \.workspace) { cell in
                workspaceCell(cell, selectedId: selectedId)
                let entries = miniatureDrawOrder(model.items.filter { $0.miniature?.workspace == cell.workspace })
                ForEach(entries) { item in
                    if item.miniature != nil, let frame = frames[item.id] {
                        TileView(entry: item.tile, kind: .picture, presentation: "miniatures", metrics: model.tileMetrics,
                                 size: CGSize(width: max(1, frame.width), height: max(1, frame.height)), settings: model.settings,
                                 selected: selectedId == item.id, marked: model.marks.contains(item.id),
                                 hint: model.summonLabel(for: item.id, destination: focus.workspace.name),
                                 pictureSize: item.miniature?.tab == nil ? nil : frame.size)
                            // A dimmed Frozen picture would otherwise show the tabs behind it through the front tab
                            .background {
                                if item.miniature?.tab != nil {
                                    RoundedRectangle(cornerRadius: model.tileMetrics.miniaturePictureRadius).fill(Color.black)
                                }
                            }
                            .opacity(matchedIds.contains(item.id) ? 1 : 0.18)
                            .onTapGesture {
                                model.hover(item.id)
                                if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                            }
                            .position(x: frame.midX, y: frame.midY - CGFloat(page) * model.miniatureSize.height)
                    }
                }
            }
            LensHintOverlay(model: model, panelBottom: model.miniatureSize.height)
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    LensSearchRow(model: model, placeholder: "\(model.name) • / to Search")
                    Spacer()
                    Text("\(page + 1) / \(layout.pageCount)").monospacedDigit()
                }
                if let error = model.searchError ?? model.banner { Text(error).foregroundStyle(.orange).font(.caption) }
            }
            .padding(14).background(theme.badgePlate(0.3)).frame(width: min(560, model.miniatureSize.width - 48))
            .position(x: model.miniatureSize.width / 2, y: 28)
        }
        .foregroundStyle(theme.text)
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            if case .active(let point) = phase { model.hoverMiniature(at: point, pointerLocation: NSEvent.mouseLocation) }
        }
    }

    @ViewBuilder
    private func workspaceCell(_ cell: MiniatureLayout.Cell, selectedId: UInt32?) -> some View {
        let workspace = model.miniatureWorkspaces.first { $0.name == cell.workspace }
        let current = workspace?.current == true
        RoundedRectangle(cornerRadius: 5)
            .fill(theme.fill(0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 5).stroke(
                    current && model.settings.miniatures.currentWorkspace != "plain" ? theme.selectionRing : theme.line(0.3), lineWidth: current ? 2 : 1)
            }
            .frame(width: cell.frame.width, height: cell.frame.height)
            .position(x: cell.frame.midX, y: cell.frame.midY)
        Text(workspace?.title ?? cell.workspace).font(.system(size: 12, weight: .semibold))
            .position(x: cell.frame.midX, y: cell.frame.minY - 12)
        if let selected = model.items.first(where: { $0.id == selectedId && $0.miniature?.workspace == cell.workspace }) {
            HStack(spacing: model.tileMetrics.gap) {
                Text(selected.tile.displayTitle).font(.system(size: 12)).lineLimit(1)
                TileChips(entry: selected.tile, metrics: model.tileMetrics, enabled: model.settings.badges, includeWorkspace: false)
            }
                .frame(width: cell.frame.width)
                .position(x: cell.frame.midX, y: cell.tray.maxY + 12)
        }
        if model.summonHintsShown, current {
            if model.settings.summonHints.contains("target-workspace") {
                Rectangle().stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: cell.frame.width, height: cell.frame.height).position(x: cell.frame.midX, y: cell.frame.midY)
            }
            if model.settings.summonHints.contains("landing-spot"), let landing = model.miniatureLandingFrame(in: cell) {
                Rectangle().stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height).position(x: landing.midX, y: landing.midY)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct MiniatureBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = material
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.material = material }
}
