import SwiftUI

struct WindowDropIntentOverlayView: View {
    let model: WindowDropIntentOverlayModel

    private let borderLineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(WindowIntentPreviewPalette.gridBaseFill)

            if model.activeZone == nil {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: wholeZoneIconSize, weight: .semibold))
                    .foregroundStyle(WindowIntentPreviewPalette.gridSymbol(isActive: true))
                labelBadge
                    .frame(
                        width: model.targetFrame.width,
                        height: model.targetFrame.height,
                        alignment: .topLeading
                    )
            } else {
                ForEach(localZones) { zone in
                    dropZoneView(zone)
                }

                WindowIntentPreviewGridLines()
                    .stroke(
                        WindowIntentPreviewPalette.gridLineStroke,
                        style: StrokeStyle(lineWidth: borderLineWidth, lineCap: .butt, lineJoin: .miter)
                    )
                labelBadge
                    .frame(
                        width: model.targetFrame.width,
                        height: model.targetFrame.height,
                        alignment: .topLeading
                    )
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WindowIntentPreviewPalette.gridOuterStroke, lineWidth: borderLineWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: model.targetFrame.width, height: model.targetFrame.height)
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat {
        model.cornerRadius ?? min(max(min(model.targetFrame.width, model.targetFrame.height) * 0.018, 10), 14)
    }

    private var localZones: [WindowIntentZone] {
        WindowIntentZoneBuilder.zones(in: Rect(
            topLeftX: 0,
            topLeftY: 0,
            width: model.targetFrame.width,
            height: model.targetFrame.height
        ))
    }

    private var wholeZoneIconSize: CGFloat {
        min(max(min(model.targetFrame.width, model.targetFrame.height) * 0.16, 28), 72)
    }

    @ViewBuilder
    private var labelBadge: some View {
        if let label = model.label?.nonEmptyString {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: labelFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let detail = model.detail?.nonEmptyString {
                    Text(detail)
                        .font(.system(size: detailFontSize, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, labelHorizontalPadding)
            .padding(.vertical, labelVerticalPadding)
            .frame(maxWidth: labelMaxWidth, alignment: .leading)
            .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
            .padding(.leading, labelOuterPadding)
            .padding(.top, labelOuterPadding)
        }
    }

    private var labelOuterPadding: CGFloat {
        min(max(min(model.targetFrame.width, model.targetFrame.height) * 0.018, 12), 24)
    }

    private var labelHorizontalPadding: CGFloat {
        min(max(model.targetFrame.width * 0.014, 12), 18)
    }

    private var labelVerticalPadding: CGFloat {
        min(max(model.targetFrame.height * 0.008, 8), 12)
    }

    private var labelFontSize: CGFloat {
        min(max(min(model.targetFrame.width, model.targetFrame.height) * 0.028, 18), 32)
    }

    private var detailFontSize: CGFloat {
        min(max(labelFontSize * 0.62, 12), 18)
    }

    private var labelMaxWidth: CGFloat {
        min(max(model.targetFrame.width - labelOuterPadding * 2, 120), 620)
    }

    private func dropZoneView(_ zone: WindowIntentZone) -> some View {
        let isActive = zone.zone == model.activeZone
        return ZStack {
            Rectangle()
                .fill(WindowIntentPreviewPalette.gridZoneFill(isActive: isActive))
            if let name = symbolName(for: zone.zone) {
                Image(systemName: name)
                    .font(.system(size: iconSize(for: zone.frame), weight: .semibold))
                    .foregroundStyle(WindowIntentPreviewPalette.gridSymbol(isActive: isActive))
            }
        }
        .frame(width: zone.frame.width, height: zone.frame.height)
        .position(x: zone.frame.center.x, y: zone.frame.center.y)
    }

    private func symbolName(for zone: WindowDropZone) -> String? {
        switch zone {
            case .left:
                "arrow.left"
            case .right:
                "arrow.right"
            case .top:
                "arrow.up"
            case .bottom:
                "arrow.down"
            case .middle:
                "arrow.left.arrow.right"
            case .tab:
                "rectangle.3.group"
        }
    }

    private func iconSize(for frame: Rect) -> CGFloat {
        min(max(min(frame.width, frame.height) * 0.45, 14), 48)
    }
}

private extension String {
    var nonEmptyString: String? {
        isEmpty ? nil : self
    }
}
