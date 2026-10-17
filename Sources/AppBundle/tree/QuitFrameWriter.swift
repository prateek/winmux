import AppKit

struct QuitFrameWindowGone: Error {}

struct QuitFrameWriteError: Error {
    let attribute: String
    let error: AXError
}

/// Every write is attempted: a window that refuses its size still gets its position.
func writeQuitFrame(_ frame: Rect, set: (String, CFTypeRef) -> AXError) throws {
    let writes: [(String, CFTypeRef)] = [
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
        (Ax.topLeftCornerAttr.key, Ax.topLeftCornerAttr.setter(frame.topLeftCorner)!),
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
    ]
    var firstError: QuitFrameWriteError?
    for (attribute, value) in writes {
        let error = set(attribute, value)
        if error != .success, firstError == nil { firstError = QuitFrameWriteError(attribute: attribute, error: error) }
    }
    if let firstError { throw firstError }
}
