import AppKit
import Common
import Foundation
import os

struct LensCommand: Command {
    let args: LensCmdArgs
    let shouldResetClosedWindowsCache = false
    var canSkipPostCommandRefresh: Bool {
        guard let verb = args.verb else { return false }
        return ["step", "peek", "mark", "sections", "pane", "presentation", "caret", "close"].contains(verb)
    }

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if env.isFromURL, let refusal = urlCommandRefusal(self) { return io.err(refusal) }
        if let verb = args.verb { return try await runVerb(verb, env, io) }
        if args.name == nil, args.filter == nil {
            let panel = SwitcherPalettePanel.shared
            guard panel.isPaletteActive else { io.failureExitCode = 2; return io.err("No Lens is open") }
            panel.changePresentationToList()
            return true
        }
        let name = args.name ?? "<ad-hoc>"
        var settings: LensConfig
        if let configured = args.name {
            guard let lens = config.lenses[configured] else { io.failureExitCode = 2; return io.err("No Lens named '\(configured)'") }
            guard lens.enabled else { io.failureExitCode = 2; return io.err("Lens '\(configured)' is disabled") }
            settings = lens
        } else { settings = LensConfig() }
        if let presentation = args.presentation { settings.presentation = presentation }
        if let sections = args.sections {
            guard settings.presentation != "miniatures" else { io.failureExitCode = 2; return io.err("--sections is not allowed with miniatures") }
            settings.sections = sections
        }
        if let tile = args.tile {
            guard settings.presentation != "miniatures" else { io.failureExitCode = 2; return io.err("--tile is not allowed with miniatures") }
            settings.tile = tile
        }
        if let sort = args.sort { settings.sort = sort.split(separator: ",").map(String.init) }
        let filter = args.filter.map { $0 == "-" ? io.readStdin() : $0 }
        if let filter {
            if case .failure(let failure) = await NickelSupervisor.shared.checkFilter(filter) {
                io.failureExitCode = failure.usageExitCode
                return io.err(failure.message)
            }
        }
        let identity = args.name == nil ? filter.map { LensAdHocIdentity(filter: $0, settings: settings, search: args.search ?? "") } : nil
        let panel = SwitcherPalettePanel.shared
        let now = LensTimebase.now()
        let trace = LensTraceStore.shared.begin(presentation: settings.presentation, origin: lensTraceOrigin ?? LensTraceOrigin(start: now, received: now, source: "internal"))
        trace.advance("binding resolved")
        trace.startInterval("windows collected")
        guard let ticket = panel.beginLens(name, toggle: args.name != nil,
                                          trace: trace, settings: settings, identity: identity) else {
            LensTraceStore.shared.discard(trace)
            return true
        }
        defer { panel.cancelLensOpening(ticket: ticket) }
        let entries = try await lensWindows(popups: settings.popups)
        let context = try await filterContextRecord(windowRecords: Dictionary(uniqueKeysWithValues: entries.map { ($0.window.windowId, $0.record) }))
        trace.advance("windows collected")
        trace.startInterval("Filter evaluated")
        let result = if let filter {
            await NickelSupervisor.shared.evalFilter(filter, context: context.json, windows: entries.map { $0.record.json })
        } else {
            await NickelSupervisor.shared.filter(lens: name, context: context.json, windows: entries.map { $0.record.json })
        }
        trace.advance("Filter evaluated")
        trace.startInterval("session ready")
        let resolution = LensFilterResolution(candidateIds: entries.map { $0.window.windowId }, result: result)
        let ids = Set(resolution.ids)
        let eligible = entries.filter { ids.contains($0.window.windowId) }
        let sorted = sortLensWindows(eligible, by: settings.sort, previousId: context.previous.map { UInt32($0.id) })
        if settings.presentation != "list" && settings.presentation != "miniatures" && settings.presentation != "strip" && settings.presentation != "grid" {
            lensLog.info("Presentation \(settings.presentation, privacy: .public) is not built yet; using list")
            settings.presentation = "list"
        }
        await panel.openLens(name: name, settings: settings, entries: sorted, search: args.search, banner: resolution.banner, context: context.json, ticket: ticket, eventFilter: args.name == nil ? filter : nil)
        return true
    }

    @MainActor private func runVerb(_ verb: String, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let panel = SwitcherPalettePanel.shared
        guard let model = panel.session else { return io.err("No Lens is open") }
        switch verb {
            case "close": panel.dismiss(); try await activateMode(mainModeId)
            case "step": model.step(args.operands[0])
            case "peek": model.send(.peekToggled)
            case "mark": model.toggleMark()
            case "sections": model.changeSections("next")
            case "pane": return io.err("The open Presentation has no panes")
            case "presentation": model.changePresentation(args.operands[0])
            case "caret": panel.moveSearchCaret(args.operands[0])
            case "focus", "summon", "close-window", "run":
                let raw: [String]
                if verb == "run" { raw = args.operands }
                else { raw = [verb == "close-window" ? "close" : verb] }
                if raw == ["focus"] {
                    let ids = model.targets(forCommand: "focus")
                    panel.dismiss()
                    try await activateMode(mainModeId)
                    guard let id = ids.first, let window = Window.get(byId: id) else { return io.err("No selected window") }
                    return try await focusLensWindow(window)
                }
                switch parseCommand(raw) {
                    case .cmd: break
                    case .failure(let error): return io.err(error)
                    case .help: return io.err("A command is required")
                }
                let keepOpen = raw[0] == "close" || raw[0] == "move-node-to-workspace"
                if !keepOpen { panel.dismiss(); try await activateMode(mainModeId) }
                return try await runLensAction([raw.joinArgs()], session: model, io: io, env: env)
            default: return io.err("Unknown Lens verb '\(verb)'")
        }
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
