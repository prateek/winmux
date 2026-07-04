import AppKit
import Common
import Foundation

struct CardCommand: Command {
    let args: CardCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch args.target.val {
            case .relative, .direct:
                return runNavigate(env, io)
            case .backAndForth:
                return prevFocusedWorkspace?.focusWorkspace() ?? false
            case .summon(let name):
                return runSummon(name: name, io: io)
            case .move(let monitorTarget):
                return runMove(monitorTarget: monitorTarget, env: env, io: io)
        }
    }

    @MainActor
    private func runNavigate(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let focusedWs = target.workspace
        switch resolveWorkspaceTarget(from: focusedWs, io: io) {
            case .focus(let workspace):
                return focusOrReportNoop(workspace, focusedWorkspace: focusedWs, io: io, failIfNoop: args.failIfNoop)
            case .backAndForth:
                return prevFocusedWorkspace?.focusWorkspace() ?? false
            case .error:
                return false
        }
    }

    @MainActor
    private func runSummon(name: WorkspaceName, io: CmdIo) -> Bool {
        guard let workspace = Workspace.existing(byName: name.raw),
              isUserFacingWorkspace(workspace, focusedWorkspace: focus.workspace)
        else {
            return io.err("Card '\(name.raw)' doesn't exist")
        }
        let monitor = focus.workspace.workspaceMonitor
        if monitor.activeWorkspace == workspace {
            if !args.failIfNoop {
                io.err("Card '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code")
            }
            return !args.failIfNoop
        }
        if activateWorkspaceOnMonitorPreservingSourceViewport(workspace, targetMonitor: monitor) {
            return workspace.focusWorkspace()
        } else {
            return io.err("Can't move card '\(workspace.name)' to monitor '\(monitor.name)'. workspace-to-monitor-force-assignment doesn't allow it")
        }
    }

    @MainActor
    private func runMove(monitorTarget: MonitorTarget, env: CmdEnv, io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let focusedWorkspace = target.workspace
        let prevMonitor = focusedWorkspace.workspaceMonitor

        switch monitorTarget.resolve(target.workspace.workspaceMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                if monitorTarget.resolvesPhysicalMonitorSelector
                    ? targetMonitor.hasSamePhysicalMonitor(as: prevMonitor)
                    : targetMonitor.hasSameWorkspaceViewport(as: prevMonitor)
                {
                    return true
                }
                if activateWorkspaceOnMonitorPreservingSourceViewport(focusedWorkspace, targetMonitor: targetMonitor) {
                    return true
                } else {
                    return io.err(
                        "Can't move card '\(focusedWorkspace.name)' to monitor '\(targetMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it",
                    )
                }
            case .failure(let msg):
                return io.err(msg)
        }
    }

    private enum ResolvedWorkspaceTarget {
        case focus(Workspace)
        case backAndForth
        case error
    }

    @MainActor
    private func resolveWorkspaceTarget(from focusedWs: Workspace, io: CmdIo) -> ResolvedWorkspaceTarget {
        switch args.target.val {
            case .relative(let nextPrev):
                guard let workspace = getNextPrevWorkspace(
                    current: focusedWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                )
                    ?? createNextTransientBlankWorkspaceIfAllowed(
                        from: focusedWs,
                        isNext: nextPrev == .next,
                        wrapAround: args.wrapAround,
                        usesStdin: args.useStdin,
                    ) else {
                    return .error
                }
                return .focus(workspace)
            case .direct(let name):
                return resolveDirectWorkspaceTarget(named: name.raw, from: focusedWs, io: io)
            default:
                return .error
        }
    }

    @MainActor
    private func resolveDirectWorkspaceTarget(named workspaceName: String, from focusedWs: Workspace, io: CmdIo) -> ResolvedWorkspaceTarget {
        if let workspace = findDirectWorkspaceTarget(named: workspaceName, from: focusedWs) {
            return args.autoBackAndForth && workspace == focusedWs ? .backAndForth : .focus(workspace)
        }
        if args.autoBackAndForth && focusedWs.name == workspaceName {
            return .backAndForth
        }
        guard let workspace = createAdjacentTransientBlankWorkspaceIfAllowed(
            named: workspaceName,
            from: focusedWs,
            among: deckNavigationWorkspaces(from: focusedWs),
        ) else {
            _ = io.err("Card '\(workspaceName)' doesn't exist")
            return .error
        }
        return .focus(workspace)
    }
}

private extension MonitorTarget {
    var resolvesPhysicalMonitorSelector: Bool {
        if case .patterns = self { return true }
        return false
    }
}

@MainActor
private func focusOrReportNoop(
    _ workspace: Workspace,
    focusedWorkspace: Workspace,
    io: CmdIo,
    failIfNoop: Bool,
) -> Bool {
    if focusedWorkspace == workspace {
        if !failIfNoop {
            io.err("Card '\(workspaceDisplayName(workspace.name))' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
        }
        return !failIfNoop
    }
    return workspace.focusWorkspace()
}

@MainActor
private func createNextTransientBlankWorkspaceIfAllowed(
    from current: Workspace,
    isNext: Bool,
    wrapAround: Bool,
    usesStdin: Bool,
) -> Workspace? {
    guard isNext, !wrapAround, !usesStdin else { return nil }
    let deckWorkspaces = deckNavigationWorkspaces(from: current)
    return createAdjacentTransientBlankWorkspaceIfAllowed(
        named: String(deckWorkspaces.count + 1),
        from: current,
        among: deckWorkspaces,
    )
}

/// The current card's column deck, filtered to user-facing cards. Equals the focused
/// column's deck whenever the current card is visible.
@MainActor
func deckNavigationWorkspaces(from current: Workspace) -> [Workspace] {
    let columnKey = winMuxWorkspaceState.columnDecks.columnKey(of: current.id)
        ?? columnDeckKey(for: current.workspaceMonitor)
    return userFacingWorkspaces(orderedDeckWorkspaces(inColumn: columnKey), focusedWorkspace: current)
}

@MainActor
private func findDirectWorkspaceTarget(named workspaceName: String, from current: Workspace) -> Workspace? {
    if let targetIndex = parsePositiveWorkspaceDisplayIndex(workspaceName) {
        if let workspace = deckNavigationWorkspaces(from: current).getOrNil(atIndex: targetIndex - 1) {
            return workspace
        }
        guard let workspace = Workspace.existing(byName: workspaceName),
              workspace.projectId == current.projectId,
              isUserFacingWorkspace(workspace, focusedWorkspace: current)
        else {
            return nil
        }
        guard !workspace.usesAutomaticDisplayName else {
            return nil
        }
        return workspace
    }

    guard let workspace = Workspace.existing(byName: workspaceName),
          isUserFacingWorkspace(workspace, focusedWorkspace: current)
    else {
        return nil
    }
    return workspace
}

private struct RelativeWorkspaceNavigation {
    let workspaces: [Workspace]
    let anchorIndex: Int
}

@MainActor
private func resolveRelativeWorkspaceCandidates(current: Workspace, stdin: String?) -> [Workspace] {
    if let stdin {
        var seen: Set<Workspace> = []
        return stdin
            .split(separator: "\n")
            .map { String($0).trim() }
            .filter { !$0.isEmpty }
            .compactMap { workspaceName in
                guard let workspace = Workspace.existing(byName: workspaceName),
                      isUserFacingWorkspace(workspace, focusedWorkspace: current),
                      seen.insert(workspace).inserted
                else {
                    return nil
                }
                return workspace
            }
    }

    return deckNavigationWorkspaces(from: current)
}

@MainActor
private func resolveRelativeWorkspaceNavigation(
    workspaces: [Workspace],
    current: Workspace,
    isNext: Bool,
    stdinProvided: Bool,
) -> RelativeWorkspaceNavigation {
    if let anchorIndex = workspaces.firstIndex(of: current) {
        return RelativeWorkspaceNavigation(workspaces: workspaces, anchorIndex: anchorIndex)
    }

    if stdinProvided, workspaces == workspaces.sorted() {
        let anchored = (workspaces + [current]).sorted()
        return RelativeWorkspaceNavigation(
            workspaces: anchored,
            anchorIndex: anchored.firstIndex(of: current).orDie(),
        )
    }

    return isNext
        ? RelativeWorkspaceNavigation(workspaces: [current] + workspaces, anchorIndex: 0)
        : RelativeWorkspaceNavigation(workspaces: workspaces + [current], anchorIndex: workspaces.count)
}

@MainActor
func getNextPrevWorkspace(current: Workspace, isNext: Bool, wrapAround: Bool, stdin: String?) -> Workspace? {
    let workspaces = resolveRelativeWorkspaceCandidates(current: current, stdin: stdin)
    guard !workspaces.isEmpty else { return nil }

    let navigation = resolveRelativeWorkspaceNavigation(
        workspaces: workspaces,
        current: current,
        isNext: isNext,
        stdinProvided: stdin != nil,
    )
    let targetIndex = isNext ? navigation.anchorIndex + 1 : navigation.anchorIndex - 1
    return wrapAround
        ? navigation.workspaces.get(wrappingIndex: targetIndex)
        : navigation.workspaces.getOrNil(atIndex: targetIndex)
}
