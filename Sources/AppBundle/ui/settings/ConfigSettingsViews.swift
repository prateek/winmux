import SwiftUI

struct ShortcutBehaviorSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @AppStorage(ExperimentalUISettings.doubleSidedWindowsKey) private var doubleSidedWindows = false
    var body: some View {
        SettingsPage(title: "Behavior") {
            SettingsValueRow("Tile new windows automatically", config.automaticallyTileNewWindows.yesNo)
            SettingsValueRow("Add new windows to the current tab group", config.autoAddNewWindowsToTabGroup.yesNo)
            SettingsValueRow("Unhide macOS-hidden apps", config.automaticallyUnhideMacosHiddenApps.yesNo)
            Divider()
            SettingsValueRow("Double-sided windows", doubleSidedWindows.yesNo)
            Text("Switch Double-sided windows from the menu bar menu. Option-click or Option-Tab flips a pair; window tabs must be enabled. Rotation uses Screen Recording and respects Reduce Motion.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            SettingsValueRow("Shake to toggle tiling", config.enableShakeToToggleTiling.yesNo)
            SettingsValueRow("Flatten matching containers", config.enableNormalizationFlattenContainers.yesNo)
            SettingsValueRow("Normalize nested orientations", config.enableNormalizationOppositeOrientationForNestedContainers.yesNo)
            SettingsValueRow("Start at login", config.startAtLogin.yesNo)
            SettingsValueRow("Reload config when it changes", config.reloadOnSave.yesNo)
            SettingsValueRow("Restore windows on quit", config.restoreWindowsOnQuit.yesNo)
            SettingsValueRow("Root layout", String(describing: config.defaultRootContainerLayout))
            SettingsValueRow("Root orientation", config.defaultRootContainerOrientation.rawValue)
            SettingsValueRow("Shortcut preset", config.shortcutsPreset.rawValue)
            SettingsValueRow("Persistent workspaces", config.persistentWorkspaces.isEmpty ? "None" : config.persistentWorkspaces.joined(separator: ", "))
        }
    }
}

struct ShortcutAppearanceSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    var body: some View {
        SettingsPage(title: "Appearance") {
            SettingsValueRow("Chrome style", config.workspaceSidebar.chromeStyle.rawValue)
            HStack {
                Text("Solid color")
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(config.workspaceSidebar.solidChromeColor == .custom ? Color(chromeHex: config.workspaceSidebar.solidChromeCustomColor) : config.workspaceSidebar.solidChromeColor.color)
                    .frame(width: 28, height: 20)
                Text(config.workspaceSidebar.solidChromeColor == .custom ? config.workspaceSidebar.solidChromeCustomColor : config.workspaceSidebar.solidChromeColor.title).foregroundStyle(.secondary)
            }
            Divider()
            SettingsValueRow("Show sidebar", config.workspaceSidebar.enabled.yesNo)
            SettingsValueRow("Focus sidebar monitor only", config.workspaceSidebar.enableFocus.yesNo)
            SettingsValueRow("Reveal sidebar at the display edge", config.workspaceSidebar.autoHide.yesNo)
            SettingsValueRow("Keep sidebar expanded", config.workspaceSidebar.alwaysExpanded.yesNo)
            SettingsValueRow("Expanded width", "\(config.workspaceSidebar.width) px")
            SettingsValueRow("Collapsed width", "\(config.workspaceSidebar.collapsedWidth) px")
            SettingsValueRow("Menu bar reserve", "\(config.workspaceSidebar.menuBarReserveHeight) px")
            SettingsValueRow("Deleting projects", config.workspaceSidebar.projectDeletionAction.rawValue)
            SettingsValueRow("Show status pills", config.workspaceSidebar.showStatusPills.yesNo)
            SettingsValueRow("Show clock / seconds", "\(config.workspaceSidebar.showClock.yesNo) / \(config.workspaceSidebar.showSeconds.yesNo)")
            SettingsValueRow("Show date / weekday", "\(config.workspaceSidebar.showDate.yesNo) / \(config.workspaceSidebar.showWeekday.yesNo)")
            Divider()
            SettingsValueRow("Show tab strips", config.windowTabs.enabled.yesNo)
            SettingsValueRow("Tab strip height", "\(config.windowTabs.height) px")
            SettingsValueRow("Tab group padding", "\(config.tabGroupPadding) px")
            Divider()
            SettingsValueRow("Inner horizontal gap", gap(config.gaps.inner.horizontal))
            SettingsValueRow("Inner vertical gap", gap(config.gaps.inner.vertical))
            SettingsValueRow("Outer left gap", gap(config.gaps.outer.left))
            SettingsValueRow("Outer right gap", gap(config.gaps.outer.right))
            SettingsValueRow("Outer top gap", gap(config.gaps.outer.top))
            SettingsValueRow("Outer bottom gap", gap(config.gaps.outer.bottom))
        }
    }

    private func gap(_ value: DynamicConfigValue<Int>) -> String {
        switch value {
            case .constant(let value): "\(value) px"
            case .perMonitor(let rules, let fallback):
                "\(fallback) px default; " + rules.map { "\($0.description): \($0.value) px" }.joined(separator: ", ")
        }
    }
}

private extension Bool {
    var yesNo: String { self ? "On" : "Off" }
}
