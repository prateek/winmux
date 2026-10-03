extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false, runPlace: Bool = true) async throws {
        if runPlace, forceTile, workspace.columns != nil {
            try await ColumnPolicy.place(self, on: workspace)
            return
        }
        let data = forceTile
            ? bindingDataForNewTilingWindow(workspace, window: self)
            : try await unbindAndGetBindingDataForNewWindow(self.asMacWindow().windowId, self.asMacWindow().macApp, workspace, window: self)
        if runPlace, data.parent is TilingContainer, workspace.columns != nil {
            try await ColumnPolicy.place(self, on: workspace)
        } else { bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index) }
    }
}
