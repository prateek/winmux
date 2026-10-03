import Foundation

struct MiniatureLayout {
    enum Direction { case left, right, up, down }
    struct Cell { let workspace: String; let frame: CGRect; let tray: CGRect }
    let workspaces: [String]
    let columns: Int
    let capacity: Int
    let workspaceHeight: CGFloat
    private let width: CGFloat
    private let cellHeight: CGFloat
    private let gap: CGFloat
    private let trayHeight: CGFloat
    var pageCount: Int { max(1, (workspaces.count + capacity - 1) / capacity) }

    init(workspaces: [String], size: CGSize, aspect: CGFloat, fit: String) {
        self.workspaces = workspaces
        let aspect = max(0.1, aspect)
        let availableWidth = max(1, size.width - 48)
        let availableHeight = max(1, size.height - 100)
        let maxColumns = max(1, Int((availableWidth + 24) / (110 * aspect + 24)))
        let maxRows = max(1, Int(availableHeight / (110 + 84)))
        var overhead: CGFloat = 84
        if fit == "shrink" {
            var factor: CGFloat = 1
            var bestColumns = 1
            var bestWidth: CGFloat = 0
            while bestWidth <= 0 {
                for candidate in 1 ... max(1, workspaces.count) {
                    let rows = max(1, Int(ceil(CGFloat(workspaces.count) / CGFloat(candidate))))
                    let horizontal = (availableWidth - CGFloat(candidate - 1) * 24 * factor) / CGFloat(candidate)
                    let vertical = (availableHeight / CGFloat(rows) - 84 * factor) * aspect
                    let candidateWidth = min(horizontal, vertical)
                    if candidateWidth > bestWidth { bestColumns = candidate; bestWidth = candidateWidth }
                }
                if bestWidth <= 0 { factor *= 0.5 }
            }
            columns = bestColumns
            width = min(560, bestWidth)
            capacity = max(1, workspaces.count)
            gap = 24 * factor
            trayHeight = 28 * factor
            overhead *= factor
        } else {
            gap = 24
            trayHeight = 28
            columns = min(maxColumns, max(1, workspaces.count))
            capacity = columns * maxRows
            let rows = min(maxRows, max(1, Int(ceil(CGFloat(workspaces.count) / CGFloat(columns)))))
            width = min(560, (availableWidth - CGFloat(columns - 1) * 24) / CGFloat(columns), max(110, availableHeight / CGFloat(rows) - 84) * aspect)
        }
        workspaceHeight = width / aspect
        cellHeight = workspaceHeight + overhead
    }

    func cells(on page: Int) -> [Cell] {
        let start = max(0, min(pageCount - 1, page)) * capacity
        return workspaces.dropFirst(start).prefix(capacity).enumerated().map { index, name in
            let frame = CGRect(x: 24 + CGFloat(index % columns) * (width + gap), y: 68 + CGFloat(index / columns) * cellHeight, width: width, height: workspaceHeight)
            return Cell(workspace: name, frame: frame, tray: CGRect(x: frame.minX, y: frame.maxY + 4, width: width, height: trayHeight))
        }
    }

    func turnedPage(_ page: Int, delta: Int) -> Int { min(max(0, page + delta), pageCount - 1) }
    func page(for workspace: String) -> Int? { workspaces.firstIndex(of: workspace).map { $0 / capacity } }

    static func scale(_ frame: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let scale = min(target.width / max(1, source.width), target.height / max(1, source.height))
        return CGRect(x: target.minX + (frame.minX - source.minX) * scale, y: target.minY + (frame.minY - source.minY) * scale, width: frame.width * scale, height: frame.height * scale)
    }

    static func nearest(from id: UInt32, direction: Direction, frames: [UInt32: CGRect], matches: Set<UInt32>) -> UInt32? {
        guard let source = frames[id] else { return nil }
        return frames.filter { candidate, rect in
            guard candidate != id, matches.contains(candidate) else { return false }
            switch direction {
                case .left: return rect.midX < source.midX - 1
                case .right: return rect.midX > source.midX + 1
                case .up: return rect.midY < source.midY - 1
                case .down: return rect.midY > source.midY + 1
            }
        }.min { lhs, rhs in
            func distance(_ rect: CGRect) -> CGFloat { hypot(rect.midX - source.midX, rect.midY - source.midY) }
            let a = distance(lhs.value), b = distance(rhs.value)
            return a == b ? lhs.key < rhs.key : a < b
        }?.key
    }
}
