import AppKit
import Common
import SwiftUI
import QuartzCore

private let switcherPalettePanelId = "WinMux.switcherPalette"

struct SwitcherPaletteItem: Identifiable {
    let id: UInt32
    let title: String
    let appName: String
    let icon: NSImage?
    let workspaceName: String
    var appIdentity: String = ""
    var projectName: String = ""
    var lastFocusedSeq: Int = 0
    let isFocused: Bool
    var miniature: MiniatureWindow? = nil
    var tile = TileEntry(title: "", appName: "")
}

// MARK: - Panel

@MainActor
final class SwitcherPalettePanel: NSPanelHud {
    static let shared = SwitcherPalettePanel(emit: broadcastEvent)
    private let hostingView = LensHostingView(rootView: AnyView(EmptyView()))
    private let lifecycle: LensLifecycle
    private let startupPreparation = LensStartupPreparation()
    private var preparedSession: LensSession?
    private let gridLandingPanel = NSPanelHud()
    private var gridMonitorRect = CGRect.zero
    private var scrollPaging = MiniatureScrollPaging()
    var session: LensSession? { lifecycle.session }
    var isPaletteActive: Bool { session != nil }

    init(emit: @escaping (ServerEvent) -> Void) {
        lifecycle = LensLifecycle(dependencies: .live(), emit: emit, show: { _ in }, hide: {})
        super.init()
        lifecycle.prepare = { [weak self] model in self?.prepare(model) }
        lifecycle.show = { [weak self] model in self?.show(model) }
        lifecycle.finishShow = { [weak self] model, instruction in self?.finishShow(model, instruction: instruction) }
        lifecycle.updatePresentation = { [weak self] model in self?.updateGridFrame(model) }
        lifecycle.hide = { [weak self] in self?.clearPresentation() }
        identifier = NSUserInterfaceItemIdentifier(switcherPalettePanelId)
        hasShadow = true
        isFloatingPanel = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        backgroundColor = .clear
        applyWinMuxLayer(.overlay)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hostingView.onFirstLayout = { [weak self] in
            self?.lifecycle.trace?.advance("first layout")
        }
        hostingView.onFirstFrame = { [weak self] refresh in
            self?.lifecycle.trace?.finish(signal: String(format: "third display-link tick at %.1f ms refresh", refresh * 1000))
        }
        gridLandingPanel.backgroundColor = .clear
        gridLandingPanel.isOpaque = false
        gridLandingPanel.hasShadow = false
        gridLandingPanel.ignoresMouseEvents = true
        gridLandingPanel.applyWinMuxLayer(.overlay)
        gridLandingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hostingView.wantsLayer = true
        contentView = hostingView
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }

    func prepareAtStartup() async {
        let started = LensTimebase.now()
        let entries = (try? await lensWindows(popups: [])) ?? []
        // A Lens that opened during the read owns the panel; drawing here would replace its view.
        let idle = if case .closed = lifecycle.state { true } else { false }
        let workspaces = miniatureWorkspaceSnapshot(entries)
        let drew = startupPreparation.run(idle: idle) { presentation in
            var settings = LensConfig()
            settings.presentation = presentation
            let items = presentationItems(entries, settings: settings, workspaces: workspaces)
            let model = LensStartupPreparation.model(presentation: presentation, size: focus.workspace.workspaceMonitor.visibleRect.size,
                                                     existingItems: items, workspaces: workspaces)
            prepare(model, startup: true)
        }
        guard drew else { return }
        clearPresentation()
        lensLog.notice("Lens startup preparation took \(Int((LensTimebase.now() - started) * 1000)) ms")
    }

    func openLens(name: String, settings: LensConfig, entries: [LensWindow], search: String?, banner: String?, context: JSONValue, ticket: Int, invocation: StripGesture? = nil, eventFilter: String? = nil) async {
        // The grid's 'real size needs a floating window's frame as it is now, as miniatures does.
        if settings.presentation == "miniatures" || settings.presentation == "grid" {
            await withTaskGroup(of: Void.self) { group in
                for entry in entries where entry.window.isFloating && (entry.window as? MacWindow)?.isHiddenInCorner != true {
                    group.addTask { @MainActor @Sendable in
                        if let rect = try? await entry.window.getAxRect() { entry.window.miniatureFrame = rect.cgRect }
                    }
                }
            }
        }
        let workspaces = miniatureWorkspaceSnapshot(entries)
        let items = presentationItems(entries, settings: settings, workspaces: workspaces)
        let model = LensSession(name: name, settings: settings, items: items, search: settings.presentation == "strip" ? "" : lifecycle.search(for: name, override: search), eventFilter: eventFilter)
        model.miniatureWorkspaces = workspaces
        if settings.miniatures.currentWorkspace == "hide" {
            model.send(.excludedChanged(Set(items.filter { $0.miniature?.workspace == focus.workspace.name }.map(\.id))))
        }
        model.banner = banner
        model.onAction = { [weak self] key in self?.performAction(key) }
        let records = entries.map { $0.record.json }
        let ids = entries.map { $0.window.windowId }
        lifecycle.complete(model, ticket: ticket, context: context, windows: records, ids: ids, invocation: invocation)
    }

    private func presentationItems(_ entries: [LensWindow], settings: LensConfig, workspaces: [MiniatureWorkspace]) -> [SwitcherPaletteItem] {
        let focused = focus
        let focusedId = focused.windowOrNil?.windowId
        let monitorHeight = focused.workspace.workspaceMonitor.visibleRect.height
        let workspaceLabels = tileWorkspaceLabels(entries.map { $0.record.workspace }, workspaces: workspaces)
        let onscreen = lensOnscreenWindows(drawsPictures: LensSession.drawsPictures(settings: settings)) { Set((CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }) }
        return entries.map { entry in
            let miniature = miniatureEntry(entry, onscreen: onscreen)
            let icon = (entry.window as? MacWindow)?.macApp.nsApp.icon
            return SwitcherPaletteItem(
                id: entry.window.windowId, title: entry.record.title, appName: entry.record.app.name,
                icon: icon,
                workspaceName: entry.searchFields.workspace, appIdentity: String(entry.record.app.pid),
                projectName: entry.searchFields.project, lastFocusedSeq: entry.record.lastFocusedSeq, isFocused: entry.window.windowId == focusedId,
                miniature: miniature, tile: tileEntry(entry, miniature: miniature, icon: icon, workspaceLabels: workspaceLabels, monitorHeight: monitorHeight, focusedWorkspaceName: focused.workspace.name)
            )
        }
    }

    private func show(_ model: LensSession) {
        if preparedSession !== model { prepare(model) }
        preparedSession = nil
        lifecycle.trace?.startInterval("panel ordered front")
        orderFrontRegardless()
        lifecycle.trace?.advance("panel ordered front")
        lifecycle.trace?.startInterval("first frame presented")
        hostingView.observeFirstFrame()
        if model.settings.presentation == "grid" {
            gridLandingPanel.order(.below, relativeTo: windowNumber)
            // A view's layer is anchored at its corner, so the scale is about the centre by hand.
            let centre = CGPoint(x: hostingView.bounds.midX, y: hostingView.bounds.midY)
            let shrunk = CGAffineTransform(translationX: centre.x, y: centre.y).scaledBy(x: 0.97, y: 0.97).translatedBy(x: -centre.x, y: -centre.y)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.0; fade.toValue = 1.0
            let scale = CABasicAnimation(keyPath: "transform")
            scale.fromValue = CATransform3DMakeAffineTransform(shrunk); scale.toValue = CATransform3DIdentity
            for (key, animation) in [("opacity", fade), ("transform", scale)] {
                animation.duration = 0.1
                hostingView.layer?.add(animation, forKey: key)
            }
        }
    }

    private func finishShow(_ model: LensSession, instruction: LensLifecycle.ShowInstruction) {
        if instruction.activate { NSApp.activate(ignoringOtherApps: true) }
        makeKey()
        // A list that is shown again with Search already focused keeps its caret and selection.
        if model.settings.presentation != "strip", instruction.focusSearch || !(firstResponder is NSTextView) {
            let initialQuery = model.query
            let selectAll = instruction.focusSearch
            focusSearch(model, selectAll: selectAll)
            DispatchQueue.main.async { [weak self, weak model] in
                guard let self, let model, self.session === model else { return }
                self.focusSearch(model, selectAll: selectAll && model.query == initialQuery)
            }
        }
    }

    private func focusSearch(_ model: LensSession, selectAll: Bool) {
        guard let field = lensSearchField(in: hostingView) else { return }
        _ = makeFirstResponder(field)
        synchronizeSearchEditor(model)
        if selectAll { (firstResponder as? NSTextView)?.selectAll(nil) }
    }

    private func synchronizeSearchEditor(_ model: LensSession) {
        guard let editor = firstResponder as? NSTextView else { return }
        if editor.string != model.query { editor.string = model.query }
        editor.setSelectedRange(NSRange(location: (model.query as NSString).length, length: 0))
    }

    func cycleStrip(name: String, invocation: StripGesture) -> Bool {
        guard let code = invocation.keyCode else { return false }
        return lifecycle.cycleStrip(name: name, keyCode: code, flags: invocation.invoking)
    }

    func stripWindowClosed(_ id: UInt32) {
        guard let session, session.settings.presentation == "strip" else { return }
        session.removeStripItems([id])
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let result = super.makeFirstResponder(responder)
        if result, let model = session {
            lifecycle.trace?.key(code: 0, characters: "", flags: [], timestamp: LensTimebase.now(),
                presentation: model.settings.presentation, hold: model.hold != nil,
                path: "focus", destination: firstResponder is NSTextView ? "Search first responder" : "other responder",
                search: model.query, selectedId: model.selectedId, fieldEditor: firstResponder is NSTextView)
        }
        return result
    }

    func stripFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard let model = session else { lifecycle.openingFlagsChanged(flags); return }
        let wasHeld = model.hold != nil
        lifecycle.stripFlagsChanged(flags, from: model)
        // An untouched Search keeps the selection it opened with.
        if wasHeld, model.hold == nil, model.searchEdited { synchronizeSearchEditor(model) }
    }

    private func prepare(_ model: LensSession, startup: Bool = false) {
        scrollPaging = MiniatureScrollPaging()
        gridLandingPanel.orderOut(nil)
        let monitor = focus.workspace.workspaceMonitor
        let visible = monitor.visibleRect
        let sidebarInset = model.settings.presentation == "miniatures" ? monitor.workspaceSidebarInset : 0
        let rect = Rect(topLeftX: visible.minX + sidebarInset, topLeftY: visible.minY, width: visible.width - sidebarInset, height: visible.height)
        model.miniatureSize = visible.size
        isOpaque = false
        let frame: NSRect
        let root: AnyView
        if model.settings.presentation == "miniatures" || model.settings.presentation == "strip" {
            model.miniatureSize = rect.size
            model.revealMiniatureSelection()
            frame = NSRect(x: rect.minX, y: appKitScreenMaxY() - rect.maxY, width: rect.width, height: rect.height)
            root = model.settings.presentation == "strip" ? AnyView(StripView(model: model)) : AnyView(MiniaturesView(model: model))
        } else if model.settings.presentation == "grid" {
            gridMonitorRect = rect.cgRect
            let layout = model.gridLayout
            let size = layout.panelSize
            lensLog.debug("Grid layout row height \(layout.rowHeight, privacy: .public), \(layout.tiles.count) Tiles, panel \(size.width, privacy: .public) × \(size.height, privacy: .public), widest picture \(layout.tiles.map { $0.pictureSize.width }.max() ?? 0, privacy: .public)")
            frame = NSRect(x: rect.minX + (rect.width - size.width) / 2,
                           y: appKitScreenMaxY() - rect.minY - (rect.height + size.height) / 2,
                           width: size.width, height: size.height)
            root = AnyView(GridView(model: model))
            gridLandingPanel.setFrame(NSRect(x: rect.minX, y: appKitScreenMaxY() - rect.maxY, width: rect.width, height: rect.height), display: false)
            gridLandingPanel.contentView = NSHostingView(rootView: GridLandingView(model: model))
        } else {
            let layout = model.listLayout
            frame = NSRect(x: rect.minX + (rect.width - layout.width) / 2,
                           y: appKitScreenMaxY() - rect.minY - layout.topOffset - layout.panelHeight,
                           width: layout.width, height: layout.panelHeight)
            root = AnyView(SwitcherPaletteView(model: model))
        }
        // The real root goes in before the frame is set, so the first layout is of the Presentation.
        lifecycle.trace?.startInterval("view built")
        hostingView.rootView = root
        setFrame(frame, display: false)
        hostingView.arm()
        lifecycle.trace?.advance("view built")
        lifecycle.trace?.startInterval("first layout")
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
        lifecycle.trace?.startInterval("first-frame thumbnails ready")
        if startup, let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) {
            // Rasterizing the whole canvas is what pays SwiftUI's first drawing; an opening only displays.
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        } else {
            hostingView.displayIfNeeded()
        }
        lifecycle.trace?.advance("first-frame thumbnails ready")
        preparedSession = model
    }

    func beginLens(_ name: String, toggle: Bool, strip: StripGesture? = nil, trace: LensOpeningTrace? = nil, keys: [LensKeyBinding] = [], invocation: StripGesture? = nil) -> Int? {
        let ticket = lifecycle.begin(name, toggle: toggle, strip: strip, trace: trace, keys: keys, invocation: invocation)
        return ticket
    }

    func cancelLensOpening(ticket: Int) { lifecycle.cancelOpening(ticket: ticket) }

    func dismiss() {
        lifecycle.dismiss()
    }

    private func updateGridFrame(_ model: LensSession) {
        // Only a drawn grid follows its results; an opening one is framed by `prepare`.
        guard model.settings.presentation == "grid", isVisible else { return }
        let size = model.gridLayout.panelSize
        let rect = gridMonitorRect
        let frame = NSRect(x: rect.minX + (rect.width - size.width) / 2,
                           y: appKitScreenMaxY() - rect.minY - (rect.height + size.height) / 2,
                           width: size.width, height: size.height)
        if frame != self.frame { setFrame(frame, display: true) }
    }

    private func clearPresentation() {
        gridLandingPanel.orderOut(nil)
        gridLandingPanel.contentView = nil
        hostingView.layer?.removeAllAnimations()
        preparedSession = nil
        hostingView.disarm()
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }

    func changePresentationToList() {
        guard let session else { return }
        lifecycle.changePresentationToList(session)
    }

    private func performAction(_ key: String) {
        guard let model = session else { return }
        let commands = model.commands(for: key)
        guard !commands.isEmpty else {
            // A release always closes the strip, even when its binding runs nothing.
            if model.settings.presentation == "strip", key.hasSuffix("enter") { dismiss() }
            return
        }
        let keepStrip = model.settings.presentation == "strip" && !commands.contains { $0 == "focus" || $0.hasPrefix("focus ") || $0 == "summon" || $0.hasPrefix("summon ") } && !key.hasSuffix("enter")
        // An action can run from a timer or a command task, where the current event is unrelated.
        let now = LensTimebase.now()
        let origin = LensTraceOrigin(start: now, received: now, source: "internal")
        if !keepStrip { dismiss() }
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.menuBarButton, token) {
                let io = CmdIo(stdin: .emptyStdin)
                if try await !($lensTraceOrigin.withValue(origin) { try await runLensAction(commands, session: model, io: io) }) {
                    lensLog.error("Lens \(model.name, privacy: .public): \(key, privacy: .public) failed: \(io.stderr.joined(separator: "; "), privacy: .public)")
                }
            }
        }
    }

    private func routeKey(_ event: NSEvent, path: String, carbon: Bool = false) -> Bool {
        guard let model = session else { return false }
        let receivedAt = LensTimebase.now()
        let trace = lifecycle.trace
        let presentation = model.settings.presentation
        let held = model.hold != nil
        let editor = firstResponder is NSTextView
        let meaning = model.meaning(for: event)
        let handled: Bool
        let destination: String
        switch meaning {
            // A global binding pressed over a list or miniatures with no Hold is not the Lens's key.
            case _ where carbon && !held && presentation != "strip": handled = false; destination = "global binding"
            case .dismiss: dismiss(); handled = true; destination = "dismissed"
            case .global: dismiss(); handled = !carbon; destination = "dismissed; global binding"
            default:
                handled = model.perform(meaning, retainTyping: !editor && model.settings.presentation != "strip")
                switch meaning {
                    case .text, .backspace: destination = handled ? "Search" : editor ? "passed to field editor" : "dropped"
                    case .command(let key): destination = "Lens keys command " + key
                    case .step: destination = "step"
                    case .arrow, .mark: destination = "selection"
                    case .dropped: destination = "dropped"
                    default: destination = editor ? "passed to field editor" : "dropped"
                }
                if handled, session === model {
                    switch meaning {
                        case .text, .backspace: synchronizeSearchEditor(model)
                        default: break
                    }
                }
                if carbon, !handled, presentation == "strip" { dismiss() }
        }
        trace?.key(code: event.keyCode, characters: event.charactersIgnoringModifiers ?? "", flags: event.modifierFlags,
                   timestamp: event.timestamp, presentation: presentation, hold: held, path: path,
                   destination: destination, search: model.query, selectedId: model.selectedId, fieldEditor: editor, receivedAt: receivedAt)
        return handled
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if routeKey(event, path: "performKeyEquivalent") { return true }
        return super.performKeyEquivalent(with: event)
    }

    func handleStripHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String, timestamp: Double? = nil) -> Bool {
        if let input = lifecycle.openingStripKey(keyCode: keyCode, flags: modifiers, characters: characters, timestamp: timestamp) {
            if input == .consumed { return true }
            dismiss()
            return false
        }
        // A binding's key is named, not typed: only a one-character name is text.
        let characters = characters.count == 1 ? characters : keyCode == 49 ? " " : ""
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                          timestamp: timestamp ?? LensTimebase.now(), windowNumber: windowNumber,
                                          context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                          isARepeat: false, keyCode: keyCode) else { return false }
        return routeKey(event, path: "Carbon", carbon: true)
    }

    override func sendEvent(_ event: NSEvent) {
        guard let model = session else { super.sendEvent(event); return }
        if event.type == .flagsChanged { model.updateSummonModifiers(event.modifierFlags) }
        if event.type == .keyDown, routeKey(event, path: "sendEvent") { return }
        if event.type == .scrollWheel, model.settings.presentation == "miniatures" {
            if let turn = scrollPaging.turn(delta: event.scrollingDeltaY, sideways: event.scrollingDeltaX, phase: event.phase, momentum: event.momentumPhase, time: event.timestamp) { model.turnMiniaturePage(turn) }
            return
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private func appKitScreenMaxY() -> CGFloat {
    NSScreen.screens.first?.frame.maxY ?? 0
}

// MARK: - Search

func filterSwitcherPaletteItems(_ items: [SwitcherPaletteItem], query: String) -> [SwitcherPaletteItem] {
    if query.allSatisfy(\.isWhitespace) { return items }
    let ranked: [(Int, SwitcherPaletteItem, Int)] = items.enumerated().compactMap { index, item in
        LensSearchFields(title: item.title, app: item.appName, workspace: item.workspaceName, project: item.projectName)
            .match(query).map { (index, item, $0.score) }
    }
    return ranked.sorted { $0.2 == $1.2 ? $0.0 < $1.0 : $0.2 > $1.2 }.map { $0.1 }
}

// MARK: - View

struct SwitcherPaletteView: View {
    @ObservedObject var model: LensSession
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = model.results
        let layout = model.listLayout(count: results.count)
        let scale = model.tileMetrics.scale
        VStack(spacing: 0) {
            HStack(spacing: 8 * scale) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                TextField("Search windows…", text: Binding(get: { model.query }, set: { model.send(.searchChanged($0)) }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14 * scale)
            .frame(height: 44 * scale)
            .padding(.top, 26 * scale)

            Rectangle()
                .fill(Color.white.opacity(GlassToken.separatorOpacity))
                .frame(height: StrokeToken.hairline)

            if let error = model.searchError {
                Text(error).font(.system(size: 11)).foregroundStyle(.orange).padding(.horizontal, 14).padding(.vertical, 4)
            }
            if let banner = model.banner {
                Text(banner.components(separatedBy: .newlines).first ?? banner).font(.system(size: 11)).foregroundStyle(.orange).padding(8)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: layout.gap) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            TileView(entry: item.tile, kind: model.tileKind, presentation: "list", metrics: model.tileMetrics,
                                     size: CGSize(width: layout.width - 40 * scale, height: layout.rowHeight),
                                     settings: model.settings, selected: index == model.selection, marked: model.marks.contains(item.id),
                                     hint: index == model.selection && model.summonHeld && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil)
                            .id(item.id)
                            .onContinuousHover { phase in
                                if case .active = phase { model.hover(item.id, at: NSEvent.mouseLocation) }
                            }
                            .onTapGesture {
                                model.hover(item.id)
                                if let event = NSApp.currentEvent, let key = model.key(for: event, click: true) { model.onAction?(key) }
                            }
                        }
                    }
                    .padding(.horizontal, 20 * scale)
                }
                .onChange(of: model.selection) { newSelection in
                    if results.indices.contains(newSelection) {
                        proxy.scrollTo(results[newSelection].id, anchor: nil)
                    }
                }
            }
            .frame(height: layout.rowsHeight)
            .padding(.bottom, 20 * scale - StrokeToken.hairline)
        }
        .frame(width: layout.width)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GlassSurface(
                shape: RoundedRectangle(cornerRadius: layout.radius, style: .continuous),
                style: config.workspaceSidebar.chromeStyle,
                solidColor: config.workspaceSidebar.resolvedSolidChromeColor,
            )
        }
        .overlay {
            if model.searchError != nil { RoundedRectangle(cornerRadius: layout.radius).stroke(.orange, lineWidth: 1) }
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.radius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { searchFocused = true }
    }
}

@MainActor
func miniatureWorkspaceSnapshot(_ entries: [LensWindow]) -> [MiniatureWorkspace] {
    let ordered = userFacingWorkspaces(orderedWorkspacesForPresentation(), focusedWorkspace: focus.workspace).map {
        MiniatureWorkspace(name: $0.name, title: workspaceDisplayName($0.name), source: $0.workspaceMonitor.visibleRect.cgRect, current: $0 == focus.workspace)
    }
    var seen = Set(ordered.map(\.name))
    let retained = entries.compactMap { entry -> MiniatureWorkspace? in
        guard !entry.record.workspace.isEmpty, seen.insert(entry.record.workspace).inserted else { return nil }
        let workspace = Workspace.existing(byName: entry.record.workspace)
        return MiniatureWorkspace(name: entry.record.workspace, title: workspaceDisplayName(entry.record.workspace),
                                  source: (workspace?.workspaceMonitor ?? focus.workspace.workspaceMonitor).visibleRect.cgRect, current: false)
    }
    return appendingRetainedMiniatureWorkspaces(ordered, retained: retained)
}

@MainActor
private func miniatureEntry(_ entry: LensWindow, onscreen: Set<UInt32>) -> MiniatureWindow {
    let window = entry.window
    let tray = window.parent is MacosMinimizedWindowsContainer || window.parent is MacosHiddenAppsWindowsContainer
    let source = window.nodeWorkspace?.workspaceMonitor.visibleRect.cgRect ?? focus.workspace.workspaceMonitor.visibleRect.cgRect
    let frame = window.isFloating ? (window.miniatureFrame ?? window.lastKnownActualRect?.cgRect ?? source) : (window.lastAppliedLayoutPhysicalRect?.cgRect ?? window.miniatureFrame ?? window.lastKnownActualRect?.cgRect ?? source)
    let nativeFullscreen = window.parent is MacosFullscreenWindowsContainer
    let frozen = miniatureIsFrozen(tray: tray, fullscreen: nativeFullscreen && !onscreen.contains(window.windowId),
                                   workspaceVisible: nativeFullscreen ? onscreen.contains(window.windowId) : window.nodeWorkspace?.isVisible == true, parked: (window as? MacWindow)?.isHiddenInCorner == true)
    return MiniatureWindow(workspace: entry.record.workspace, frame: frame, tray: tray, frozen: frozen,
                           accessory: entry.record.app.accessory, floating: window.isFloating, window: window)
}

@MainActor
func lensSearchField(in view: NSView) -> NSTextField? {
    if let field = view as? NSTextField, field.isEditable { return field }
    return view.subviews.lazy.compactMap { lensSearchField(in: $0) }.first
}

@MainActor
func tileWorkspaceLabels(_ names: [String], workspaces: [MiniatureWorkspace]) -> [String: String] {
    let titles = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.name, $0.title) })
    return Dictionary(uniqueKeysWithValues: Set(names).filter { !$0.isEmpty }.map { name in
        if let label = config.workspaceSidebar.workspaceLabels[name]?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return (name, tileWorkspaceLabel(label))
        }
        let workspace = Workspace.existing(byName: name)
        let title = titles[name] ?? name
        if workspace?.usesAutomaticDisplayName == true, title.hasPrefix("Workspace ") {
            return (name, String(title.dropFirst("Workspace ".count)))
        }
        return (name, parsePositiveWorkspaceDisplayIndex(name).map(String.init) ?? tileWorkspaceLabel(title))
    })
}

func tileWorkspaceLabel(_ title: String) -> String {
    title.count > 12 ? String(title.prefix(12)) + "…" : title
}

@MainActor
func tileEntry(_ entry: LensWindow, miniature: MiniatureWindow, icon: NSImage?, workspaceLabels: [String: String], monitorHeight: CGFloat, focusedWorkspaceName: String) -> TileEntry {
    let frame = thumbnailCaptureFrame(entry.window)
    return TileEntry(icon: icon, title: entry.record.title, appName: entry.record.app.name, picture: entry.window.thumbnail,
                     aspect: frame.width / max(1, frame.height), realSize: frame.size,
                     badges: TileBadges(workspaceLabel: workspaceLabels[entry.record.workspace], onFocusedWorkspace: entry.record.workspace == focusedWorkspaceName,
                                        floating: miniature.floating, minimized: entry.window.parent is MacosMinimizedWindowsContainer,
                                        hidden: entry.window.parent is MacosHiddenAppsWindowsContainer),
                     frozen: miniature.frozen, accessory: miniature.accessory,
                     monitorHeightFraction: frame.height / max(1, monitorHeight))
}

@MainActor
private final class LensHostingView: NSHostingView<AnyView> {
    var onFirstLayout: (() -> Void)?
    var onFirstFrame: ((_ refreshSeconds: Double) -> Void)?
    private var firstLayout = false
    private var displayTicks = 0
    private var firstFrameLink: CADisplayLink?

    func disarm() {
        firstLayout = false
        firstFrameLink?.invalidate()
        firstFrameLink = nil
        displayTicks = 0
    }
    func arm() { disarm(); firstLayout = true }
    override func layout() {
        super.layout()
        if firstLayout { firstLayout = false; onFirstLayout?() }
    }
    func observeFirstFrame() {
        let link = displayLink(target: self, selector: #selector(displayTick(_:)))
        firstFrameLink = link
        link.add(to: .main, forMode: .common)
    }
    @objc private func displayTick(_ link: CADisplayLink) {
        guard link === firstFrameLink else { return }
        displayTicks += 1
        guard displayTicks == 3 else { return }
        let refresh = link.duration
        link.invalidate()
        firstFrameLink = nil
        onFirstFrame?(refresh)
    }
}
