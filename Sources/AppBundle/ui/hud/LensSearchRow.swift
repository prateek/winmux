import SwiftUI

struct LensSearchRow: View {
    @Environment(\.lensTheme) private var theme
    @ObservedObject var model: LensSession
    var placeholder = "Search windows…"

    var body: some View {
        if model.inputState == .search {
            TextField(placeholder, text: Binding(get: { model.query }, set: { model.send(.searchChanged($0)) }),
                      prompt: Text(placeholder).foregroundColor(theme.ink(0.62)))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.searchText)
        } else {
            Button { model.enterSearch() } label: {
                HStack {
                    Text(model.query.isEmpty ? placeholder : model.query).lineLimit(1)
                    Spacer()
                    Text("/").monospaced().padding(.horizontal, 6)
                        .background(theme.fill(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(theme.ink(0.45))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
