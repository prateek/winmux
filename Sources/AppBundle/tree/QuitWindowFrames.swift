import AppKit

enum QuitFrameAction: Equatable, Sendable {
    case restore(Rect)
    case leave
    case center(Rect)

    var frame: Rect? {
        switch self {
            case .restore(let rect), .center(let rect): rect
            case .leave: nil
        }
    }

    var name: String {
        switch self {
            case .restore: "restored"
            case .leave: "left-onscreen"
            case .center: "centered"
        }
    }
}

/// `parkedOn` is the visible rect of the monitor a window hidden in a corner was parked on.
func quitFrameAction(record: Rect?, hidden: Bool, parkedOn: Rect?, lastKnownFrame: Rect?, floatingSize: CGSize?,
                     restoreOriginal: Bool, monitors: [Monitor], main: Monitor) -> QuitFrameAction {
    if restoreOriginal {
        if let record, monitors.contains(where: { $0.rect.contains(record.center) }) { return .restore(record) }
        // Only hiding moves a window off its monitor, so an unhidden window with no cached frame is on screen.
        if !hidden, lastKnownFrame.map({ frame in monitors.contains { $0.rect.contains(frame.center) } }) ?? true {
            return .leave
        }
    }
    let monitor = parkedOn.flatMap { rect in monitors.first { $0.visibleRect == rect } }
        ?? lastKnownFrame.flatMap { frame in
            monitors.min { frame.center.distance(toOuterFrame: $0.rect) < frame.center.distance(toOuterFrame: $1.rect) }
        } ?? main
    let visible = monitor.visibleRect
    let size = floatingSize ?? visible.size
    return .center(Rect(topLeftX: visible.minX + max(0, (visible.width - size.width) / 2),
        topLeftY: visible.minY + max(0, (visible.height - size.height) / 2), width: size.width, height: size.height))
}

struct QuitWindowFrame: Sendable {
    let appId: Int32
    let windowId: UInt32
    let action: QuitFrameAction
}

@MainActor
func restoreQuitWindowFrames(_ plans: [QuitWindowFrame],
                             write: @escaping @MainActor @Sendable (UInt32, Rect) async throws -> Void,
                             failed: @escaping @MainActor @Sendable (QuitWindowFrame, Error) -> Void) async {
    await withTaskGroup(of: Void.self) { group in
        for windows in Dictionary(grouping: plans, by: \.appId).values {
            group.addTask {
                await restoreAppQuitWindowFrames(windows, write: write, failed: failed)
            }
        }
    }
}

@MainActor
private func restoreAppQuitWindowFrames(_ windows: [QuitWindowFrame],
                                       write: @MainActor @Sendable (UInt32, Rect) async throws -> Void,
                                       failed: @MainActor @Sendable (QuitWindowFrame, Error) -> Void) async {
    for window in windows {
        do {
            if let frame = window.action.frame { try await write(window.windowId, frame) }
            quitFramesLog.info("Quit frame window=\(window.windowId) action=\(window.action.name, privacy: .public)")
        } catch {
            failed(window, error)
        }
    }
}
