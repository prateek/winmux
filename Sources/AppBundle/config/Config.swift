import AppKit
import Common
import HotKey
import OrderedCollections

func getDefaultConfigUrlFromProject(startingAt explicitStartUrl: URL? = nil) -> URL {
    let starts = [
        explicitStartUrl,
        URL(filePath: #filePath),
        URL(filePath: FileManager.default.currentDirectoryPath),
    ].compactMap { $0 }

    for start in starts {
        if let url = findDefaultConfigUrlFromProject(startingAt: start) {
            return url
        }
    }

    return dieT("Can't find resources/default-config.toml from \(starts.map(\.path).joined(separator: ", "))")
}

func getDefaultConfigUrlNextToExecutable(executablePath: String? = CommandLine.arguments.first) -> URL? {
    guard let executablePath, !executablePath.isEmpty else { return nil }

    var executableUrl = URL(filePath: executablePath)
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(atPath: executableUrl.path, isDirectory: &isDirectory),
       !isDirectory.boolValue
    {
        executableUrl.deleteLastPathComponent()
    }

    let candidates = [
        executableUrl.appending(component: "default-config.toml"),
        executableUrl.deletingLastPathComponent().appending(path: "Resources/default-config.toml"),
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
}

private func findDefaultConfigUrlFromProject(startingAt startUrl: URL) -> URL? {
    var url = startUrl
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
        url.deleteLastPathComponent()
    }

    while url.path != url.deletingLastPathComponent().path {
        let configUrl = url.appending(component: "resources/default-config.toml")
        if FileManager.default.fileExists(atPath: url.appending(component: ".git").path),
           FileManager.default.fileExists(atPath: configUrl.path)
        {
            return configUrl
        }
        url.deleteLastPathComponent()
    }
    return nil
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else if let path = ProcessInfo.processInfo.environment["WINMUX_DEFAULT_CONFIG_PATH"], !path.isEmpty {
        return URL(filePath: path)
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for staged raw executables used by the Tart harness.
            ?? getDefaultConfigUrlNextToExecutable()
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    let parsedConfig = parseConfig(Result { try String(contentsOf: defaultConfigUrl, encoding: .utf8) }.getOrDie())
    if !parsedConfig.errors.isEmpty {
        die("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
@MainActor var config: Config = defaultConfig { // todo move to Ctx?
    didSet {
        refreshZoneTopologySnapshot()
    }
}
@MainActor var configUrl: URL = defaultConfigUrl

struct Config: ConvenienceCopyable {
    var configVersion: Int = 1
    var afterLoginCommand: [any Command] = []
    var afterStartupCommand: [any Command] = []
    var _indentForNestedContainersWithTheSameOrientation: Void = ()
    var enableNormalizationFlattenContainers: Bool = true
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var defaultRootContainerLayout: Layout = .tiles
    var defaultRootContainerOrientation: DefaultContainerOrientation = .auto
    var startAtLogin: Bool = false
    var autoReloadConfig: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var shortcutsPreset: ShortcutsPreset = .none
    var tabGroupPadding: Int = 30
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var persistentWorkspaces: OrderedSet<String> = []
    var execOnWorkspaceChange: [String] = [] // todo deprecate
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var onFocusChanged: [any Command] = []
    // var onFocusedWorkspaceChanged: [any Command] = []
    var onFocusedMonitorChanged: [any Command] = []

    var autoAddNewWindowsToTabGroup: Bool = false
    var gaps: Gaps = .zero
    var mouse = MouseConfig()
    var workspaceSidebar = WorkspaceSidebarConfig()
    var windowTabs = WindowTabsConfig()
    var zoneStyles: [ZoneStyleConfig] = []
    var zoneLayouts: [ZoneLayoutConfig] = []
    var zoneScenes: [ZoneSceneConfig] = []
    var zoneBindings: [ZoneBindingConfig] = []
    var zoneAffinities: [ZoneAffinityConfig] = []
    var zoneAvailabilitySets: [ZoneAvailabilitySetConfig] = []
    var zones: [ZoneConfig] = []
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []
    var onModeChanged: [any Command] = []
}

struct MouseConfig: ConvenienceCopyable, Equatable, Sendable {
    var zoneSnap = ZoneSnapConfig()
    var zoneDividerDrag: ZoneDividerDragPolicy = .zoneMode
}

enum ZoneDividerDragPolicy: String, CaseIterable, Equatable, Sendable {
    /// Divider hover chrome and drags are available only while the binding mode named "zone"
    /// is active, so boundaries are inert during normal work.
    case zoneMode = "zone-mode"
    case always
    case off
}

struct ZoneSnapConfig: ConvenienceCopyable, Equatable, Sendable {
    var policy: ZoneSnapPolicy = .freeform
    var modifier: NSEvent.ModifierFlags = .option
    var gesture: ZoneSnapGesture = .drag
    var target: ZoneSnapTarget = .zone
}

enum ZoneSnapPolicy: String, CaseIterable, Equatable, Sendable {
    case freeform
    case snapOnModifier = "snap-on-modifier"
    case snapToZone = "snap-to-zone"
    case floatUnlessSnap = "float-unless-snap"
}

enum ZoneSnapGesture: String, CaseIterable, Equatable, Sendable {
    case drag
    case secondaryButtonDrag = "secondary-button-drag"
}

enum ZoneSnapTarget: String, CaseIterable, Equatable, Sendable {
    case zone
    case window
}

struct ZoneConfig: ConvenienceCopyable, Equatable, Sendable {
    var monitor: MonitorDescription?
    var layoutPreset: String?
    var layout: ZoneLayoutKind?
    var defaultZone: String?
    var columns: [ZoneColumnConfig] = []
}

struct ZoneLayoutConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var layout: ZoneLayoutKind?
    var defaultZone: String?
    var columns: [ZoneColumnConfig] = []
}

struct ZoneSceneConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var layoutPreset: String?
    var workspaces: [ZoneSceneWorkspaceConfig] = []
}

struct ZoneSceneWorkspaceConfig: ConvenienceCopyable, Equatable, Sendable {
    var zone: String = ""
    var workspace: WorkspaceName?
}

struct ZoneBindingConfig: ConvenienceCopyable, Equatable, Sendable {
    var monitor: MonitorDescription?
    var zone: String = ""
    var workspace: WorkspaceName?
}

struct ZoneAffinityConfig: ConvenienceCopyable, Equatable {
    var matcher: WindowDetectedCallbackMatcher = WindowDetectedCallbackMatcher()
    var zone: ZoneSelector?
    var checkFurtherCallbacks: Bool = false
    var focusFollowsWindow: Bool = false
    var failIfNoop: Bool = false
}

struct ZoneStyleConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var color: String = ""
}

struct ZoneAvailabilitySetConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var enabledZones: [String] = []
}

enum ZoneLayoutKind: String, Equatable, Sendable {
    case columns
}

struct ZoneColumnConfig: ConvenienceCopyable, Equatable, Sendable {
    var id: String = ""
    var name: String?
    var width: Double = 0
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}

enum ShortcutsPreset: String, Equatable, Sendable {
    case none
    case rectangle
}

struct WorkspaceSidebarConfig: ConvenienceCopyable, Equatable, Sendable {
    var enabled: Bool = false
    var enableFocus: Bool = false
    var collapsedWidth: Int = 44
    var width: Int = 240
    var monitor: [MonitorDescription] = []
    var showStatusPills: Bool = true
    var showDate: Bool = true
    var menuBarReserveHeight: Int = 28
    var projectDeletionAction: WorkspaceProjectDeletionAction = .closeWindows
    var workspaceLabels: [String: String] = [:]
    var projectLabels: [String: String] = [:]
    var projectColors: [String: String] = [:]
}

enum WorkspaceProjectDeletionAction: String, CaseIterable, Identifiable, Sendable {
    case closeWindows = "close-windows"
    case moveWindowsToFallback = "move-windows-to-fallback"

    var id: String { rawValue }
}

struct WindowTabsConfig: ConvenienceCopyable, Equatable, Sendable {
    var enabled: Bool = true
    var height: Int = 36
}

extension WorkspaceSidebarConfig {
    @MainActor
    func resolvedMonitor(sortedMonitors: [Monitor]) -> Monitor? {
        let sortedPhysicalMonitors = physicalMonitorCandidates(from: sortedMonitors)
        return monitor.lazy
            .compactMap { $0.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) }
            .first
    }

    @MainActor
    func resolvedMonitors(sortedMonitors: [Monitor]) -> [Monitor] {
        let sortedPhysicalMonitors = physicalMonitorCandidates(from: sortedMonitors)
        guard !monitor.isEmpty else { return sortedPhysicalMonitors }
        if monitor == [.main] {
            return sortedPhysicalMonitors
        }
        var seenTopLeftCorners = Set<CGPoint>()
        return monitor
            .compactMap { $0.resolvePhysicalMonitor(sortedPhysicalMonitors: sortedPhysicalMonitors) }
            .filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted }
    }
}

private func physicalMonitorCandidates(from monitors: [Monitor]) -> [Monitor] {
    var seenTopLeftCorners = Set<CGPoint>()
    return sortMonitorsBySpatialOrder(
        monitors.map(\.physicalMonitor)
            .filter { seenTopLeftCorners.insert($0.rect.topLeftCorner).inserted },
    )
}
