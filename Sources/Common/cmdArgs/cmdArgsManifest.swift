public enum CmdKind: String, CaseIterable, Equatable, Sendable {
    // Sorted

    case agent
    case balanceColumns = "balance-columns"
    case balanceSizes = "balance-sizes"
    case card
    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case column
    case config
    case cycleColumnSnapPolicy = "cycle-column-snap-policy"
    case debugWindows = "debug-windows"
    case doctor
    case enable
    case execAndForget = "exec-and-forget"
    case expose
    case flattenWorkspaceTree = "flatten-workspace-tree"
    case focus
    case focusBackAndForth = "focus-back-and-forth"
    case focusColumn = "focus-column"
    case focusMonitor = "focus-monitor"
    case fullscreen
    case joinWith = "join-with"
    case layout
    case listApps = "list-apps"
    case listCards = "list-cards"
    case listColumns = "list-columns"
    case listExecEnvVars = "list-exec-env-vars"
    case listModes = "list-modes"
    case listMonitors = "list-monitors"
    case listWindows = "list-windows"
    case macosNativeFullscreen = "macos-native-fullscreen"
    case macosNativeMinimize = "macos-native-minimize"
    case mode
    case move = "move"
    case moveMouse = "move-mouse"
    case moveNodeToCard = "move-node-to-card"
    case moveNodeToColumn = "move-node-to-column"
    case moveNodeToMonitor = "move-node-to-monitor"
    case openSidebar = "open-sidebar"
    case palette
    case reloadConfig = "reload-config"
    case resize
    case scene
    case setColumnSnapPolicy = "set-column-snap-policy"
    case split
    case stackWith = "stack-with"
    case subscribe
    case swap
    case triggerBinding = "trigger-binding"
    case volume
}

func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .agent:
                result[kind.rawValue] = SubCommandParser(parseAgentCmdArgs)
            case .balanceColumns:
                result[kind.rawValue] = SubCommandParser(parseBalanceColumnsCmdArgs)
            case .balanceSizes:
                result[kind.rawValue] = SubCommandParser(BalanceSizesCmdArgs.init)
            case .card:
                result[kind.rawValue] = SubCommandParser(parseCardCmdArgs)
            case .close:
                result[kind.rawValue] = SubCommandParser(CloseCmdArgs.init)
            case .closeAllWindowsButCurrent:
                result[kind.rawValue] = SubCommandParser(CloseAllWindowsButCurrentCmdArgs.init)
            case .column:
                result[kind.rawValue] = SubCommandParser(parseColumnCmdArgs)
            case .config:
                result[kind.rawValue] = SubCommandParser(parseConfigCmdArgs)
            case .cycleColumnSnapPolicy:
                result[kind.rawValue] = SubCommandParser(parseCycleColumnSnapPolicyCmdArgs)
            case .debugWindows:
                result[kind.rawValue] = SubCommandParser(DebugWindowsCmdArgs.init)
            case .doctor:
                result[kind.rawValue] = SubCommandParser(parseDoctorCmdArgs)
            case .enable:
                result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case .expose:
                result[kind.rawValue] = SubCommandParser(parseExposeCmdArgs)
            case .flattenWorkspaceTree:
                result[kind.rawValue] = SubCommandParser(FlattenWorkspaceTreeCmdArgs.init)
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusBackAndForth:
                result[kind.rawValue] = SubCommandParser(FocusBackAndForthCmdArgs.init)
            case .focusColumn:
                result[kind.rawValue] = SubCommandParser(parseFocusColumnCmdArgs)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = SubCommandParser(parseFullscreenCmdArgs)
            case .joinWith:
                result[kind.rawValue] = SubCommandParser(JoinWithCmdArgs.init)
            case .layout:
                result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
            case .listApps:
                result[kind.rawValue] = SubCommandParser(parseListAppsCmdArgs)
            case .listCards:
                result[kind.rawValue] = SubCommandParser(parseListCardsCmdArgs)
            case .listColumns:
                result[kind.rawValue] = SubCommandParser(parseListColumnsCmdArgs)
            case .listExecEnvVars:
                result[kind.rawValue] = SubCommandParser(ListExecEnvVarsCmdArgs.init)
            case .listModes:
                result[kind.rawValue] = SubCommandParser(parseListModesCmdArgs)
            case .listMonitors:
                result[kind.rawValue] = SubCommandParser(parseListMonitorsCmdArgs)
            case .listWindows:
                result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
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
            case .moveNodeToCard:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToCardCmdArgs)
            case .moveNodeToColumn:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToColumnCmdArgs)
            case .moveNodeToMonitor:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToMonitorCmdArgs)
            case .openSidebar:
                result[kind.rawValue] = SubCommandParser(OpenSidebarCmdArgs.init)
            case .palette:
                result[kind.rawValue] = SubCommandParser(PaletteCmdArgs.init)
            case .reloadConfig:
                result[kind.rawValue] = SubCommandParser(ReloadConfigCmdArgs.init)
            case .resize:
                result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
            case .scene:
                result[kind.rawValue] = SubCommandParser(parseSceneCmdArgs)
            case .setColumnSnapPolicy:
                result[kind.rawValue] = SubCommandParser(parseSetColumnSnapPolicyCmdArgs)
            case .split:
                result[kind.rawValue] = SubCommandParser(parseSplitCmdArgs)
            case .stackWith:
                result[kind.rawValue] = SubCommandParser(StackWithCmdArgs.init)
            case .subscribe:
                result[kind.rawValue] = SubCommandParser(parseSubscribeCmdArgs)
            case .swap:
                result[kind.rawValue] = SubCommandParser(parseSwapCmdArgs)
            case .triggerBinding:
                result[kind.rawValue] = SubCommandParser(parseTriggerBindingCmdArgs)
            case .volume:
                result[kind.rawValue] = SubCommandParser(VolumeCmdArgs.init)
        }
    }
    return result
}
