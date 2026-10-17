import AppKit
import SwiftUI

struct TileView: View {
    @Environment(\.lensTheme) private var theme
    let entry: TileEntry
    let kind: TileKind
    let presentation: String
    let metrics: TileMetrics
    let size: CGSize
    let settings: LensConfig
    let selected: Bool
    let marked: Bool
    let hint: String?
    var pictureSize: CGSize? = nil
    var controlsVisible = false
    var workspaceHint: String? = nil
    var hintsShown = false
    @State private var frozenBadgeHeight: CGFloat = 0
    var pictureBackingRequired: Bool {
        hintsShown && ThumbnailAppearance(frozen: entry.frozen, look: settings.frozenThumbnail, capturedAt: nil, now: Date()).opacity < 1
    }

    private var miniature: Bool { presentation == "miniatures" }
    private var row: Bool { presentation == "list" }
    private var line: Bool { kind == .text || row }
    private var selectionRing: CGFloat { miniature ? metrics.miniatureRing : metrics.selectionRing }
    private var radius: CGFloat { miniature ? metrics.miniatureRadius : line ? metrics.textRadius : metrics.radius }
    var extremeAspect: Bool { !line && !miniature && (entry.aspect < 0.3 || entry.aspect > 3.6) }

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                drawing
                    .frame(width: size.width, height: size.height)
                    .background(selected && !miniature && !extremeAspect ? (line ? theme.selectionPlate : theme.fill(0.16)) : .clear, in: RoundedRectangle(cornerRadius: radius))
                    .overlay {
                        if selected && !line && !extremeAspect {
                            RoundedRectangle(cornerRadius: radius).inset(by: -selectionRing / 2).stroke(theme.selectionRing, lineWidth: selectionRing)
                        }
                        if entry.accessory && !extremeAspect {
                            RoundedRectangle(cornerRadius: radius).stroke(theme.line(0.65), style: StrokeStyle(lineWidth: metrics.scale, dash: [4 * metrics.scale, 3 * metrics.scale]))
                        }
                    }
                    .shadow(color: .black.opacity(selected && !line ? (miniature ? 0.5 : 0.4) : 0), radius: miniature ? metrics.miniatureShadowRadius : metrics.selectionShadowRadius, y: miniature ? metrics.miniatureShadowY : metrics.selectionShadowY)
                    .scaleEffect(selected && !line && !miniature ? metrics.selectionScale : 1)
                    .animation(.easeOut(duration: 0.16), value: selected)
                    .allowsHitTesting(false)
            }
            .foregroundStyle(theme.text)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var drawing: some View {
        if miniature {
            picture(in: size)
        } else if line {
            HStack(spacing: row && kind != .text ? metrics.rowGap : metrics.gap) {
                if kind != .text {
                    picture(in: CGSize(width: metrics.listPictureWidth, height: size.height - 2 * metrics.rowVerticalPadding))
                        .frame(width: metrics.listPictureWidth)
                }
                bar
            }
            .padding(.horizontal, metrics.rowHorizontalPadding)
        } else {
            let rect = tilePictureRect(entry: entry, kind: kind, size: size, pictureSize: pictureSize, metrics: metrics,
                                       presentation: presentation, selected: selected)
            ZStack(alignment: .topLeading) {
                if kind == .card {
                    bar.frame(width: max(1, size.width - 2 * metrics.padding), height: metrics.barHeight)
                        .position(x: size.width / 2, y: metrics.padding + metrics.barHeight / 2)
                }
                picture(in: rect.size, fittedSize: rect.size)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: metrics.gap) {
            icon(size: metrics.icon)
            if line && entry.appCount == nil {
                TileBarTextLayout(gap: metrics.gap) {
                    title
                    Text(lensHighlightedText(entry.appName, ranges: entry.appRanges))
                        .font(.system(size: metrics.appFont)).foregroundStyle(theme.ink(0.62))
                        .lineLimit(1).truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            } else {
                title.frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            }
            TileChips(entry: entry, metrics: metrics, enabled: settings.badges)
            if marked { Image(systemName: "checkmark.circle.fill") }
            if entry.accessory && line { chip("menu-bar app") }
            if line {
                if let hint { label(hint) }
            }
        }
    }

    private var title: some View {
        Text(lensHighlightedText(entry.displayTitle, ranges: entry.displayTitleRanges))
            .font(.system(size: metrics.titleFont, weight: selected ? .semibold : .regular))
            .foregroundStyle(theme.ink(selected ? 1 : 0.62))
            .lineLimit(1).truncationMode(.middle)
    }

    private func chip(_ text: String) -> some View {
        TileChip(text: text, metrics: metrics)
    }

    /// A label over a window picture keeps the dark plate in both appearances: the picture under it can be any colour.
    private func label(_ text: String, onPicture: Bool = false) -> some View {
        let plate = onPicture ? LensTheme.dark : theme
        return Text(text).font(.system(size: metrics.chipFont))
            .foregroundStyle(plate.text)
            .padding(.vertical, metrics.labelVerticalPadding).padding(.horizontal, metrics.labelHorizontalPadding)
            .background(plate.badgePlate(0.72), in: RoundedRectangle(cornerRadius: metrics.chipRadius))
            .fixedSize()
    }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if let icon = entry.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size) }
        else { Image(systemName: "macwindow").resizable().scaledToFit().frame(width: size, height: size) }
    }

    func fittedPicture(in available: CGSize) -> CGSize {
        tileFittedPicture(entry: entry, available: available, pictureSize: pictureSize, metrics: metrics,
                          presentation: presentation, selected: selected, line: line)
    }

    private func picture(in available: CGSize, fittedSize: CGSize? = nil) -> some View {
        let fitted = fittedSize ?? fittedPicture(in: available)
        return ZStack {
            Group {
                if let thumbnail = entry.picture {
                    TilePicture(thumbnail: thumbnail, icon: entry.icon, frozen: entry.frozen, look: settings.frozenThumbnail, metrics: metrics, backed: pictureBackingRequired, badgeHeight: $frozenBadgeHeight)
                } else { icon(size: min(fitted.width, fitted.height)) }
            }
            .frame(width: fitted.width, height: fitted.height)
            .clipShape(RoundedRectangle(cornerRadius: miniature ? metrics.miniaturePictureRadius : metrics.pictureRadius))
            .shadow(color: .black.opacity(miniature ? 0 : 0.35), radius: metrics.pictureShadowRadius, y: metrics.pictureShadowY)
            .overlay {
                if selected && !line && extremeAspect {
                    RoundedRectangle(cornerRadius: metrics.pictureRadius).stroke(theme.selectionRing, lineWidth: selectionRing)
                }
                if entry.accessory && extremeAspect {
                    RoundedRectangle(cornerRadius: metrics.pictureRadius).stroke(theme.line(0.65), style: StrokeStyle(lineWidth: metrics.scale, dash: [4 * metrics.scale, 3 * metrics.scale]))
                }
                if miniature {
                    RoundedRectangle(cornerRadius: metrics.miniaturePictureRadius).stroke(theme.line(0.35), lineWidth: metrics.scale)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3 * metrics.scale) {
                    if miniature || kind == .picture && !row {
                        icon(size: miniature ? metrics.miniatureIcon : metrics.pictureIcon)
                            .shadow(color: .black.opacity(0.5), radius: metrics.iconShadowRadius, y: metrics.iconShadowY)
                    }
                    if entry.accessory && !line { label("menu-bar app", onPicture: true) }
                }.padding(miniature ? metrics.miniatureIconInset : metrics.pictureIconInset)
            }
            .overlay(alignment: .bottomTrailing) {
                if let workspaceHint, !line && !miniature {
                    Text(workspaceHint).font(.system(size: 13 * metrics.scale, weight: .bold))
                        .padding(.vertical, 2 * metrics.scale).padding(.horizontal, 8 * metrics.scale)
                        .foregroundStyle(LensTheme.dark.text)
                        .background(LensTheme.dark.badgePlate(0.72), in: RoundedRectangle(cornerRadius: 6 * metrics.scale))
                        .padding(.trailing, 8 * metrics.scale)
                        .padding(.bottom, LensHintGeometry.workspaceChipBottomInset(badgeHeight: frozenBadgeHeight, scale: metrics.scale))
                }
            }
            .overlay(alignment: .topLeading) {
                if controlsVisible && !line && !miniature {
                    TileWindowControls(entry: entry, pictureSize: fitted, scale: metrics.scale)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: metrics.adornmentGap) {
                    if marked && !row && kind != .card { Image(systemName: "checkmark.circle.fill").foregroundStyle(LensTheme.dark.text) }
                    if let hint, !line { label(hint, onPicture: true) }
                }.padding(metrics.gap)
            }
        }
        .frame(width: available.width, height: available.height)
    }
}

private struct TileBarTextLayout: SwiftUI.Layout {
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let title = subviews[0].sizeThatFits(.unspecified)
        let app = subviews[1].sizeThatFits(.unspecified)
        return CGSize(width: proposal.width ?? title.width + gap + app.width, height: max(title.height, app.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = tileBarTextWidths(available: bounds.width - gap,
                                       titleIdeal: subviews[0].sizeThatFits(.unspecified).width,
                                       appIdeal: subviews[1].sizeThatFits(.unspecified).width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: widths.title, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.maxX - widths.app, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: widths.app, height: bounds.height))
    }
}

private struct TilePicture: View {
    @ObservedObject var thumbnail: WindowThumbnail
    let icon: NSImage?
    let frozen: Bool
    let look: String
    let metrics: TileMetrics
    /// An opaque plate behind a translucent picture, so thinned glass never shows the desk through it.
    let backed: Bool
    @Binding var badgeHeight: CGFloat

    var body: some View {
        let appearance = ThumbnailAppearance(frozen: frozen, look: look, capturedAt: thumbnail.capturedAt, now: Date())
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnail.image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
                    .saturation(appearance.saturation).colorMultiply(Color(white: appearance.brightness)).opacity(appearance.opacity)
                    .background { if backed { config.workspaceSidebar.resolvedSolidChromeColor } }
            } else if let icon { Image(nsImage: icon).resizable().scaledToFit() }
            else { Image(systemName: "macwindow").resizable().scaledToFit() }
            Group {
                if appearance.badge == "pause" {
                    Image(systemName: "pause.fill").padding(4 * metrics.scale).background(.black.opacity(0.6))
                } else if frozen && look == "age-badge", let date = thumbnail.capturedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(ThumbnailAppearance(frozen: true, look: look, capturedAt: date, now: context.date).badge ?? "")
                            .font(.system(size: 10 * metrics.scale)).padding(3 * metrics.scale).background(.black.opacity(0.6))
                    }
                } else { Color.clear.frame(width: 0, height: 0) }
            }
            .foregroundStyle(LensTheme.dark.text)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { badgeHeight = $0 }
        }
    }
}

struct TileChips: View {
    let entry: TileEntry
    let metrics: TileMetrics
    let enabled: Bool
    var includeWorkspace = true

    var body: some View {
        HStack(spacing: metrics.chipGap) {
            ForEach(Array(entry.chips(enabled: enabled, includeWorkspace: includeWorkspace).enumerated()), id: \.offset) { _, text in
                TileChip(text: text, metrics: metrics)
            }
        }
    }
}

private struct TileChip: View {
    @Environment(\.lensTheme) private var theme
    let text: String
    let metrics: TileMetrics

    var body: some View {
        Text(text).font(.system(size: metrics.chipFont, weight: .semibold))
            .padding(.vertical, metrics.chipVerticalPadding).padding(.horizontal, metrics.chipHorizontalPadding)
            .background(theme.chip, in: RoundedRectangle(cornerRadius: metrics.chipRadius))
            .fixedSize()
    }
}
