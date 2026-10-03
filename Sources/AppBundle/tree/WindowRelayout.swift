extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false, runPlace: Bool = true) async throws {
        let location = ColumnPolicy.Location(self)
        let classification = forceTile ? AxUiElementWindowType.window : try await nativeWindowType
        guard location.contains(self) else { return }
        switch classification {
            case .popup:
                bind(to: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            case .dialog:
                bindAsFloatingWindow(to: workspace)
            case .window:
                if !forceTile && !config.automaticallyTileNewWindows { bindAsFloatingWindow(to: workspace) }
                else if runPlace, workspace.columns != nil { try await ColumnPolicy.place(self, on: workspace) }
                else { bind(to: bindingDataForNewTilingWindow(workspace, window: self)) }
        }
    }
}
