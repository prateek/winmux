enum WindowDragSubject: Equatable {
    case window
    case group(UInt64)

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }
}

enum TabDetachOrigin: Equatable {
    case window
    case tabStrip
}
