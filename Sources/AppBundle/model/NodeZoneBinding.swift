import Common

enum NodeZoneBindingKind: String, Hashable, Sendable {
    case window
    case tabGroup = "tab-group"
}

struct NodeZoneBindingKey: Hashable, Sendable, CustomStringConvertible {
    let kind: NodeZoneBindingKind
    let windowIds: [UInt32]

    var description: String {
        "\(kind.rawValue):\(windowIds.map(String.init).joined(separator: ","))"
    }
}

struct NodeZoneBinding: Sendable {
    let key: NodeZoneBindingKey
    let zoneId: String
    let zoneName: String?
    let physicalMonitorId: Int?
    let physicalIdentity: String
    let workspaceName: String
    let title: String
}

nonisolated(unsafe) private var nodeZoneBindingsByKey: [NodeZoneBindingKey: NodeZoneBinding] = [:]

@MainActor
func resetNodeZoneBindingsForTests() {
    nodeZoneBindingsByKey = [:]
}

@MainActor
func bindNodeToZone(_ window: Window, zone selector: ZoneSelector) async -> Result<NodeZoneBinding, String> {
    pruneStaleNodeZoneBindings()
    let resolved: ResolvedZoneSelector
    switch resolveZoneSelector(selector) {
        case .success(let zone):
            resolved = zone
        case .failure(let message):
            return .failure(message)
    }

    let targetWorkspace = resolved.monitor.activeWorkspace
    let key = nodeZoneBindingKey(for: window)
    let title = await nodeZoneBindingTitle(for: key)
    moveWindowOrTabGroupToWorkspace(window, targetWorkspace, focusFollowsWindow: false)

    let binding = NodeZoneBinding(
        key: key,
        zoneId: resolved.monitor.zoneId.orDie("Resolved zone selector must point at a zone monitor"),
        zoneName: resolved.monitor.zoneName,
        physicalMonitorId: resolved.monitor.physicalMonitor.monitorId_oneBased,
        physicalIdentity: zoneLayoutPhysicalIdentity(for: resolved.monitor.physicalMonitor),
        workspaceName: targetWorkspace.name,
        title: title,
    )
    nodeZoneBindingsByKey[key] = binding
    return .success(binding)
}

@MainActor
func unbindNodeZoneBinding(for window: Window) -> Result<NodeZoneBinding, String> {
    pruneStaleNodeZoneBindings()
    let key = nodeZoneBindingKey(for: window)
    if let removed = nodeZoneBindingsByKey.removeValue(forKey: key) {
        return .success(removed)
    }
    guard let matchingKey = nodeZoneBindingsByKey.keys.first(where: { $0.windowIds.contains(window.windowId) }),
          let removed = nodeZoneBindingsByKey.removeValue(forKey: matchingKey)
    else {
        return .failure("No node zone binding exists for \(key.description)")
    }
    return .success(removed)
}

@MainActor
func nodeZoneBindingRows() -> [NodeZoneBindingListRow] {
    pruneStaleNodeZoneBindings()
    return nodeZoneBindingsByKey.values
        .sorted { $0.key.description < $1.key.description }
        .map { binding in
            NodeZoneBindingListRow(
                binding: binding,
                currentWorkspaceName: currentWorkspaceName(for: binding) ?? binding.workspaceName,
            )
        }
}

struct NodeZoneBindingListRow {
    let binding: NodeZoneBinding
    let currentWorkspaceName: String

    var displayLine: String {
        [
            field("node-id", binding.key.description),
            field("node-type", binding.key.kind.rawValue),
            field("window-ids", binding.key.windowIds.map(String.init).joined(separator: ",")),
            field("title", binding.title),
            field("zone", binding.zoneId),
            field("zone-name", binding.zoneName ?? ""),
            field("workspace", currentWorkspaceName),
            field("monitor", binding.physicalMonitorId.map(String.init) ?? ""),
            field("physical", binding.physicalIdentity),
        ].joined(separator: "|")
    }

    private func field(_ name: String, _ value: String) -> String {
        "\(name)=\(escapeZoneBindingFieldValue(value))"
    }
}

private func escapeZoneBindingFieldValue(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "|", with: "\\|")
        .replacingOccurrences(of: "=", with: "\\=")
}

@MainActor
private func nodeZoneBindingKey(for window: Window) -> NodeZoneBindingKey {
    let node = window.moveNode
    if let container = node as? TilingContainer, container.layout == .tabGroup {
        return NodeZoneBindingKey(
            kind: .tabGroup,
            windowIds: container.allLeafWindowsRecursive.map(\.windowId).sorted(),
        )
    }
    return NodeZoneBindingKey(kind: .window, windowIds: [window.windowId])
}

@MainActor
private func nodeZoneBindingTitle(for key: NodeZoneBindingKey) async -> String {
    var titles: [String] = []
    for windowId in key.windowIds {
        if let window = Window.get(byId: windowId) {
            let title = (try? await window.title) ?? ""
            titles.append(title.isEmpty ? "Window \(windowId)" : title)
        } else {
            titles.append("Window \(windowId)")
        }
    }
    return titles.joined(separator: " + ")
}

@MainActor
private func pruneStaleNodeZoneBindings() {
    nodeZoneBindingsByKey = nodeZoneBindingsByKey.filter { key, _ in
        guard let firstWindow = key.windowIds.compactMap({ Window.get(byId: $0) }).first else {
            return false
        }
        return nodeZoneBindingKey(for: firstWindow) == key
    }
}

@MainActor
private func currentWorkspaceName(for binding: NodeZoneBinding) -> String? {
    guard let firstWindow = binding.key.windowIds.compactMap({ Window.get(byId: $0) }).first,
          nodeZoneBindingKey(for: firstWindow) == binding.key
    else { return nil }
    return firstWindow.moveNode.nodeWorkspace?.name
}
