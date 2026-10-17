import AppKit

struct QuitFrameWindowGone: Error {}

struct QuitFrameWriteError: Error {
    let attribute: String
    let error: AXError
}

/// Every write is attempted: a window that refuses its size still gets its position. The first
/// size write may fail where the window stands; only the position and the last size count.
func writeQuitFrame(_ frame: Rect, set: (String, CFTypeRef) -> AXError) throws {
    let writes: [(String, CFTypeRef)] = [
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
        (Ax.topLeftCornerAttr.key, Ax.topLeftCornerAttr.setter(frame.topLeftCorner)!),
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
    ]
    let results = writes.map { attribute, value in (attribute, set(attribute, value)) }
    if let (attribute, error) = results.dropFirst().first(where: { $0.1 != .success }) {
        throw QuitFrameWriteError(attribute: attribute, error: error)
    }
}
