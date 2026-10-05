import AppKit
import SwiftUI

struct MiniaturesView: View {
    @ObservedObject var model: LensSession
    @FocusState private var searchFocused: Bool

    var body: some View {
        let layout = model.miniatureLayout
        let page = min(model.miniaturePage, layout.pageCount - 1)
        let frames = model.miniatureFrames(layout: layout)
        let results = model.results
        let matchedIds = Set(results.map(\.id))
        let selectedId = results.indices.contains(model.selection) ? results[model.selection].id : nil
        ZStack(alignment: .topLeading) {
            if model.settings.miniatures.blur { MiniatureBackdrop().allowsHitTesting(false) }
            Color.black.opacity(model.settings.miniatures.darkness).allowsHitTesting(false)
            ForEach(model.miniatureCells(on: page, layout: layout), id: \.workspace) { cell in
                workspaceCell(cell, selectedId: selectedId)
                let entries = miniatureDrawOrder(model.items.filter { $0.miniature?.workspace == cell.workspace })
                ForEach(entries) { item in
                    if item.miniature != nil, let frame = frames[item.id] {
                        TileView(entry: item.tile, kind: .picture, presentation: "miniatures", metrics: model.tileMetrics,
                                 size: CGSize(width: max(1, frame.width), height: max(1, frame.height)), settings: model.settings,
                                 selected: selectedId == item.id, marked: model.marks.contains(item.id),
                                 hint: selectedId == item.id && model.summonHeld && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil)
                            .zIndex(selectedId == item.id ? 10 : 0)
                            .opacity(matchedIds.contains(item.id) ? 1 : 0.18)
                            .onContinuousHover { phase in
                                if case .active = phase { model.hover(item.id, at: NSEvent.mouseLocation) }
                            }
                            .onTapGesture {
                                model.hover(item.id)
                                if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                            }
                            .position(x: frame.midX, y: frame.midY - CGFloat(page) * model.miniatureSize.height)
                    }
                }
            }
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("\(model.name) • Type to Search", text: Binding(get: { model.query }, set: { model.send(.searchChanged($0)) }))
                        .textFieldStyle(.plain).focused($searchFocused)
                    Spacer()
                    Text("\(page + 1) / \(layout.pageCount)").monospacedDigit()
                }
                if let error = model.searchError ?? model.banner { Text(error).foregroundStyle(.orange).font(.caption) }
            }
            .padding(14).background(.black.opacity(0.3)).frame(width: min(560, model.miniatureSize.width - 48))
            .position(x: model.miniatureSize.width / 2, y: 28)
        }
        .foregroundStyle(.white)
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder
    private func workspaceCell(_ cell: MiniatureLayout.Cell, selectedId: UInt32?) -> some View {
        let workspace = model.miniatureWorkspaces.first { $0.name == cell.workspace }
        let current = workspace?.current == true
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.white.opacity(0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 5).stroke(
                    current && model.settings.miniatures.currentWorkspace != "plain" ? Color.accentColor : Color.white.opacity(0.3), lineWidth: current ? 2 : 1)
            }
            .frame(width: cell.frame.width, height: cell.frame.height)
            .position(x: cell.frame.midX, y: cell.frame.midY)
        Text(workspace?.title ?? cell.workspace).font(.system(size: 12, weight: .semibold))
            .position(x: cell.frame.midX, y: cell.frame.minY - 12)
        if let selected = model.items.first(where: { $0.id == selectedId && $0.miniature?.workspace == cell.workspace }) {
            Text(selected.title).font(.system(size: 12)).lineLimit(1)
                .frame(width: cell.frame.width)
                .position(x: cell.frame.midX, y: cell.tray.maxY + 12)
        }
        if model.summonHeld, current {
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

private struct MiniatureBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
