import SwiftUI

struct ZoneDividerOverlayView: View {
    let model: ZoneDividerOverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            activeBand
                .frame(width: bandWidth, height: model.workspaceRect.height)
                .position(x: model.localBoundaryX, y: model.workspaceRect.height / 2)

            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: model.workspaceRect.height)
                .position(x: model.localBoundaryX, y: model.workspaceRect.height / 2)

            label
                .position(x: labelX, y: labelY)
        }
        .frame(width: model.workspaceRect.width, height: model.workspaceRect.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var activeBand: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(lineColor.opacity(model.state == .hover ? 0.14 : 0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(lineColor.opacity(0.34), lineWidth: 1)
            )
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white.opacity(0.76))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: labelWidth, alignment: .leading)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }

    private var title: String {
        switch model.state {
            case .hover:
                "Zone divider"
            case .dragging:
                "\(model.leftName) | \(model.rightName)"
            case .committed:
                "Widths updated"
        }
    }

    private var detail: String {
        if let leftShare = model.leftShare, let rightShare = model.rightShare {
            return "\(model.leftName) \(percent(leftShare)) | \(model.rightName) \(percent(rightShare))"
        }
        return "Drag \(model.leftName) | \(model.rightName)"
    }

    private var lineColor: Color {
        switch model.state {
            case .hover:
                Color(nsColor: .systemTeal)
            case .dragging:
                Color(nsColor: .controlAccentColor)
            case .committed:
                Color(nsColor: .systemGreen)
        }
    }

    private var lineWidth: CGFloat {
        switch model.state {
            case .hover: 3
            case .dragging, .committed: 4
        }
    }

    private var bandWidth: CGFloat {
        zoneDividerVisibleBandWidth(for: model.state)
    }

    private var labelWidth: CGFloat {
        min(max(model.workspaceRect.width * 0.18, 220), 360)
    }

    private var labelX: CGFloat {
        let proposed = model.localBoundaryX + labelWidth / 2 + 18
        let maxX = model.workspaceRect.width - labelWidth / 2 - 14
        let minX = labelWidth / 2 + 14
        if proposed > maxX {
            return max(minX, model.localBoundaryX - labelWidth / 2 - 18)
        }
        return max(minX, proposed)
    }

    private var labelY: CGFloat {
        min(max(34, model.workspaceRect.height * 0.08), 68)
    }

    private func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}
