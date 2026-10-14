import SwiftUI

struct LensSearchRow: View {
    @ObservedObject var model: LensSession

    var body: some View {
        if model.inputState == .search {
            TextField("Search windows…", text: Binding(get: { model.query }, set: { model.send(.searchChanged($0)) }),
                      prompt: Text("Search windows…").foregroundColor(.white.opacity(0.62)))
                .textFieldStyle(.plain)
                .foregroundStyle(.white.opacity(GlassToken.textPrimary))
        } else {
            Button { model.enterSearch() } label: {
                HStack {
                    Text(model.query.isEmpty ? "Search windows…" : model.query).lineLimit(1)
                    Spacer()
                    Text("/").monospaced().padding(.horizontal, 6)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(.white.opacity(0.45))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
