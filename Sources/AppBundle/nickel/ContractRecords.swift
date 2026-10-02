import AppKit
import Common

// The records of the Filter contract as WinMux sends them to `winmux-nickel`. Their fields are
// defined once, in nickel-helper/src/records.rs, and `winmux config schema` prints them. The
// helper rejects a record that lacks a field, so every field is always sent.

enum WindowClass: String, Equatable, Sendable {
    case tiled, floating, fullscreen, minimized
    case hiddenApp = "hidden-app"
    case accessoryPopup = "accessory-popup"
    case appPopup = "app-popup"
}

enum AppActivationPolicy: String, Equatable, Sendable {
    case regular, accessory, prohibited
}

/// What a Window record takes from the window's AX element.
struct WindowAxRecordAttributes: Equatable, Sendable {
    var title: String
    var subrole: String
    var hasCloseButton: Bool
    var document: String

    static let unknown = WindowAxRecordAttributes(title: "", subrole: "", hasCloseButton: false, document: "")
}

struct MonitorRecord: Equatable, Sendable {
    var name: String
    var uuid: String
    var builtin: Bool

    static let unknown = MonitorRecord(name: "", uuid: "", builtin: false)

    init(name: String, uuid: String, builtin: Bool) {
        self.name = name
        self.uuid = uuid
        self.builtin = builtin
    }

    init(_ monitor: Monitor) {
        self.init(name: monitor.name, uuid: monitor.displayUuid, builtin: monitor.isBuiltin)
    }

    var json: JSONValue {
        .object(["name": .string(name), "uuid": .string(uuid), "builtin": .bool(builtin)])
    }
}

struct AppRecord: Equatable, Sendable {
    var bundleId: String
    var name: String
    var pid: Int
    var accessory: Bool
    var activationPolicy: AppActivationPolicy

    /// `accessory` and `activationPolicy` are supplied by "Accessory window defaults and the
    /// `floating` Lens". Until then every app is reported as a regular one.
    init(_ app: any AbstractApp) {
        bundleId = app.rawAppBundleId ?? ""
        name = app.name ?? ""
        pid = Int(app.pid)
        accessory = false
        activationPolicy = .regular
    }

    var json: JSONValue {
        .object([
            "bundleId": .string(bundleId),
            "name": .string(name),
            "pid": .int(pid),
            "accessory": .bool(accessory),
            "activationPolicy": .string(activationPolicy.rawValue),
        ])
    }
}

struct WindowRecord: Equatable, Sendable {
    var id: Int
    var title: String
    var windowClass: WindowClass
    var subrole: String
    var level: Int
    var hasCloseButton: Bool
    var document: String
    var workspace: String
    var project: String
    var monitor: MonitorRecord
    var lastFocusedSeq: Int
    var app: AppRecord

    var json: JSONValue {
        .object([
            "id": .int(id),
            "title": .string(title),
            "class": .string(windowClass.rawValue),
            "subrole": .string(subrole),
            "level": .int(level),
            "hasCloseButton": .bool(hasCloseButton),
            "document": .string(document),
            "workspace": .string(workspace),
            "project": .string(project),
            "monitor": monitor.json,
            "lastFocusedSeq": .int(lastFocusedSeq),
            "app": app.json,
        ])
    }
}

struct FilterContextRecord: Equatable, Sendable {
    var focused: WindowRecord?
    var mouse: WindowRecord?
    var previous: WindowRecord?
    var workspaceName: String
    var workspaceProject: String
    var monitor: MonitorRecord
    var profile: String

    var json: JSONValue {
        .object([
            "focused": focused?.json ?? .null,
            "mouse": mouse?.json ?? .null,
            "previous": previous?.json ?? .null,
            "workspace": .object(["name": .string(workspaceName), "project": .string(workspaceProject)]),
            "monitor": monitor.json,
            "profile": .string(profile),
        ])
    }
}

extension Window {
    /// The window's class: the one node it sits under, the same relation `list-windows` prints as
    /// the layout. `nil` for a window that is in no tree, which is one being closed.
    @MainActor var windowClass: WindowClass? {
        guard let parent else { return nil }
        return switch getChildParentRelation(child: self, parent: parent) {
            case .tiling: .tiled
            case .floatingWindow: .floating
            case .macosNativeFullscreenWindow: .fullscreen
            case .macosNativeHiddenAppWindow: .hiddenApp
            case .macosNativeMinimizedWindow: .minimized
            // "Accessory window defaults and the `floating` Lens" tells the two popup classes apart.
            case .macosPopupWindow: .appPopup
            case .rootTilingContainer, .shimContainerRelation: illegalChildParentRelation(child: self, parent: parent)
        }
    }

    /// The Window record, or `nil` for a window that is in no tree.
    @MainActor func windowRecord() async -> WindowRecord? {
        guard let windowClass else { return nil }
        // A window that closes while it is being read reports what is still known about it.
        let ax = (try? await axRecordAttributes) ?? .unknown
        // A minimized window sits outside every workspace and reports the one it was minimized on,
        // which WinMux may have deleted since. A popup reports none.
        let minimizedOn = windowClass == .minimized ? minimizedOn : nil
        let workspace = nodeWorkspace ?? minimizedOn.flatMap { Workspace.existing(byName: $0.workspaceName) }
        return WindowRecord(
            id: Int(windowId),
            title: ax.title,
            windowClass: windowClass,
            subrole: ax.subrole,
            level: isUnitTest ? 0 : getWindowLevel(for: windowId)?.cgWindowLevel ?? 0,
            hasCloseButton: ax.hasCloseButton,
            document: ax.document,
            workspace: workspace?.name ?? minimizedOn?.workspaceName ?? "",
            project: (workspace?.projectId ?? minimizedOn?.projectId)?.rawValue ?? "",
            monitor: workspace.map { MonitorRecord($0.workspaceMonitor) } ?? .unknown,
            // Written by "Global MRU (`lastFocusedSeq`)".
            lastFocusedSeq: 0,
            app: AppRecord(app),
        )
    }
}

extension MacOsWindowLevel {
    var cgWindowLevel: Int {
        switch self {
            case .normalWindow: 0
            case .alwaysOnTopWindow: 3
            case .unknown(let windowLevel): windowLevel
        }
    }
}

/// The window under the mouse on the workspace the mouse is over: a floating window, the most
/// recently used first, before the tiled one beneath it.
@MainActor func windowUnderMouse(_ point: CGPoint = mouseLocation) async -> Window? {
    let workspace = point.monitorApproximation.activeWorkspace
    for window in workspace.childrenByMostRecentUse.filterIsInstance(of: Window.self) {
        let rect = if let known = window.lastKnownActualRect { known } else { try? await window.getAxRect() }
        if rect?.contains(point) == true { return window }
    }
    return point.findIn(tree: workspace.rootTilingContainer, virtual: false)
}

/// The Filter context for a Filter evaluated now.
@MainActor func filterContextRecord(mouse: CGPoint = mouseLocation) async -> FilterContextRecord {
    let focus = focus
    return FilterContextRecord(
        focused: await focus.windowOrNil?.windowRecord(),
        mouse: await windowUnderMouse(mouse)?.windowRecord(),
        previous: await prevFocus?.windowOrNil?.windowRecord(),
        workspaceName: focus.workspace.name,
        workspaceProject: focus.workspace.projectId.rawValue,
        monitor: MonitorRecord(focus.workspace.workspaceMonitor),
        profile: "default",
    )
}

extension Json {
    /// A record as `debug-windows` prints it. `Json` has no fractional number, and no record
    /// WinMux builds holds one.
    init(_ value: JSONValue) {
        self = switch value {
            case .null: .null
            case .bool(let value): .bool(value)
            case .int(let value): .int(value)
            case .double(let value): .string(value.description)
            case .string(let value): .string(value)
            case .array(let values): .array(values.map(Json.init))
            case .object(let fields): .dict(fields.mapValues(Json.init))
        }
    }
}
