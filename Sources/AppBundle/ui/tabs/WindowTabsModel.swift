import AppKit

@MainActor
func updateWindowTabModel() async {
    WindowTabHintController.shared.reconcile()
    let didClearMouseInteractionChromeSuppression =
        WindowTabStripPanelController.shared.clearMouseInteractionChromeSuppressionIfInactive()
    guard TrayMenuModel.shared.isEnabled, config.windowTabs.enabled else {
        TrayMenuModel.shared.setIfChanged(\.windowTabStrips, [])
        WindowTabStripPanelController.shared.refresh()
        debugFocusLog("updateWindowTabModel disabled -> cleared")
        return
    }
    pruneCachedWindowTitles()

    let built = await buildWindowTabStripViewModelsFromChromeItems()
    WindowTabHintController.shared.reconcile()
    let strips = WindowTabHintController.shared.applyingLabels(to: built)

    if TrayMenuModel.shared.windowTabStrips != strips {
        debugFocusLog("updateWindowTabModel apply strips old=\(TrayMenuModel.shared.windowTabStrips.map(\.frame)) new=\(strips.map(\.frame))")
        TrayMenuModel.shared.windowTabStrips = strips
        WindowTabStripPanelController.shared.refresh()
    } else {
        if didClearMouseInteractionChromeSuppression {
            WindowTabStripPanelController.shared.refresh()
        }
        debugFocusLog("updateWindowTabModel unchanged strips=\(strips.map(\.frame))")
    }
}
