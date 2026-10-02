import SwiftUI

struct ShortcutBehaviorSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var doubleSidedWindows = ExperimentalUISettings().doubleSidedWindows
    @State private var automaticallyTileNewWindows = config.automaticallyTileNewWindows
    @State private var autoAddNewWindowsToTabGroup = config.autoAddNewWindowsToTabGroup
    @State private var enableShakeToToggleTiling = config.enableShakeToToggleTiling
    @State private var automaticallyUnhideMacosHiddenApps = config.automaticallyUnhideMacosHiddenApps
    @State private var reloadOnSave = config.reloadOnSave
    @State private var startAtLogin = config.startAtLogin
    @State private var defaultLayout = config.defaultRootContainerLayout
    @State private var defaultOrientation = config.defaultRootContainerOrientation
    @State private var flattenContainers = config.enableNormalizationFlattenContainers
    @State private var normalizeNestedContainers = config.enableNormalizationOppositeOrientationForNestedContainers
    @State private var shortcutsPreset = config.shortcutsPreset.rawValue
    @State private var persistentWorkspaces = config.persistentWorkspaces.joined(separator: ", ")

    var body: some View {
        SettingsScrollView {
            SettingsSection("New windows") {
                SettingsToggle("Tile new windows automatically", isOn: $automaticallyTileNewWindows, help: "Place new windows in the current tiled layout.")
                SettingsToggle("Add new windows to the current tab group", isOn: $autoAddNewWindowsToTabGroup, help: "Keep new windows in the selected stack instead of creating a new tile.")
                SettingsToggle("Unhide macOS-hidden apps", isOn: $automaticallyUnhideMacosHiddenApps, help: "Restore apps macOS has hidden when they receive focus.")
            }
            SettingsSection("Window pairs", readOnly: false) {
                SettingsToggle("Double-sided windows", isOn: $doubleSidedWindows, help: "Replace two-window tab strips with two sides. Option-click anywhere in the window or press Option-Tab to flip.") {
                    var settings = ExperimentalUISettings()
                    settings.doubleSidedWindows = doubleSidedWindows
                    if doubleSidedWindows { requestScreenRecordingPermissionsIfNeeded() }
                    scheduleRefreshSession(.menuBarButton)
                }
                Text("Option-click anywhere in the window or press Option-Tab to flip between two windows. Three or more windows use tabs. Window tabs must be enabled. Rotation uses Screen Recording access and respects Reduce Motion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
            }
            SettingsSection("Interaction") {
                SettingsToggle("Shake to toggle tiling", isOn: $enableShakeToToggleTiling, help: "Shake a window by its title bar to switch between floating and tiled.")
                SettingsToggle("Flatten matching containers", isOn: $flattenContainers, help: "Simplify adjacent containers with the same layout orientation.")
                SettingsToggle("Normalize nested orientations", isOn: $normalizeNestedContainers, help: "Avoid nested tiled containers with the same orientation.")
            }
            SettingsSection("Startup") {
                SettingsToggle("Start at login", isOn: $startAtLogin, help: "Launch WinMux after you sign in.")
                SettingsToggle("Reload config when it changes", isOn: $reloadOnSave, help: "Apply valid edits to the config file and the files it imports when they are saved.")
            }
            SettingsSection("Default layout") {
                SettingsPicker("Root layout", selection: $defaultLayout, help: "Used for new workspaces.") {
                    Text("Tiles").tag(Layout.tiles)
                    Text("Tab group").tag(Layout.tabGroup)
                }
                SettingsPicker("Root orientation", selection: $defaultOrientation, help: "Controls how new tiled containers split.") {
                    Text("Automatic").tag(DefaultContainerOrientation.auto)
                    Text("Horizontal").tag(DefaultContainerOrientation.horizontal)
                    Text("Vertical").tag(DefaultContainerOrientation.vertical)
                }
                SettingsPicker("Shortcut preset", selection: $shortcutsPreset, help: "Install the built-in default shortcut set, or use your own.") {
                    Text("Custom").tag("none")
                    Text("Rectangle").tag("rectangle")
                }
            }
            SettingsSection("Workspaces") {
                SettingsTextField("Persistent workspaces", text: $persistentWorkspaces, help: "Comma-separated workspace names that remain available when empty.")
            }
        }
    }
}

struct ShortcutAppearanceSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var sidebarEnabled = config.workspaceSidebar.enabled
    @State private var sidebarFocusEnabled = config.workspaceSidebar.enableFocus
    @State private var sidebarAutoHide = config.workspaceSidebar.autoHide
    @State private var sidebarAlwaysExpanded = config.workspaceSidebar.alwaysExpanded
    @State private var showStatusPills = config.workspaceSidebar.showStatusPills
    @State private var showClock = config.workspaceSidebar.showClock
    @State private var showSeconds = config.workspaceSidebar.showSeconds
    @State private var showDate = config.workspaceSidebar.showDate
    @State private var showWeekday = config.workspaceSidebar.showWeekday
    @State private var chromeStyle = config.workspaceSidebar.chromeStyle
    @State private var solidChromeColor = config.workspaceSidebar.solidChromeColor
    @State private var solidChromeCustomColor = config.workspaceSidebar.solidChromeCustomColor
    @State private var sidebarWidth = config.workspaceSidebar.width
    @State private var collapsedWidth = config.workspaceSidebar.collapsedWidth
    @State private var tabEnabled = config.windowTabs.enabled
    @State private var tabHeight = config.windowTabs.height
    @State private var tabPadding = config.tabGroupPadding
    @State private var menuBarReserveHeight = config.workspaceSidebar.menuBarReserveHeight
    @State private var projectDeletionAction = config.workspaceSidebar.projectDeletionAction
    @State private var innerHorizontalGap = settingsConstantValue(config.gaps.inner.horizontal)
    @State private var innerVerticalGap = settingsConstantValue(config.gaps.inner.vertical)
    @State private var outerLeftGap = settingsConstantValue(config.gaps.outer.left)
    @State private var outerRightGap = settingsConstantValue(config.gaps.outer.right)
    @State private var outerTopGap = settingsConstantValue(config.gaps.outer.top)
    @State private var outerBottomGap = settingsConstantValue(config.gaps.outer.bottom)

    var body: some View {
        SettingsScrollView {
            SettingsSection("Chrome") {
                SettingsPicker("Style", selection: $chromeStyle, help: "Apply Liquid Glass or an opaque solid color to the sidebar, tab groups, and switcher. Settings keep their own appearance.") {
                    Text("Liquid Glass").tag(ChromeStyle.liquidGlass)
                    Text("Solid color").tag(ChromeStyle.solid)
                }
                SettingsSolidColorPalette(
                    selection: $solidChromeColor,
                    customColor: $solidChromeCustomColor,
                    isEnabled: chromeStyle == .solid,
                )
            }
            SettingsSection("Sidebar") {
                SettingsToggle("Show sidebar", isOn: $sidebarEnabled, help: "Show the workspace rail on configured displays.")
                SettingsToggle("Focus sidebar monitor only", isOn: $sidebarFocusEnabled, help: "Show the sidebar only on the focused monitor when monitor scope allows it.")
                SettingsToggle("Reveal sidebar at the display edge", isOn: $sidebarAutoHide, help: "Hide the compact rail until the pointer reaches the left edge.")
                SettingsToggle("Keep sidebar expanded", isOn: $sidebarAlwaysExpanded, help: "Reserve the full sidebar width for tiled windows.")
                SettingsStepper("Expanded width", value: $sidebarWidth, range: 120...480, help: "Width of the fully expanded sidebar.")
                SettingsStepper("Collapsed width", value: $collapsedWidth, range: 28...120, help: "Width of the compact sidebar rail.")
                SettingsStepper("Menu bar reserve", value: $menuBarReserveHeight, range: 0...72, help: "Use 0 px when the macOS menu bar auto-hides.")
                SettingsPicker("Deleting projects", selection: $projectDeletionAction, help: "Choose what happens to the project's windows.") {
                    Text("Close project windows").tag(WorkspaceProjectDeletionAction.closeWindows)
                    Text("Move windows elsewhere").tag(WorkspaceProjectDeletionAction.moveWindowsToFallback)
                }
            }
            SettingsSection("Sidebar content") {
                SettingsToggle("Show status pills", isOn: $showStatusPills)
                SettingsToggle("Show clock", isOn: $showClock)
                SettingsToggle("Show seconds", isOn: $showSeconds)
                SettingsToggle("Show date", isOn: $showDate)
                SettingsToggle("Show weekday", isOn: $showWeekday)
            }
            SettingsSection("Window tabs") {
                SettingsToggle("Show tab strips", isOn: $tabEnabled, help: "Display browser-like tabs for stacked windows.")
                SettingsStepper("Tab strip height", value: $tabHeight, range: 21...80, help: "Height of the window tab strip.")
                SettingsStepper("Tab group padding", value: $tabPadding, range: 0...80, help: "Space around tab groups.")
            }
            SettingsSection("Tiling gaps") {
                SettingsStepper("Inner horizontal", value: $innerHorizontalGap, range: 0...80, help: "Space between windows side by side.")
                SettingsStepper("Inner vertical", value: $innerVerticalGap, range: 0...80, help: "Space between vertically stacked windows.")
                SettingsStepper("Outer left", value: $outerLeftGap, range: 0...120, help: "Inset at the left display edge.")
                SettingsStepper("Outer right", value: $outerRightGap, range: 0...120, help: "Inset at the right display edge.")
                SettingsStepper("Outer top", value: $outerTopGap, range: 0...120, help: "Inset at the top display edge.")
                SettingsStepper("Outer bottom", value: $outerBottomGap, range: 0...120, help: "Inset at the bottom display edge.")
            }
        }
    }
}

struct ShortcutAutomationSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel
    @State private var workspaceCommands = ""
    @State private var focusCommands = ""
    @State private var monitorCommands = ""
    @State private var modeCommands = ""

    var body: some View {
        SettingsScrollView {
            SettingsSection("Event actions") {
                SettingsMultilineField("On workspace change", text: $workspaceCommands, help: "One command per line. Commands run after changing workspaces.")
                SettingsMultilineField("On focus change", text: $focusCommands, help: "One command per line. Commands run after the focused window changes.")
                SettingsMultilineField("On focused monitor change", text: $monitorCommands, help: "One command per line. Commands run after the active display changes.")
                SettingsMultilineField("On mode change", text: $modeCommands, help: "One command per line. Commands run after a mode changes.")
            }
        }
        .task { loadCommands() }
        .id(model.settingsRevision)
    }

    private func loadCommands() {
        workspaceCommands = config.execOnWorkspaceChange.joined(separator: "\n")
        focusCommands = config.onFocusChanged.map { $0.args.description }.joined(separator: "\n")
        monitorCommands = config.onFocusedMonitorChanged.map { $0.args.description }.joined(separator: "\n")
        modeCommands = config.onModeChanged.map { $0.args.description }.joined(separator: "\n")
    }
}

private struct SettingsScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    /// Settings that live in the config file are shown and cannot be changed here.
    let readOnly: Bool
    @ViewBuilder let content: Content
    init(_ title: String, readOnly: Bool = true, @ViewBuilder content: () -> Content) { self.title = title; self.readOnly = readOnly; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content
            }
            .disabled(readOnly)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: StrokeToken.hairline)
            }
        }
    }
}

private struct SettingsToggle: View {
    let title: String; @Binding var isOn: Bool; var help: String? = nil; let save: () -> Void
    init(_ title: String, isOn: Binding<Bool>, help: String? = nil, save: @escaping () -> Void = {}) { self.title = title; _isOn = isOn; self.help = help; self.save = save }
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .help(help ?? title)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 14)
        }
        .onChange(of: isOn) { _ in save() }
    }
}

private struct SettingsStepper: View {
    let title: String; @Binding var value: Int; let range: ClosedRange<Int>; let help: String
    init(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, help: String) {
        self.title = title
        _value = value
        self.range = range
        self.help = help
    }
    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound))
                .frame(width: 96)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Stepper("", value: $value, in: range)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .help(help)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 14)
        }
    }
}

private struct SettingsTextField: View {
    let title: String; @Binding var text: String; let help: String
    init(_ title: String, text: Binding<String>, help: String) { self.title = title; _text = text; self.help = help }
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 230)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
        .help(help)
    }
}

private struct SettingsMultilineField: View {
    let title: String; @Binding var text: String; let help: String
    init(_ title: String, text: Binding<String>, help: String) { self.title = title; _text = text; self.help = help }
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title); Text(help).font(.caption).foregroundStyle(.secondary); TextEditor(text: $text).font(.system(size: 12, design: .monospaced)).frame(minHeight: 50).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor))) }.padding(12) }
}

private struct SettingsPicker<Selection: Hashable, Content: View>: View {
    let title: String; @Binding var selection: Selection; let help: String; @ViewBuilder let content: Content
    init(_ title: String, selection: Binding<Selection>, help: String, @ViewBuilder content: () -> Content) { self.title = title; _selection = selection; self.help = help; self.content = content() }
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("", selection: $selection, content: { content })
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .help(help)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 14)
        }
    }
}

private struct SettingsSolidColorPalette: View {
    @Binding var selection: ChromeSolidColor
    @Binding var customColor: String
    let isEnabled: Bool
    private let columns = Array(repeating: GridItem(.flexible(minimum: 40), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Solid color")
            Text("Choose an opaque chrome color.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ChromeSolidColor.allCases) { color in
                    Button {
                        selection = color
                    } label: {
                        GlassSurface(
                            shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                            hasBorder: false,
                            style: .solid,
                            solidColor: color == .custom ? Color(chromeHex: customColor) : color.color,
                        )
                            .frame(height: 42)
                            .overlay {
                                if selection == color {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.4), radius: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(color.title)
                    .accessibilityLabel(color.title)
                    .accessibilityAddTraits(selection == color ? .isSelected : [])
                }
            }
            if selection == .custom {
                ColorPicker("Custom color", selection: Binding(
                    get: { Color(chromeHex: customColor) },
                    set: { customColor = $0.chromeHex },
                ), supportsOpacity: false)
            }
        }
        .padding(14)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 14)
        }
    }
}

private func settingsConstantValue(_ value: DynamicConfigValue<Int>) -> Int {
    switch value {
        case .constant(let value): value
        case .perMonitor(_, let `default`): `default`
    }
}
