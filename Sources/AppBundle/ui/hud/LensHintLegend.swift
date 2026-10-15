import SwiftUI

struct LensHintLegend: View {
    private let theme = LensTheme.dark
    let entries: [LensHintEntry]
    let scale: CGFloat
    let maxWidth: CGFloat
    var body: some View {
        ViewThatFits(in: .horizontal) {
            legend.fixedSize()
            legend
        }
        .frame(maxWidth: maxWidth)
        .frame(height: 36 * scale)
        .allowsHitTesting(false)
    }

    private var legend: some View {
        HStack(spacing: 18 * scale) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 6 * scale) {
                    ForEach(Array(entry.chords.enumerated()), id: \.offset) { _, chord in
                        Text(chord).fixedSize().font(.system(size: 13 * scale, weight: .semibold))
                            .padding(.vertical, 2 * scale).padding(.horizontal, 7 * scale)
                            .background(theme.fill(0.18), in: RoundedRectangle(cornerRadius: 5 * scale))
                    }
                    Text(entry.phrase).font(.system(size: 15 * scale)).lineLimit(1).truncationMode(.tail)
                }
            }
        }
        .foregroundStyle(theme.text)
        .padding(.vertical, 9 * scale).padding(.horizontal, 18 * scale)
        .background(Color(red: 10 / 255, green: 12 / 255, blue: 16 / 255).opacity(0.82), in: RoundedRectangle(cornerRadius: 12 * scale))
    }
}

struct LensHintOverlay: View {
    @ObservedObject var model: LensSession
    let panelBottom: CGFloat
    var body: some View {
        let scale = model.tileMetrics.scale
        let sidebarInset = LensHintGeometry.sidebarClearance(presentation: model.settings.presentation,
                                                            monitorInset: focus.workspace.workspaceMonitor.workspaceSidebarInset, scale: scale)
        VStack(spacing: 0) {
            if model.hintsShown, !model.hintLegend.isEmpty {
                LensHintLegend(entries: model.hintLegend, scale: scale, maxWidth: LensHintGeometry.legendMaxWidth(screenWidth: model.miniatureSize.width, scale: scale, occupiedSideInset: sidebarInset))
            }
        }
        .frame(maxWidth: model.miniatureSize.width)
        .position(x: model.miniatureSize.width / 2,
                  y: LensHintGeometry.legendTop(panelBottom: panelBottom, screenHeight: model.miniatureSize.height, legendHeight: 36 * scale, scale: scale) + 18 * scale)
        .allowsHitTesting(false)
    }
}
