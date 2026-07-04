import SwiftUI

extension View {
    /// Makes a card row a drag source. Unlike a window row, a card has no backing macOS window to
    /// carry under the cursor, so the card drag is native SwiftUI drag-and-drop: it emits a
    /// `.card` payload that the reorder slots, column headers, and scene chips accept as drop
    /// targets. Only the configured column-deck sections attach this; the implicit laptop list does
    /// not, so its rows stay exactly as before.
    @ViewBuilder
    func workspaceSidebarCardDrag(enabled: Bool, cardName: String) -> some View {
        if enabled {
            onDrag { WorkspaceSidebarDragPayload.card(cardName).itemProvider }
        } else {
            self
        }
    }
}
