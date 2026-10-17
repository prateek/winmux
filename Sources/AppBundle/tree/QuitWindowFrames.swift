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

func quitFrameAction(record: Rect?, hidden: Bool, lastKnownFrame: Rect?, floatingSize: CGSize?,
                     restoreOriginal: Bool, monitors: [Monitor], main: Monitor) -> QuitFrameAction {
    if restoreOriginal {
        if let record, monitors.contains(where: { $0.rect.contains(record.center) }) { return .restore(record) }
        if !hidden, let lastKnownFrame, monitors.contains(where: { $0.rect.contains(lastKnownFrame.center) }) { return .leave }
    }
    let monitor = lastKnownFrame.flatMap { frame in
        monitors.min { frame.center.distance(toOuterFrame: $0.rect) < frame.center.distance(toOuterFrame: $1.rect) }
    } ?? main
    let visible = monitor.visibleRect
    let size = floatingSize ?? visible.size
    return .center(Rect(topLeftX: visible.minX + (visible.width - size.width) / 2,
        topLeftY: visible.minY + (visible.height - size.height) / 2, width: size.width, height: size.height))
}

struct QuitWindowFrame: Sendable {
    let appId: Int32
    let windowId: UInt32
    let action: QuitFrameAction
}

@MainActor
func restoreQuitWindowFrames(_ plans: [QuitWindowFrame],
                             write: @escaping @MainActor @Sendable (UInt32, Rect) async throws -> Void,
                             failed: @escaping @MainActor @Sendable (UInt32, Error) -> Void) async {
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
                                       failed: @MainActor @Sendable (UInt32, Error) -> Void) async {
    for window in windows {
        do {
            if let frame = window.action.frame { try await write(window.windowId, frame) }
            quitFramesLog.info("Quit frame window=\(window.windowId) action=\(window.action.name, privacy: .public)")
        } catch {
            failed(window.windowId, error)
        }
    }
}
