import AppKit
import Common

open class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: any AbstractApp
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard
    /// Event-invalidated caches of the native window state (frame, fullscreen, minimized),
    /// read on hot paths instead of polling every window over AX. Entering/exiting native
    /// fullscreen always resizes the window (invalidated via moved/resized events); minimize
    /// state changes emit miniaturized/deminiaturized events. nil means "no observation since
    /// the last event" and readers must fetch live.
    ///
    /// Writes go through the record methods below: an async AX observation races the very
    /// events that invalidate these caches, and a stale value written back after the
    /// transition's events were consumed would look valid forever (nothing would invalidate
    /// it again). Observed values are therefore discarded unless the generation captured
    /// before the fetch is still current.
    @MainActor private(set) var lastKnownActualRect: Rect? = nil
    @MainActor private(set) var lastKnownNativeFullscreen: Bool? = nil
    @MainActor private(set) var lastKnownNativeMinimized: Bool? = nil
    @MainActor private var lastKnownNativeStateGeneration: UInt64 = 0

    @MainActor
    func invalidateLastKnownNativeState() {
        lastKnownNativeStateGeneration += 1
        lastKnownActualRect = nil
        lastKnownNativeFullscreen = nil
        lastKnownNativeMinimized = nil
    }

    /// Capture before starting an async AX observation and pass to the matching record method.
    @MainActor
    func nativeStateObservationToken() -> UInt64 { lastKnownNativeStateGeneration }

    @MainActor
    func recordObservedActualRect(_ rect: Rect?, token: UInt64) {
        if lastKnownNativeStateGeneration == token {
            lastKnownActualRect = rect
        }
    }

    @MainActor
    func recordObservedNativeState(fullscreen: Bool, minimized: Bool, token: UInt64) {
        if lastKnownNativeStateGeneration == token {
            lastKnownNativeFullscreen = fullscreen
            lastKnownNativeMinimized = minimized
        }
    }

    /// For writers that know the current frame because they just set or saved it themselves
    /// (interaction-opacity parking/restore, initial registration). Supersedes any in-flight
    /// observation so a slow fetch can't clobber the deliberately written value.
    @MainActor
    func recordAuthoritativeActualRect(_ rect: Rect?) {
        lastKnownNativeStateGeneration += 1
        lastKnownActualRect = rect
    }

    @MainActor
    init(id: UInt32, _ app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? { // todo make non optional
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    @MainActor
    func closeAxWindow() { die("Not implemented") }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getAxSize() async throws -> CGSize? { die("Not implemented") }
    var title: String { get async throws { die("Not implemented") } }
    @MainActor var axRecordAttributes: WindowAxRecordAttributes { get async throws { die("Not implemented") } }
    /// The window's layer in the window server: 0 for a normal window, and 0 when unknown.
    @MainActor var cgWindowLevel: Int { die("Not implemented") }
    var isMacosFullscreen: Bool { get async throws { false } }
    var isMacosMinimized: Bool { get async throws { false } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor
    func nativeFocus() { die("Not implemented") }
    func getAxRect() async throws -> Rect? { die("Not implemented") }
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
}

/// The workspace a window was on, with its project: WinMux may delete the workspace while the
/// window is away from it.
struct WorkspaceOrigin: Codable, Equatable, Sendable {
    var workspaceName: String
    var projectId: WorkspaceProjectId

    init(workspaceName: String, projectId: WorkspaceProjectId) {
        self.workspaceName = workspaceName
        self.projectId = projectId
    }

    init(_ workspace: Workspace) {
        self.init(workspaceName: workspace.name, projectId: workspace.projectId)
    }
}

enum LayoutReason: Equatable, Sendable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide.
    ///
    /// `origin` is where the window was. A minimized window is detached from it: the window does
    /// not keep that workspace alive, and when unminimized it lands on the focused workspace. So
    /// `returnsToOrigin` is false for it, and the origin only says where the window came from.
    case macos(prevParentKind: NonLeafTreeNodeKind, origin: WorkspaceOrigin?, returnsToOrigin: Bool)

    var origin: WorkspaceOrigin? {
        switch self {
            case .standard: nil
            case .macos(_, let origin, _): origin
        }
    }

    /// The workspace the window goes back to when it leaves the macOS state, which it also keeps
    /// alive meanwhile. `nil` means the focused workspace.
    var returnWorkspaceName: String? {
        switch self {
            case .standard: nil
            case .macos(_, let origin, let returnsToOrigin): returnsToOrigin ? origin?.workspaceName : nil
        }
    }

    /// The same reason with its origin moved to `workspace`.
    func movingOrigin(to workspace: Workspace) -> LayoutReason {
        switch self {
            case .standard: .standard
            case .macos(let prevParentKind, _, let returnsToOrigin):
                .macos(prevParentKind: prevParentKind, origin: WorkspaceOrigin(workspace), returnsToOrigin: returnsToOrigin)
        }
    }
}

extension LayoutReason: Codable {
    private enum CodingKeys: String, CodingKey { case standard, macos }
    private enum MacosKeys: String, CodingKey { case prevParentKind, origin, returnsToOrigin, prevWorkspaceName }
    private struct Empty: Codable {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.macos) else {
            self = .standard
            return
        }
        let macos = try container.nestedContainer(keyedBy: MacosKeys.self, forKey: .macos)
        let prevParentKind = try macos.decode(NonLeafTreeNodeKind.self, forKey: .prevParentKind)
        if let returnsToOrigin = try macos.decodeIfPresent(Bool.self, forKey: .returnsToOrigin) {
            let origin = try macos.decodeIfPresent(WorkspaceOrigin.self, forKey: .origin)
            self = .macos(prevParentKind: prevParentKind, origin: origin, returnsToOrigin: returnsToOrigin)
        } else {
            // State saved before the origin was kept: a workspace name meant "return there", and
            // a detached window had none. The project was not saved.
            let origin = try macos.decodeIfPresent(String.self, forKey: .prevWorkspaceName)
                .map { WorkspaceOrigin(workspaceName: $0, projectId: workspaceProjectDefaultId) }
            self = .macos(prevParentKind: prevParentKind, origin: origin, returnsToOrigin: origin != nil)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .standard:
                try container.encode(Empty(), forKey: .standard)
            case .macos(let prevParentKind, let origin, let returnsToOrigin):
                var macos = container.nestedContainer(keyedBy: MacosKeys.self, forKey: .macos)
                try macos.encode(prevParentKind, forKey: .prevParentKind)
                try macos.encodeIfPresent(origin, forKey: .origin)
                try macos.encode(returnsToOrigin, forKey: .returnsToOrigin)
        }
    }
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    @MainActor
    func rememberMacOsLayoutOrigin(detachFromWorkspace: Bool = false) {
        guard let parent else { return }
        layoutReason = .macos(
            prevParentKind: parent.kind,
            origin: nodeWorkspace.map(WorkspaceOrigin.init),
            returnsToOrigin: !detachFromWorkspace,
        )
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
