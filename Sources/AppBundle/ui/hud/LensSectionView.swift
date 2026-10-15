import SwiftUI

struct LensSectionHeader: View {
    @Environment(\.lensTheme) private var theme
    let label: String
    let current: Bool
    let scale: CGFloat
    var body: some View {
        Text(label + (current ? "  · here" : ""))
            .font(.system(size: 15 * scale, weight: .semibold))
            .tracking(0.3 * scale)
            .foregroundStyle(theme.ink(current ? 1 : 0.62))
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
    }
}

struct LensGroupingControl: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession
    var body: some View {
        let scale = model.tileMetrics.scale
        HStack(spacing: 2 * scale) {
            Text("Group").padding(.trailing, 8 * scale)
            ForEach(model.visibleSectionValues, id: \.self) { value in
                Button { model.changeSections(value) } label: {
                    Text(value)
                        .fontWeight(model.settings.sections == value ? .semibold : .regular)
                        .foregroundStyle(theme.ink(model.settings.sections == value ? 1 : 0.62))
                        .padding(.horizontal, 11 * scale).padding(.vertical, 4 * scale)
                        .background(model.settings.sections == value ? theme.fill(0.16) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8 * scale))
                }
                .buttonStyle(.plain).focusable(false)
                .accessibilityLabel("Group by \(value)")
                .accessibilityValue(model.settings.sections == value ? "Selected" : "")
            }
            if let key = model.sectionsKey {
                Text(displayBindingNotation(key)).font(.system(size: 12 * scale, weight: .semibold))
                    .padding(.horizontal, 6 * scale).padding(.vertical, scale)
                    .background(theme.fill(0.16), in: RoundedRectangle(cornerRadius: 5 * scale))
                    .padding(.leading, 8 * scale)
            }
        }
        .font(.system(size: 14 * scale)).foregroundStyle(theme.ink(0.62))
        .fixedSize()
    }
}

struct LensSelectionFooter: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession
    let items: [SwitcherPaletteItem]
    var body: some View {
        if items.indices.contains(model.selection) {
            let selected = items[model.selection]
            HStack(spacing: model.tileMetrics.gap) {
                Text(lensHighlightedText(selected.tile.displayTitle, ranges: selected.tile.displayTitleRanges)).fontWeight(.semibold).foregroundStyle(theme.text).lineLimit(1)
                if model.tileKind == .picture {
                    TileChips(entry: selected.tile, metrics: model.tileMetrics, enabled: model.settings.badges)
                }
                if let app = selected.tile.footerAppName {
                    (Text("· ") + Text(lensHighlightedText(app, ranges: selected.tile.appRanges)))
                        .foregroundStyle(theme.ink(0.62)).lineLimit(1)
                }
                Text("· \(model.selection + 1) of \(items.count)")
                    .foregroundStyle(theme.ink(0.62)).lineLimit(1)
            }
            .font(.system(size: 15 * model.tileMetrics.scale))
        } else {
            Text("No windows").font(.system(size: 15 * model.tileMetrics.scale))
        }
    }
}
