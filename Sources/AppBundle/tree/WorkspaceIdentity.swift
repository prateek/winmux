import AppKit

struct WorkspaceId: RawRepresentable, Hashable, Identifiable, Sendable, Codable, CustomStringConvertible, Comparable {
    let rawValue: String

    var id: String { rawValue }
    var description: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static func < (lhs: WorkspaceId, rhs: WorkspaceId) -> Bool {
        lhs.rawValue.localizedStandardCompare(rhs.rawValue) == .orderedAscending
    }
}

struct WorkspaceProjectId: RawRepresentable, Hashable, Identifiable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    static let defaultProject = WorkspaceProjectId(rawValue: "default")

    let rawValue: String

    var id: String { rawValue }
    var description: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    func hasPrefix(_ prefix: String) -> Bool {
        rawValue.hasPrefix(prefix)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func < (lhs: WorkspaceProjectId, rhs: WorkspaceProjectId) -> Bool {
        lhs.rawValue.localizedStandardCompare(rhs.rawValue) == .orderedAscending
    }
}

struct MonitorViewportId: Hashable, Sendable, Codable, CustomStringConvertible {
    let topLeftCorner: CGPoint
    let stableIdentity: String

    var description: String {
        stableIdentity == Self.physicalIdentity(topLeftCorner: topLeftCorner)
            ? "\(topLeftCorner.x),\(topLeftCorner.y)"
            : "\(stableIdentity)@\(topLeftCorner.x),\(topLeftCorner.y)"
    }

    init(topLeftCorner: CGPoint) {
        self.topLeftCorner = topLeftCorner
        self.stableIdentity = Self.physicalIdentity(topLeftCorner: topLeftCorner)
    }

    @MainActor
    init(_ monitor: Monitor) {
        let topLeftCorner = monitor.rect.topLeftCorner
        self.topLeftCorner = topLeftCorner
        if let columnId = monitor.columnId {
            self.stableIdentity = Self.columnIdentity(
                physicalTopLeftCorner: monitor.physicalMonitor.rect.topLeftCorner,
                columnId: columnId,
            )
        } else {
            self.stableIdentity = Self.physicalIdentity(topLeftCorner: topLeftCorner)
        }
    }

    func hasSameStableIdentity(as other: MonitorViewportId) -> Bool {
        stableIdentity == other.stableIdentity
    }

    @MainActor
    var currentMonitorApproximation: Monitor {
        monitors.first { MonitorViewportId($0).stableIdentity == stableIdentity } ?? topLeftCorner.monitorApproximation
    }

    private static func physicalIdentity(topLeftCorner: CGPoint) -> String {
        "physical:\(topLeftCorner.x),\(topLeftCorner.y)"
    }

    private static func columnIdentity(physicalTopLeftCorner: CGPoint, columnId: String) -> String {
        "zone:\(physicalTopLeftCorner.x),\(physicalTopLeftCorner.y):\(columnId)"
    }

    private enum CodingKeys: String, CodingKey {
        case topLeftCorner
        case stableIdentity
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topLeftCorner = try container.decode(CGPoint.self, forKey: .topLeftCorner)
        stableIdentity = try container.decodeIfPresent(String.self, forKey: .stableIdentity)
            ?? Self.physicalIdentity(topLeftCorner: topLeftCorner)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topLeftCorner, forKey: .topLeftCorner)
        try container.encode(stableIdentity, forKey: .stableIdentity)
    }
}

typealias MonitorKey = MonitorViewportId

enum WorkspaceLifecycle: String, Codable, Sendable {
    case durable
    case transient
    case archived
}
