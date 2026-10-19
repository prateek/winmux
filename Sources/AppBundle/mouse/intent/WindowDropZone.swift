import Foundation

enum WindowDropZone: String, CaseIterable, Hashable, Sendable {
    case tab
    case left
    case right
    case top
    case bottom
    case middle

    var symbolName: String {
        switch self {
            case .tab: "rectangle.3.group"
            case .left: "arrow.left"
            case .right: "arrow.right"
            case .top: "arrow.up"
            case .bottom: "arrow.down"
            case .middle: "arrow.left.arrow.right"
        }
    }

    var sidebarIntent: String {
        switch self {
            case .tab: "Tab with"
            case .left: "Split left of"
            case .right: "Split right of"
            case .top: "Split above"
            case .bottom: "Split below"
            case .middle: "Swap with"
        }
    }

    var stackSplitPosition: WindowStackSplitPosition? {
        switch self {
            case .left: .left
            case .right: .right
            case .top: .above
            case .bottom: .below
            case .tab, .middle: nil
        }
    }
}

struct WindowDropIntent: Equatable {
    let sourceWindowId: UInt32
    let targetWindowId: UInt32
    let zone: WindowDropZone
}
