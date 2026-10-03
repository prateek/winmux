import AppKit
import SwiftUI

struct StripView: View {
    @ObservedObject var model: LensSession

    var body: some View {
        let layout = model.stripLayout
        let items = model.results
        ZStack {
            if model.stripSummonAvailable, let landing = model.miniatureLanding,
               let current = model.miniatureWorkspaces.first(where: \.current) {
                Rectangle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX - current.source.minX, y: landing.midY - current.source.minY)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 8) {
                HStack(spacing: StripLayout.gap) {
                    Text(layout.before > 0 ? "+\(layout.before)" : "").frame(width: 24)
                    if items.isEmpty { Text("No windows").frame(width: StripLayout.entryWidth, height: StripLayout.entryHeight) }
                    ForEach(Array(layout.range), id: \.self) { index in
                        let item = items[index]
                        VStack(spacing: 6) {
                            if let entry = item.miniature {
                                let actual = entry.accessory && model.settings.accessoryWindow == "actual-size"
                                let scale = min(1, entry.frame.width / max(1, model.miniatureSize.width))
                                MiniatureEntryView(item: item, entry: entry, settings: model.settings,
                                                   selected: index == model.selection, marked: model.marks.contains(item.id),
                                                   hint: index == model.selection && model.stripSummonAvailable && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil)
                                    .frame(width: actual ? max(32, StripLayout.entryWidth * scale) : StripLayout.entryWidth, height: actual ? max(28, 92 * scale) : 92)
                                    .frame(width: StripLayout.entryWidth, height: 92)
                            } else {
                                Image(systemName: "macwindow").frame(width: StripLayout.entryWidth, height: 92)
                            }
                            Text(item.title.isEmpty ? item.appName : item.title).font(.system(size: 11)).lineLimit(1)
                        }
                        .padding(4)
                        .frame(width: StripLayout.entryWidth, height: StripLayout.entryHeight)
                        .background(index == model.selection ? Color.accentColor.opacity(0.22) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            if case .active = phase { model.hover(item.id, at: NSEvent.mouseLocation) }
                        }
                        .onTapGesture {
                            model.hover(item.id)
                            if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                        }
                    }
                    Text(layout.after > 0 ? "+\(layout.after)" : "").frame(width: 24)
                }
                Text("\(model.name) · \(items.isEmpty ? 0 : model.selection + 1) of \(items.count)").font(.system(size: 11)).foregroundStyle(.secondary)
                if let banner = model.banner { Text(banner).font(.caption).foregroundStyle(.orange) }
            }
            .padding(12)
            .foregroundStyle(.white)
            .background {
                GlassSurface(shape: RoundedRectangle(cornerRadius: RadiusToken.panel), style: config.workspaceSidebar.chromeStyle, solidColor: config.workspaceSidebar.resolvedSolidChromeColor)
            }
            .frame(width: layout.rowWidth)
        }
        .frame(width: model.miniatureSize.width, height: model.miniatureSize.height)
    }
}
