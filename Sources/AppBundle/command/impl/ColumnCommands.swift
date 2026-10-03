import AppKit
import Common

@MainActor private func columnUsage(_ io: CmdIo, _ message: String) -> Bool {
    io.failureExitCode = 2
    return io.err(message)
}

struct FocusColumnCommand: Command {
    let args: FocusColumnCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let ws = target.workspace
        ws.enforceColumnInvariant()
        guard let columns = ws.columns else { return io.err("Columns are off on this workspace") }
        let slot = Int(args.value.val).orDie()
        guard (1...columns.count).contains(slot) else { return columnUsage(io, "Column \(slot) is out of range") }
        if let window = ws.rootTilingContainer.children.first(where: { $0.columnSlot == slot })?.mostRecentWindowRecursive {
            return window.focusWindow()
        }
        _ = ws.focusWorkspace()
        columns.focusedSlot = slot
        columns.lastFocusedWindowSlot = ws.columnSlot(containing: focus.windowOrNil)
        return true
    }
}

struct MoveNodeToColumnCommand: Command {
    let args: MoveNodeToColumnCmdArgs
    let shouldResetClosedWindowsCache = true
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else { return io.err(noWindowIsFocused) }
        let ws = target.workspace
        ws.enforceColumnInvariant()
        guard let columns = ws.columns else { return io.err("Columns are off on this workspace") }
        let slot = Int(args.value.val).orDie()
        guard (1...columns.count).contains(slot) else { return columnUsage(io, "Column \(slot) is out of range") }
        window.unbindFromParent()
        ws.bindToColumn(window, slot: slot)
        ws.normalizeContainers()
        return true
    }
}

struct ColumnWidthCommand: Command {
    let args: ColumnWidthCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let ws = target.workspace
        ws.enforceColumnInvariant()
        guard let columns = ws.columns else { return io.err("Columns are off on this workspace") }
        let slot = (args.windowId ?? env.windowId) != nil
            ? ws.columnSlot(containing: target.windowOrNil) ?? 1
            : columns.focusedSlot ?? ws.columnSlot(containing: target.windowOrNil) ?? 1
        let width = ws.rootTilingContainer.lastAppliedLayoutPhysicalRect?.width ?? ws.workspaceMonitor.visibleRect.width
        if ["next", "prev"].contains(args.value.val) {
            columns.stepWidth(slot: slot, forward: args.value.val == "next", presets: config.columns.widthPresets, availableWidth: width)
        } else {
            columns.setWidth(slot: slot, fraction: CGFloat(Double(args.value.val).orDie()), availableWidth: width)
        }
        ws.enforceColumnInvariant()
        return true
    }
}

struct CompactCommand: Command {
    let args: CompactCmdArgs
    let shouldResetClosedWindowsCache = true
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let ws = target.workspace
        ws.enforceColumnInvariant()
        guard ws.columns != nil else { return io.err("Columns are off on this workspace") }
        for (index, child) in ws.rootTilingContainer.children.enumerated() { child.columnSlot = index + 1 }
        ws.enforceColumnInvariant()
        return true
    }
}

struct ListColumnsCommand: Command {
    let args: ListColumnsCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let ws = target.workspace
        let records = ws.columns.map { columns in
            (1...columns.slotCount).map { slot -> JSONValue in
                let ids = ws.rootTilingContainer.children.first { $0.columnSlot == slot }?.allLeafWindowsRecursive.map { JSONValue.int(Int($0.windowId)) } ?? []
                return .object(["index": .int(slot), "width": .double(Double(columns.widths[slot - 1])), "empty": .bool(ids.isEmpty), "window-ids": .array(ids)])
            }
        } ?? []
        if args.json { return io.out(JSONValue.array(records).prettyPrinted) }
        return io.out(records.map { "\($0["index"]!.prettyPrinted) width \($0["width"]!.prettyPrinted) empty \($0["empty"]!.prettyPrinted) windows \(($0["window-ids"]?.arrayOrNil ?? []).map(\.prettyPrinted).joined(separator: ","))" })
    }
}

struct ColumnCountCommand: Command {
    let args: ColumnCountCmdArgs
    let shouldResetClosedWindowsCache = true
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let count: JSONValue = args.value.val == "off" ? .string("off") : .int(Int(args.value.val).orDie())
        target.workspace.applyColumns(ColumnsConfig(.object(["count": count]), workspaces: nil))
        target.workspace.normalizeContainers()
        return true
    }
}

struct PlaceCommand: Command {
    let args: PlaceCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) async -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else { return io.err("Can't find the window") }
        let ws = focus.workspace
        guard ws.columns != nil else { return io.out(args.json ? "{\"column\":null,\"hook\":null}" : "Columns off; ordinary tree placement") }
        let decision = await ColumnPolicy.decision(window: window, workspace: ws)
        if let failure = decision.failure { return io.err(failure) }
        if args.json { return io.out(decision.json.prettyPrinted) }
        return io.out("column \(decision.slot) (\(decision.target)), overflow \(decision.overflow), hook \(decision.hook ?? "built-in")")
    }
}
