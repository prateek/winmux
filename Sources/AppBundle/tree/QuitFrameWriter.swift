import AppKit

struct QuitFrameWriteError: Error {
    let attribute: String
    let error: AXError
}

func writeQuitFrame(_ frame: Rect, set: (String, CFTypeRef) -> AXError) throws {
    let writes: [(String, CFTypeRef)] = [
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
        (Ax.topLeftCornerAttr.key, Ax.topLeftCornerAttr.setter(frame.topLeftCorner)!),
        (Ax.sizeAttr.key, Ax.sizeAttr.setter(frame.size)!),
    ]
    for (attribute, value) in writes {
        let error = set(attribute, value)
        guard error == .success else { throw QuitFrameWriteError(attribute: attribute, error: error) }
    }
}
