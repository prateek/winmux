import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if args.usesLensPipeline { return try await runLensPipeline(io) }
        let focus = focus
        var windows: [Window] = []

        if args.filteringOptions.focused {
            if let window = focus.windowOrNil {
                windows = [window]
            } else {
                return io.err(noWindowIsFocused)
            }
        } else {
            var workspaces: Set<Workspace> = args.filteringOptions.workspaces.isEmpty
                ? userFacingWorkspaces(Workspace.all, focusedWorkspace: focus.workspace).toSet()
                : args.filteringOptions.workspaces
                    .flatMap { filter in
                        switch filter {
                            case .focused: [focus.workspace]
                            case .visible: Workspace.all.filter(\.isVisible)
                            case .name(let name): Workspace.existing(byName: name.raw).map { [$0] } ?? []
                        }
                    }
                    .toSet()
            if !args.filteringOptions.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.filteringOptions.monitors.resolveMonitors(io)
                if monitors.isEmpty { return false }
                workspaces = workspaces.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
            }
            windows = workspaces.flatMap(\.allLeafWindowsRecursive)
            if let pid = args.filteringOptions.pidFilter {
                windows = windows.filter { $0.app.pid == pid }
            }
            if let appId = args.filteringOptions.appIdFilter {
                windows = windows.filter { $0.app.rawAppBundleId == appId }
            }
        }

        if args.outputOnlyCount {
            return io.out("\(windows.count)")
        } else {
            var windowInfos: [(window: Window, title: String)] = []
            for window in windows {
                windowInfos.append((window, try await window.title))
            }
            windowInfos = windowInfos
                .filter { $0.window.isBound }
                .sortedBy([{ $0.window.app.name ?? "" }, \.title])

            return windowInfos.map { FormatObject.window(window: $0.window, title: $0.title) }.writeFormattedOutput(
                to: io,
                format: args.format,
                json: args.json,
                ignoreRightPaddingVar: args._format.isEmpty,
            )
        }
    }
}

extension ListWindowsCommand {
    @MainActor
    private func runLensPipeline(_ io: CmdIo) async throws -> Bool {
        let settings: LensConfig
        if let name = args.lens {
            guard let lens = config.lenses[name] else { io.failureExitCode = 2; return io.err("No Lens named '\(name)'") }
            guard lens.enabled else { io.failureExitCode = 2; return io.err("Lens '\(name)' is disabled") }
            settings = lens
        } else { settings = LensConfig() }
        var entries = try await lensWindows(popups: settings.popups)
        let scope = args.filteringOptions
        if scope.focused {
            guard let focused = focus.windowOrNil else { return io.err(noWindowIsFocused) }
            entries = entries.filter { $0.window.windowId == focused.windowId }
        }
        if !scope.workspaces.isEmpty {
            let names = Set(scope.workspaces.flatMap { filter -> [String] in
                switch filter {
                    case .focused: [focus.workspace.name]
                    case .visible: Workspace.all.filter(\.isVisible).map(\.name)
                    case .name(let name): [name.raw]
                }
            })
            entries = entries.filter { names.contains($0.record.workspace) }
        }
        if !scope.monitors.isEmpty && !scope.monitors.contains(.all) {
            let points = scope.monitors.resolveMonitors(io)
            if points.isEmpty { return false }
            let names = Set(Workspace.all.filter { points.contains($0.workspaceMonitor.rect.topLeftCorner) }.map(\.name))
            entries = entries.filter { names.contains($0.record.workspace) }
        }
        if let pid = scope.pidFilter { entries = entries.filter { $0.record.app.pid == pid } }
        if let app = scope.appIdFilter { entries = entries.filter { $0.record.app.bundleId == app } }
        let context = try await filterContextRecord(windowRecords: Dictionary(uniqueKeysWithValues: entries.map { ($0.window.windowId, $0.record) }))
        let result: Result<[Bool], NickelFailure>
        if let lens = args.lens {
            result = await NickelSupervisor.shared.filter(lens: lens, context: context.json, windows: entries.map { $0.record.json })
        } else if let filter = args.filter {
            let body = filter == "-" ? io.readStdin() : filter
            if case .failure(let failure) = await NickelSupervisor.shared.checkFilter(body) {
                io.failureExitCode = failure.usageExitCode
                return io.err(failure.message)
            }
            result = await NickelSupervisor.shared.evalFilter(body, context: context.json, windows: entries.map { $0.record.json })
        } else { result = .success(Array(repeating: true, count: entries.count)) }
        switch result {
            case .success(let bits): entries = lensFilterMatches(entries, bits: bits)
            case .failure(let failure): io.failureExitCode = failure.usageExitCode; return io.err(failure.message)
        }
        entries = sortLensWindows(entries, by: settings.sort, previousId: context.previous.map { UInt32($0.id) })
        if let search = args.search { entries = searchLensWindows(entries, search: search) }
        if args.outputOnlyCount { return io.out(String(entries.count)) }
        let objects = entries.map { FormatObject.window(window: $0.window, title: $0.record.title) }
        if args.json {
            let extra: [[String: Primitive]] = entries.map { entry in
                guard let match = entry.searchMatch else { return [:] }
                return ["score": .int(match.score), "matched-field": .string(match.matchedField)]
            }
            switch objects.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty, extraFields: extra) {
                case .success(let json): return io.out(json)
                case .failure(let message): return io.err(message)
            }
        }
        return objects.writeFormattedOutput(to: io, format: args.format, json: false, ignoreRightPaddingVar: args._format.isEmpty)
    }
}
