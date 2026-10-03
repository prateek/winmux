import AppKit
import Common
import Foundation
import os

struct LensCommand: Command {
    let args: LensCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if args.name == nil, args.filter == nil {
            let panel = SwitcherPalettePanel.shared
            guard panel.isPaletteActive else { io.failureExitCode = 2; return io.err("No Lens is open") }
            panel.changePresentationToList()
            return true
        }
        let live = NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue))
        let invocation = lensInvocation ?? StripGesture(keyCode: nil, invoking: live, openedAt: ProcessInfo.processInfo.systemUptime)
        let name = args.name ?? "<ad-hoc>"
        var settings: LensConfig
        if let configured = args.name {
            guard let lens = config.lenses[configured] else { io.failureExitCode = 2; return io.err("No Lens named '\(configured)'") }
            guard lens.enabled else { io.failureExitCode = 2; return io.err("Lens '\(configured)' is disabled") }
            settings = lens
        } else { settings = LensConfig() }
        if let presentation = args.presentation { settings.presentation = presentation }
        if let sort = args.sort { settings.sort = sort.split(separator: ",").map(String.init) }
        let filter = args.filter.map { $0 == "-" ? io.readStdin() : $0 }
        if let filter {
            if case .failure(let failure) = await NickelSupervisor.shared.checkFilter(filter) {
                io.failureExitCode = failure.usageExitCode
                return io.err(failure.message)
            }
        }
        let panel = SwitcherPalettePanel.shared
        if settings.presentation == "strip", panel.cycleStrip(name: name, invocation: invocation) { return true }
        guard let ticket = panel.beginLens(name, toggle: args.name != nil, strip: settings.presentation == "strip" ? invocation : nil) else { return true }
        defer { panel.cancelLensOpening(ticket: ticket) }
        let entries = try await lensWindows(popups: settings.popups)
        let context = try await filterContextRecord(windowRecords: Dictionary(uniqueKeysWithValues: entries.map { ($0.window.windowId, $0.record) }))
        let result = if let filter {
            await NickelSupervisor.shared.evalFilter(filter, context: context.json, windows: entries.map { $0.record.json })
        } else {
            await NickelSupervisor.shared.filter(lens: name, context: context.json, windows: entries.map { $0.record.json })
        }
        let resolution = LensFilterResolution(candidateIds: entries.map { $0.window.windowId }, result: result)
        let ids = Set(resolution.ids)
        let eligible = entries.filter { ids.contains($0.window.windowId) }
        let sorted = sortLensWindows(eligible, by: settings.sort, previousId: context.previous.map { UInt32($0.id) })
        if settings.presentation != "list" && settings.presentation != "miniatures" && settings.presentation != "strip" {
            lensLog.info("Presentation \(settings.presentation, privacy: .public) is not built yet; using list")
            settings.presentation = "list"
        }
        await panel.openLens(name: name, settings: settings, entries: sorted, search: args.search, banner: resolution.banner, context: context.json, ticket: ticket, invocation: invocation)
        return true
    }
}

let lensLog = Logger(subsystem: winMuxAppId, category: "lens")

struct ListLensesCommand: Command {
    let args: ListLensesCmdArgs
    let shouldResetClosedWindowsCache = false
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if args.json {
            return try io.out(String(decoding: JSONEncoder().encode(JSONValue.object(config.lenses.mapValues(\.json))), as: UTF8.self))
        }
        return io.out(config.lenses.keys.sorted().map { "\($0) | \(config.lenses[$0]!.presentation) | \(config.lenses[$0]!.enabled ? "enabled" : "disabled")" })
    }
}

extension NickelFailure {
    var usageExitCode: Int32 {
        if case .diagnostic = self { return 2 }
        return 1
    }
}
