import SwiftUI

extension View {
    /// Makes a card row a drag source. Unlike a window row, a card has no backing macOS window to
    /// carry under the cursor, so the card drag is native SwiftUI drag-and-drop: it emits a
    /// `.card` payload that the reorder slots, column headers, and scene chips accept as drop
    /// targets. Every enabled column-deck section attaches this, including the implicit laptop deck.
    @ViewBuilder
    func workspaceSidebarCardDrag(enabled: Bool, cardName: String) -> some View {
        if enabled {
            onDrag { WorkspaceSidebarDragPayload.card(cardName).itemProvider }
        } else {
            self
        }
    }
}
