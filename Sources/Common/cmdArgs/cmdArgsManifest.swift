public enum CmdKind: String, CaseIterable, Equatable, Sendable {
    // Sorted

    case agent
    case applyZoneBindings = "apply-zone-bindings"
    case balanceSizes = "balance-sizes"
    case balanceZones = "balance-zones"
    case bindNodeToZone = "bind-node-to-zone"
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case config
    case cycleZoneAvailability = "cycle-zone-availability"
    case cycleZoneLayout = "cycle-zone-layout"
    case debugWindows = "debug-windows"
    case disableZone = "disable-zone"
    case doctor
    case enable
    case enableZone = "enable-zone"
    case execAndForget = "exec-and-forget"
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case focusBackAndForth = "focus-back-and-forth"
    case focusMonitor = "focus-monitor"
    case focusZone = "focus-zone"
    case fullscreen
    case joinWith = "join-with"
    case layout
    case listApps = "list-apps"
    case listExecEnvVars = "list-exec-env-vars"
    case listModes = "list-modes"
    case listMonitors = "list-monitors"
    case listWindows = "list-windows"
    case listWorkspaces = "list-workspaces"
    case listZoneBindings = "list-zone-bindings"
    case listZones = "list-zones"
    case macosNativeFullscreen = "macos-native-fullscreen"
    case macosNativeMinimize = "macos-native-minimize"
    case mode
    case move = "move"
    case moveMouse = "move-mouse"
    case moveNodeToMonitor = "move-node-to-monitor"
    case moveNodeToProject = "move-node-to-project"
    case moveNodeToWorkspace = "move-node-to-workspace"
    case moveNodeToZone = "move-node-to-zone"
    case moveWorkspaceToMonitor = "move-workspace-to-monitor"
    case openSidebar = "open-sidebar"
    case palette
    case project
    case reloadConfig = "reload-config"
    case resize
    case resizeZone = "resize-zone"
    case setZoneStyle = "set-zone-style"
    case split
    case stackWith = "stack-with"
    case subscribe
    case summonWorkspace = "summon-workspace"
    case swap
    case toggleZone = "toggle-zone"
    case triggerBinding = "trigger-binding"
    case unbindNodeZoneBinding = "unbind-node-zone-binding"
    case useZoneAvailability = "use-zone-availability"
    case useZoneLayout = "use-zone-layout"
    case useZoneScene = "use-zone-scene"
    case volume
    case workspace
    case workspaceBackAndForth = "workspace-back-and-forth"
}

func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .agent:
                result[kind.rawValue] = SubCommandParser(parseAgentCmdArgs)
            case .applyZoneBindings:
                result[kind.rawValue] = SubCommandParser(parseApplyZoneBindingsCmdArgs)
            case .balanceSizes:
                result[kind.rawValue] = SubCommandParser(BalanceSizesCmdArgs.init)
            case .balanceZones:
                result[kind.rawValue] = SubCommandParser(parseBalanceZonesCmdArgs)
            case .bindNodeToZone:
                result[kind.rawValue] = SubCommandParser(parseBindNodeToZoneCmdArgs)
            case .close:
                result[kind.rawValue] = SubCommandParser(CloseCmdArgs.init)
            case .closeAllWindowsButCurrent:
                result[kind.rawValue] = SubCommandParser(CloseAllWindowsButCurrentCmdArgs.init)
            case .config:
                result[kind.rawValue] = SubCommandParser(parseConfigCmdArgs)
            case .cycleZoneAvailability:
                result[kind.rawValue] = SubCommandParser(parseCycleZoneAvailabilityCmdArgs)
            case .cycleZoneLayout:
                result[kind.rawValue] = SubCommandParser(parseCycleZoneLayoutCmdArgs)
            case .debugWindows:
                result[kind.rawValue] = SubCommandParser(DebugWindowsCmdArgs.init)
            case .disableZone:
                result[kind.rawValue] = SubCommandParser(parseDisableZoneCmdArgs)
            case .doctor:
                result[kind.rawValue] = SubCommandParser(DoctorCmdArgs.init)
            case .enable:
                result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
            case .enableZone:
                result[kind.rawValue] = SubCommandParser(parseEnableZoneCmdArgs)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case .flattenWorkspaceTree:
                result[kind.rawValue] = SubCommandParser(FlattenWorkspaceTreeCmdArgs.init)
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusBackAndForth:
                result[kind.rawValue] = SubCommandParser(FocusBackAndForthCmdArgs.init)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .focusZone:
                result[kind.rawValue] = SubCommandParser(parseFocusZoneCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = SubCommandParser(parseFullscreenCmdArgs)
            case .joinWith:
                result[kind.rawValue] = SubCommandParser(JoinWithCmdArgs.init)
            case .layout:
                result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
            case .listApps:
                result[kind.rawValue] = SubCommandParser(parseListAppsCmdArgs)
            case .listExecEnvVars:
                result[kind.rawValue] = SubCommandParser(ListExecEnvVarsCmdArgs.init)
            case .listModes:
                result[kind.rawValue] = SubCommandParser(parseListModesCmdArgs)
            case .listMonitors:
                result[kind.rawValue] = SubCommandParser(parseListMonitorsCmdArgs)
            case .listWindows:
                result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
            case .listWorkspaces:
                result[kind.rawValue] = SubCommandParser(parseListWorkspacesCmdArgs)
            case .listZoneBindings:
                result[kind.rawValue] = SubCommandParser(parseListZoneBindingsCmdArgs)
            case .listZones:
                result[kind.rawValue] = SubCommandParser(parseListZonesCmdArgs)
            case .macosNativeFullscreen:
                result[kind.rawValue] = SubCommandParser(parseMacosNativeFullscreenCmdArgs)
            case .macosNativeMinimize:
                result[kind.rawValue] = SubCommandParser(MacosNativeMinimizeCmdArgs.init)
            case .mode:
                result[kind.rawValue] = SubCommandParser(ModeCmdArgs.init)
            case .move:
                result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
                // deprecated
                result["move-through"] = SubCommandParser(parseMoveCmdArgs)
            case .moveMouse:
                result[kind.rawValue] = SubCommandParser(parseMoveMouseCmdArgs)
            case .moveNodeToMonitor:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToMonitorCmdArgs)
            case .moveNodeToProject:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToProjectCmdArgs)
            case .moveNodeToWorkspace:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
            case .moveNodeToZone:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToZoneCmdArgs)
            case .moveWorkspaceToMonitor:
                result[kind.rawValue] = SubCommandParser(parseWorkspaceToMonitorCmdArgs)
                // deprecated
                result["move-workspace-to-display"] = SubCommandParser(MoveWorkspaceToMonitorCmdArgs.init)
            case .openSidebar:
                result[kind.rawValue] = SubCommandParser(OpenSidebarCmdArgs.init)
            case .palette:
                result[kind.rawValue] = SubCommandParser(PaletteCmdArgs.init)
            case .project:
                result[kind.rawValue] = SubCommandParser(parseProjectCmdArgs)
            case .reloadConfig:
                result[kind.rawValue] = SubCommandParser(ReloadConfigCmdArgs.init)
            case .resize:
                result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
            case .resizeZone:
                result[kind.rawValue] = SubCommandParser(parseResizeZoneCmdArgs)
            case .setZoneStyle:
                result[kind.rawValue] = SubCommandParser(parseSetZoneStyleCmdArgs)
            case .split:
                result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
            case .stackWith:
                result[kind.rawValue] = SubCommandParser(StackWithCmdArgs.init)
            case .subscribe:
                result[kind.rawValue] = SubCommandParser(parseSubscribeCmdArgs)
            case .summonWorkspace:
                result[kind.rawValue] = SubCommandParser(SummonWorkspaceCmdArgs.init)
            case .swap:
                result[kind.rawValue] = SubCommandParser(parseSwapCmdArgs)
            case .toggleZone:
                result[kind.rawValue] = SubCommandParser(parseToggleZoneCmdArgs)
            case .triggerBinding:
                result[kind.rawValue] = SubCommandParser(parseTriggerBindingCmdArgs)
            case .unbindNodeZoneBinding:
                result[kind.rawValue] = SubCommandParser(parseUnbindNodeZoneBindingCmdArgs)
            case .useZoneAvailability:
                result[kind.rawValue] = SubCommandParser(parseUseZoneAvailabilityCmdArgs)
            case .useZoneLayout:
                result[kind.rawValue] = SubCommandParser(parseUseZoneLayoutCmdArgs)
            case .useZoneScene:
                result[kind.rawValue] = SubCommandParser(parseUseZoneSceneCmdArgs)
            case .volume:
                result[kind.rawValue] = SubCommandParser(VolumeCmdArgs.init)
            case .workspace:
                result[kind.rawValue] = SubCommandParser(parseWorkspaceCmdArgs)
            case .workspaceBackAndForth:
                result[kind.rawValue] = SubCommandParser(WorkspaceBackAndForthCmdArgs.init)
        }
    }
    return result
}
