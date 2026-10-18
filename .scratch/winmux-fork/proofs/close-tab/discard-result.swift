@testable import AppBundle

@MainActor
func closeWithoutAwaiting() {
    closeWindowFromTabStrip(999, fallbackWorkspace: "tabs")
}
