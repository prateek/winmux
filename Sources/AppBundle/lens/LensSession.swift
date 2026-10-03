import AppKit
import Common
import HotKey

@MainActor
final class LensSession: ObservableObject {
    let name: String
    private(set) var settings: LensConfig
    let items: [SwitcherPaletteItem]
    @Published var query: String {
        didSet {
            guard query != oldValue else { return }
            if query.hasPrefix("="), !oldValue.hasPrefix("=") {
                inlineIds = Set(filterSwitcherPaletteItems(items, query: oldValue).map(\.id))
            }
            if !query.hasPrefix("=") { searchError = nil }
            selection = 0
            onSearchChanged?()
        }
    }
    @Published var selection: Int
    @Published private(set) var marks: [UInt32] = []
    @Published private(set) var searchError: String?
    @Published var banner: String?
    @Published var summonHeld = false
    private var inlineIds: Set<UInt32>?
    private let keyBindings: [(name: String, code: UInt16, modifiers: NSEvent.ModifierFlags)]
    var onSearchChanged: (() -> Void)?
    var onAction: ((String) -> Void)?

    init(name: String, settings: LensConfig, items: [SwitcherPaletteItem], search: String) {
        self.name = name
        self.settings = settings
        self.items = items
        keyBindings = settings.keys.keys.sorted().compactMap { name in
            if case .success(let (modifiers, key)) = parseBinding(name, .emptyRoot, config.keyMapping.resolve()) {
                return (name, UInt16(key.carbonKeyCode), modifiers)
            }
            return nil
        }
        query = search
        selection = 0
        selection = results.count > 1 && results.first?.isFocused == true ? 1 : 0
    }

    var results: [SwitcherPaletteItem] {
        let windows = query.hasPrefix("=") ? items.filter { inlineIds?.contains($0.id) ?? true } : filterSwitcherPaletteItems(items, query: query)
        guard settings.entries == "app" else { return windows }
        var seen: Set<String> = []
        return windows.filter { seen.insert($0.appIdentity).inserted }.map { representative in
            windows.filter { $0.appIdentity == representative.appIdentity }.max {
                $0.lastFocusedSeq == $1.lastFocusedSeq ? $0.id > $1.id : $0.lastFocusedSeq < $1.lastFocusedSeq
            } ?? representative
        }
    }

    var selectedId: UInt32? { results.indices.contains(selection) ? results[selection].id : nil }

    func key(for event: NSEvent, click: Bool = false) -> String? {
        let code: UInt16 = click || event.keyCode == 76 ? 36 : event.keyCode
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        return keyBindings.first { $0.code == code && $0.modifiers == modifiers }?.name
    }

    func moveSelection(_ delta: Int) { selection = min(max(selection + delta, 0), max(results.count - 1, 0)) }
    func hover(_ id: UInt32) { if let index = results.firstIndex(where: { $0.id == id }) { selection = index } }
    func toggleMark() {
        guard let id = selectedId else { return }
        if let index = marks.firstIndex(of: id) { marks.remove(at: index) } else { marks.append(id) }
    }
    func commands(for key: String) -> [String] { settings.keys[key] ?? [] }
    func targets(for key: String) -> [UInt32] {
        targets(forCommand: commands(for: key).first ?? "")
    }
    func targets(forCommand command: String) -> [UInt32] {
        let focusesSelection = command == "focus" || command.hasPrefix("focus ")
        return focusesSelection || marks.isEmpty ? selectedId.map { [$0] } ?? [] : marks
    }
    func acceptInlineResult(_ ids: [UInt32]) {
        inlineIds = Set(ids)
        searchError = nil
        selection = min(selection, max(results.count - 1, 0))
        objectWillChange.send()
    }
    func rejectInlineResult(_ error: String) { searchError = error.components(separatedBy: .newlines).first }
    func changePresentation(_ presentation: String) { settings.presentation = presentation; objectWillChange.send() }
}
