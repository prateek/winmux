import Common

public struct ServerEvent: Codable, Sendable {
    private let _event: ServerEventType

    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var windowId: UInt32?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var workspace: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var prevWorkspace: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var monitorId: Int? // 1-based
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var appBundleId: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var appName: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var mode: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var binding: String?

    private var ok: Bool?
    private var error: String?
    private var configPath: String?
    private var lens: String?
    private var filter: String?
    private var count: Int?
    private var widths: [Double]?
    private var occupied: [Int]?

    public static func configReloaded(ok: Bool, error: String?, configPath: String) -> ServerEvent {
        ServerEvent(_event: .configReloaded, ok: ok, error: error, configPath: configPath)
    }

    public static func lensEvent(opened: Bool, lens: String?, filter: String?) -> ServerEvent {
        ServerEvent(_event: opened ? .lensOpened : .lensClosed, lens: lens, filter: filter)
    }

    public static func columnsChanged(workspace: String, count: Int, widths: [Double], occupied: [Int]) -> ServerEvent {
        ServerEvent(_event: .columnsChanged, workspace: workspace, count: count, widths: widths, occupied: occupied)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(_event, forKey: ._event)
        switch _event {
            case .configReloaded:
                try c.encode(ok, forKey: .ok)
                try c.encode(error, forKey: .error)
                try c.encode(configPath, forKey: .configPath)
            case .lensOpened, .lensClosed:
                try c.encode(lens, forKey: .lens)
                if lens == nil { try c.encode(filter, forKey: .filter) }
            case .columnsChanged:
                try c.encode(workspace, forKey: .workspace)
                try c.encode(count, forKey: .count)
                try c.encode(widths, forKey: .widths)
                try c.encode(occupied, forKey: .occupied)
            default:
                try c.encodeIfPresent(windowId, forKey: .windowId)
                try c.encodeIfPresent(workspace, forKey: .workspace)
                try c.encodeIfPresent(prevWorkspace, forKey: .prevWorkspace)
                try c.encodeIfPresent(monitorId, forKey: .monitorId)
                try c.encodeIfPresent(appBundleId, forKey: .appBundleId)
                try c.encodeIfPresent(appName, forKey: .appName)
                try c.encodeIfPresent(mode, forKey: .mode)
                try c.encodeIfPresent(binding, forKey: .binding)
        }
    }

    public var eventType: ServerEventType { _event }

    public static func focusChanged(windowId: UInt32?, workspace: String) -> ServerEvent {
        ServerEvent(_event: .focusChanged, windowId: windowId, workspace: workspace)
    }

    public static func focusedMonitorChanged(workspace: String, monitorId_oneBased: Int) -> ServerEvent {
        ServerEvent(_event: .focusedMonitorChanged, workspace: workspace, monitorId: monitorId_oneBased)
    }

    public static func workspaceChanged(workspace: String, prevWorkspace: String) -> ServerEvent {
        ServerEvent(_event: .workspaceChanged, workspace: workspace, prevWorkspace: prevWorkspace)
    }

    public static func modeChanged(mode: String?) -> ServerEvent {
        ServerEvent(_event: .modeChanged, mode: mode)
    }

    public static func windowDetected(windowId: UInt32, workspace: String?, appBundleId: String?, appName: String?) -> ServerEvent {
        ServerEvent(_event: .windowDetected, windowId: windowId, workspace: workspace, appBundleId: appBundleId, appName: appName)
    }

    public static func bindingTriggered(mode: String, binding: String) -> ServerEvent {
        ServerEvent(_event: .bindingTriggered, mode: mode, binding: binding)
    }
}
