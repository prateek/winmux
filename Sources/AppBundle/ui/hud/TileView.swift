import AppKit
import SwiftUI

struct TileView: View {
    let entry: TileEntry
    let kind: TileKind
    let presentation: String
    let metrics: TileMetrics
    let size: CGSize
    let settings: LensConfig
    let selected: Bool
    let marked: Bool
    let hint: String?

    private var miniature: Bool { presentation == "miniatures" }
    private var row: Bool { presentation == "list" }
    private var line: Bool { kind == .text || row }
    private var selectionRing: CGFloat { miniature ? metrics.miniatureRing : metrics.selectionRing }
    private var radius: CGFloat { miniature ? metrics.miniatureRadius : line ? metrics.textRadius : metrics.radius }
    private var chips: [String] {
        entry.badges.chips(enabled: settings.badges) + ((!miniature ? entry.appCount : nil).map { ["\($0) windows"] } ?? [])
    }

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                drawing
                    .frame(width: size.width, height: size.height)
                    .background(selected && !miniature ? (line ? Color.accentColor.opacity(0.26) : Color.white.opacity(0.16)) : .clear, in: RoundedRectangle(cornerRadius: radius))
                    .overlay {
                        if selected && !line {
                            RoundedRectangle(cornerRadius: radius).inset(by: -selectionRing / 2).stroke(Color.accentColor, lineWidth: selectionRing)
                        }
                        if entry.accessory {
                            RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.65), style: StrokeStyle(lineWidth: metrics.scale, dash: [4 * metrics.scale, 3 * metrics.scale]))
                        }
                    }
                    .shadow(color: .black.opacity(selected && !line ? (miniature ? 0.5 : 0.4) : 0), radius: miniature ? metrics.miniatureShadowRadius : metrics.selectionShadowRadius, y: miniature ? metrics.miniatureShadowY : metrics.selectionShadowY)
                    .scaleEffect(selected && !line && !miniature ? metrics.selectionScale : 1)
                    .animation(.easeOut(duration: 0.16), value: selected)
                    .allowsHitTesting(false)
            }
            .foregroundStyle(.white)
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
            VStack(spacing: metrics.gap) {
                if kind == .card { bar.frame(height: metrics.barHeight) }
                picture(in: CGSize(width: max(1, size.width - 2 * metrics.padding), height: max(1, size.height - 2 * metrics.padding - (kind == .card ? metrics.barHeight + metrics.gap : 0))))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(metrics.padding)
        }
    }

    private var bar: some View {
        HStack(spacing: metrics.gap) {
            icon(size: metrics.icon)
            Text(entry.title.isEmpty ? entry.appName : entry.title)
                .font(.system(size: metrics.titleFont, weight: selected ? .semibold : .regular))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.62))
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            if line && entry.appCount == nil {
                Text(entry.appName).font(.system(size: metrics.appFont)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            chipLine
            if marked && kind != .text && (kind == .card || row) { Image(systemName: "checkmark.circle.fill") }
            if entry.accessory && kind == .text { chip("menu-bar app") }
            if kind == .text {
                if marked { Image(systemName: "checkmark.circle.fill") }
                if let hint { label(hint) }
            }
        }
    }

    private var chipLine: some View {
        HStack(spacing: metrics.chipGap) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, text in chip(text) }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: metrics.chipFont, weight: .semibold))
            .padding(.vertical, metrics.chipVerticalPadding).padding(.horizontal, metrics.chipHorizontalPadding)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: metrics.chipRadius))
            .fixedSize()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: metrics.chipFont))
            .padding(.vertical, metrics.labelVerticalPadding).padding(.horizontal, metrics.labelHorizontalPadding)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: metrics.chipRadius))
            .fixedSize()
    }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if let icon = entry.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size) }
        else { Image(systemName: "macwindow").resizable().scaledToFit().frame(width: size, height: size) }
    }

    private func picture(in available: CGSize) -> some View {
        let actual = presentation == "strip" && entry.accessory && settings.accessoryWindow == "actual-size"
        let pictureHeight = metrics.pictureHeight(rowHeight: available.height, accessory: entry.accessory, actualSize: actual, monitorHeightFraction: entry.monitorHeightFraction)
        let fitted = metrics.fittedPicture(aspect: entry.aspect, in: CGSize(width: available.width, height: pictureHeight))
        return ZStack {
            Group {
                if let thumbnail = entry.picture {
                    TilePicture(thumbnail: thumbnail, icon: entry.icon, frozen: entry.frozen, look: settings.frozenThumbnail, metrics: metrics)
                } else { icon(size: min(fitted.width, fitted.height)) }
            }
            .frame(width: fitted.width, height: fitted.height)
            .clipShape(RoundedRectangle(cornerRadius: miniature ? metrics.miniaturePictureRadius : metrics.pictureRadius))
            .shadow(color: .black.opacity(miniature ? 0 : 0.35), radius: metrics.pictureShadowRadius, y: metrics.pictureShadowY)
            .overlay {
                if miniature {
                    RoundedRectangle(cornerRadius: metrics.miniaturePictureRadius).stroke(.white.opacity(0.35), lineWidth: metrics.scale)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3 * metrics.scale) {
                    if miniature || kind == .picture && !row {
                        icon(size: miniature ? metrics.miniatureIcon : metrics.pictureIcon)
                            .shadow(color: .black.opacity(0.5), radius: metrics.iconShadowRadius, y: metrics.iconShadowY)
                    }
                    if entry.accessory { label("menu-bar app") }
                }.padding(miniature ? metrics.miniatureIconInset : metrics.pictureIconInset)
            }
            .overlay(alignment: .topLeading) {
                if miniature || kind == .picture && !row {
                    chipLine.padding(.horizontal, 4 * metrics.scale).padding(.top, metrics.pictureBadgeTop(hasHint: hint != nil))
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: metrics.adornmentGap) {
                    if marked && !row && kind != .card { Image(systemName: "checkmark.circle.fill") }
                    if let hint { label(hint) }
                }.padding(metrics.gap)
            }
        }
        .frame(width: available.width, height: available.height)
    }
}

private struct TilePicture: View {
    @ObservedObject var thumbnail: WindowThumbnail
    let icon: NSImage?
    let frozen: Bool
    let look: String
    let metrics: TileMetrics

    var body: some View {
        let appearance = ThumbnailAppearance(frozen: frozen, look: look, capturedAt: thumbnail.capturedAt, now: Date())
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnail.image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
                    .saturation(appearance.saturation).colorMultiply(Color(white: appearance.brightness)).opacity(appearance.opacity)
            } else if let icon { Image(nsImage: icon).resizable().scaledToFit() }
            else { Image(systemName: "macwindow").resizable().scaledToFit() }
            if appearance.badge == "pause" {
                Image(systemName: "pause.fill").padding(4 * metrics.scale).background(.black.opacity(0.6))
            }
            if frozen && look == "age-badge", let date = thumbnail.capturedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(ThumbnailAppearance(frozen: true, look: look, capturedAt: date, now: context.date).badge ?? "")
                        .font(.system(size: 10 * metrics.scale)).padding(3 * metrics.scale).background(.black.opacity(0.6))
                }
            }
        }
    }
}
