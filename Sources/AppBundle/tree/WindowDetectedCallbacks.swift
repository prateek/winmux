@MainActor
func tryOnWindowDetected(_ window: Window) async throws {
    guard !window.arriveHandled, let workspace = window.nodeWorkspace else { return }
    window.arriveHandled = true
    try await ColumnPolicy.arrive(window, on: workspace, floatingDefault: window.isFloating)
    broadcastEvent(.windowDetected(windowId: window.windowId, workspace: window.nodeWorkspace?.name,
        appBundleId: window.app.rawAppBundleId, appName: window.app.name))
}
