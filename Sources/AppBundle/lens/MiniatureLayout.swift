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
    private let origin: CGPoint
    private let trayHeight: CGFloat
    var pageCount: Int { max(1, (workspaces.count + capacity - 1) / capacity) }

    init(workspaces: [String], size: CGSize, aspect: CGFloat, fit: String) {
        self.workspaces = workspaces
        let aspect = max(0.1, aspect)
        let availableWidth = max(1, size.width - 48)
        let availableHeight = max(1, size.height - 100)
        let maxColumns = max(1, Int((availableWidth + 24) / (110 * aspect + 24)))
        let maxRows = max(1, Int(availableHeight / (110 + 84)))
        let count = max(1, workspaces.count)
        var factor: CGFloat = 1
        var bestColumns = 1
        var bestWidth: CGFloat = 0
        repeat {
            for candidate in 1 ... count {
                let rows = (count + candidate - 1) / candidate
                let horizontal = (availableWidth - CGFloat(candidate - 1) * 24 * factor) / CGFloat(candidate)
                let vertical = (availableHeight / CGFloat(rows) - 84 * factor) * aspect
                let candidateWidth = min(horizontal, vertical)
                if candidateWidth >= bestWidth { bestColumns = candidate; bestWidth = candidateWidth }
            }
            if bestWidth <= 0 { factor *= 0.5 }
        } while bestWidth <= 0

        let rows: Int
        if fit == "page", bestWidth / aspect < 110 {
            columns = min(maxColumns, count)
            capacity = columns * maxRows
            rows = maxRows
            width = min((availableWidth - CGFloat(columns - 1) * 24) / CGFloat(columns), max(110, availableHeight / CGFloat(rows) - 84) * aspect)
            factor = 1
        } else {
            columns = bestColumns
            capacity = count
            rows = (count + columns - 1) / columns
            width = bestWidth
        }
        gap = 24 * factor
        trayHeight = 28 * factor
        workspaceHeight = width / aspect
        cellHeight = workspaceHeight + 84 * factor
        let arrangementWidth = CGFloat(columns) * width + CGFloat(columns - 1) * gap
        origin = CGPoint(x: (size.width - arrangementWidth) / 2,
                         y: 68 + (availableHeight - CGFloat(rows) * cellHeight) / 2 + 24 * factor)
    }

    func cells(on page: Int) -> [Cell] {
        let start = max(0, min(pageCount - 1, page)) * capacity
        return workspaces.dropFirst(start).prefix(capacity).enumerated().map { index, name in
            let frame = CGRect(x: origin.x + CGFloat(index % columns) * (width + gap), y: origin.y + CGFloat(index / columns) * cellHeight, width: width, height: workspaceHeight)
            return Cell(workspace: name, frame: frame, tray: CGRect(x: frame.minX, y: frame.maxY + 4, width: width, height: trayHeight))
        }
    }

    func turnedPage(_ page: Int, delta: Int) -> Int { min(max(0, page + delta), pageCount - 1) }
    func page(for workspace: String) -> Int? { workspaces.firstIndex(of: workspace).map { $0 / capacity } }

    static func scale(_ frame: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let scale = min(target.width / max(1, source.width), target.height / max(1, source.height))
        return CGRect(x: target.minX + (frame.minX - source.minX) * scale, y: target.minY + (frame.minY - source.minY) * scale, width: frame.width * scale, height: frame.height * scale)
    }

    static func panelPoint(fromScreen point: CGPoint, screenMaxY: CGFloat, origin: CGPoint) -> CGPoint {
        CGPoint(x: point.x - origin.x, y: screenMaxY - point.y - origin.y)
    }

    static func fan(_ frame: CGRect, count: Int, index: Int, activeIndex: Int, cellWidth: CGFloat) -> CGRect {
        guard count > 1 else { return frame }
        let offset = min(cellWidth * 16 / 820, min(frame.width, frame.height) / (4 * CGFloat(count - 1)))
        let inset = CGFloat(count - 1) * offset
        let depth = fanDepth(index: index, activeIndex: activeIndex)
        return CGRect(x: frame.minX + CGFloat(depth) * offset, y: frame.minY + CGFloat(depth) * offset,
                      width: frame.width - inset, height: frame.height - inset)
    }

    static func fanDepth(index: Int, activeIndex: Int) -> Int {
        index == activeIndex ? 0 : (index < activeIndex ? index + 1 : index)
    }

    static func nearest(from id: UInt32, direction: Direction, frames: [UInt32: CGRect], matches: Set<UInt32>, adjacentTabs: Set<UInt32> = []) -> UInt32? {
        guard let source = frames[id] else { return nil }
        return frames.filter { candidate, rect in
            guard candidate != id, matches.contains(candidate) else { return false }
            let threshold: CGFloat = adjacentTabs.contains(candidate) ? 0 : 1
            switch direction {
                case .left: return rect.midX < source.midX - threshold
                case .right: return rect.midX > source.midX + threshold
                case .up: return rect.midY < source.midY - threshold
                case .down: return rect.midY > source.midY + threshold
            }
        }.min { lhs, rhs in
            func distance(_ rect: CGRect) -> CGFloat { hypot(rect.midX - source.midX, rect.midY - source.midY) }
            let a = distance(lhs.value), b = distance(rhs.value)
            return a == b ? lhs.key < rhs.key : a < b
        }?.key
    }
}
