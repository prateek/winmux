import Foundation
import UniformTypeIdentifiers

let workspaceSidebarWindowDragPrefix = "window:"
let workspaceSidebarTabGroupDragPrefix = "tab-group:"
let workspaceSidebarCardDragPrefix = "card:"
let workspaceSidebarDragPayloadType = UTType(exportedAs: "dev.winmux.sidebar-drag-payload")

enum WorkspaceSidebarDragPayload: Equatable, Sendable {
    case window(UInt32)
    case tabGroup(UInt32)
    /// A whole card (workspace) dragged by name, so the drop reorders or transfers the card
    /// itself rather than moving a window into it.
    case card(String)

    var encodedValue: String {
        switch self {
            case .window(let windowId):
                "\(workspaceSidebarWindowDragPrefix)\(windowId)"
            case .tabGroup(let representativeWindowId):
                "\(workspaceSidebarTabGroupDragPrefix)\(representativeWindowId)"
            case .card(let cardName):
                "\(workspaceSidebarCardDragPrefix)\(cardName)"
        }
    }

    init?(encodedValue: String) {
        if encodedValue.hasPrefix(workspaceSidebarWindowDragPrefix),
           let rawValue = UInt32(encodedValue.dropFirst(workspaceSidebarWindowDragPrefix.count)) {
            self = .window(rawValue)
        } else if encodedValue.hasPrefix(workspaceSidebarTabGroupDragPrefix),
                  let rawValue = UInt32(encodedValue.dropFirst(workspaceSidebarTabGroupDragPrefix.count)) {
            self = .tabGroup(rawValue)
        } else if encodedValue.hasPrefix(workspaceSidebarCardDragPrefix) {
            self = .card(String(encodedValue.dropFirst(workspaceSidebarCardDragPrefix.count)))
        } else {
            return nil
        }
    }

    var itemProvider: NSItemProvider {
        let value = encodedValue
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: workspaceSidebarDragPayloadType.identifier,
            visibility: .all,
        ) { completion in
            completion(Data(value.utf8), nil)
            return nil
        }
        return provider
    }
}
