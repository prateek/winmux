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
    private var scrollPaging = MiniatureScrollPaging()
    var session: LensSession? { lifecycle.session }
    var isPaletteActive: Bool { session != nil }

    init(emit: @escaping (ServerEvent) -> Void) {
        lifecycle = LensLifecycle(dependencies: .live(), emit: emit, show: { _ in }, hide: {})
        super.init()
        lifecycle.prepare = { [weak self] model in self?.prepare(model) }
        lifecycle.show = { [weak self] model in self?.show(model) }
        lifecycle.finishShow = { [weak self] model, instruction in self?.finishShow(model, instruction: instruction) }
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
        if settings.presentation == "miniatures" {
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
    }

    private func finishShow(_ model: LensSession, instruction: LensLifecycle.ShowInstruction) {
        if instruction.activate { NSApp.activate(ignoringOtherApps: true) }
        makeKey()
        if instruction.focusSearch {
            DispatchQueue.main.async { [weak self, weak model] in
                guard let self, let model, self.session === model else { return }
                if let field = lensSearchField(in: self.hostingView) { self.makeFirstResponder(field) }
                (self.firstResponder as? NSTextView)?.selectAll(nil)
                self.lifecycle.trace?.key(code: 0, characters: "", flags: [], timestamp: LensTimebase.now(), presentation: model.settings.presentation, hold: false, path: "focus", destination: "Search first responder", search: model.query, selectedId: model.selectedId, fieldEditor: self.firstResponder is NSTextView)
            }
        }
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
                presentation: model.settings.presentation, hold: model.stripGesture != nil,
                path: "focus", destination: firstResponder is NSTextView ? "Search first responder" : "other responder",
                search: model.query, selectedId: model.selectedId, fieldEditor: firstResponder is NSTextView)
        }
        return result
    }

    func stripFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard let model = session else { lifecycle.openingFlagsChanged(flags); return }
        guard model.settings.presentation == "strip" else { return }
        lifecycle.stripFlagsChanged(flags, from: model)
    }

    private func prepare(_ model: LensSession, startup: Bool = false) {
        scrollPaging = MiniatureScrollPaging()
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

    func beginLens(_ name: String, toggle: Bool, strip: StripGesture? = nil, trace: LensOpeningTrace? = nil) -> Int? {
        let ticket = lifecycle.begin(name, toggle: toggle, strip: strip, trace: trace)
        return ticket
    }

    func cancelLensOpening(ticket: Int) { lifecycle.cancelOpening(ticket: ticket) }

    func dismiss() {
        lifecycle.dismiss()
    }

    private func clearPresentation() {
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

    private func recordKey(_ event: NSEvent, path: String, destination: String, model: LensSession? = nil, trace: LensOpeningTrace? = nil, presentation: String? = nil) {
        let model = model ?? session
        (trace ?? lifecycle.trace)?.key(code: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
            flags: event.modifierFlags, timestamp: event.timestamp,
            presentation: presentation ?? model?.settings.presentation ?? "opening",
            hold: model?.stripGesture.map { !$0.shouldCommit(flags: event.modifierFlags) } ?? false,
            path: path, destination: destination, search: model?.query ?? "", selectedId: model?.selectedId,
            fieldEditor: firstResponder is NSTextView)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if session?.settings.presentation == "strip", handleStripKey(event) { recordKey(event, path: "performKeyEquivalent", destination: "strip"); return true }
        if session?.performKeyAction(event) == true { recordKey(event, path: "performKeyEquivalent", destination: "Lens keys command"); return true }
        recordKey(event, path: "performKeyEquivalent", destination: "passed to field editor")
        return super.performKeyEquivalent(with: event)
    }

    private func handleStripKey(_ event: NSEvent) -> Bool {
        guard let model = session, model.settings.presentation == "strip" else { return false }
        switch model.stripInput(event) {
            case .ignored: return false
            case .consumed: return true
            case .cancel: dismiss(); return true
            case .list: return true
        }
    }

    func handleStripHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String) -> Bool {
        if let input = lifecycle.openingStripKey(keyCode: keyCode, flags: modifiers) {
            if input == .consumed {
                stripDebugLog("strip queued key uptime=\(ProcessInfo.processInfo.systemUptime) key=\(keyCode) modifiers=\(modifiers.rawValue)")
                return true
            }
            // Not the strip's: drop the opening strip so its release cannot undo the binding that runs now.
            dismiss()
            return false
        }
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber,
                                          context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                          isARepeat: false, keyCode: keyCode) else { return false }
        let model = session
        let trace = lifecycle.trace
        let presentation = model?.settings.presentation
        let handled = handleStripKey(event)
        recordKey(event, path: "Carbon", destination: handled ? "strip" : "global binding", model: model, trace: trace, presentation: presentation)
        if !handled, session?.settings.presentation == "strip" { dismiss() }
        return handled
    }

    // Intercept navigation keys before the field editor consumes them; other typing
    // flows to the Search field unless it matches a configured action.
    override func sendEvent(_ event: NSEvent) {
        guard let model = session else { super.sendEvent(event); return }
        if event.type == .flagsChanged {
            model.updateSummonModifiers(event.modifierFlags)
        }
        if event.type == .keyDown {
            let trace = lifecycle.trace
            let presentation = model.settings.presentation
            let search = model.query
            let selection = model.selectedId
            defer {
                let destination = session == nil ? "dismissed" : model.query != search ? "Search" : model.selectedId != selection ? "selection" : firstResponder is NSTextView ? "passed to field editor" : "dropped"
                recordKey(event, path: "sendEvent", destination: destination, model: model, trace: trace, presentation: presentation)
            }
            if model.settings.presentation == "strip", handleStripKey(event) { return }
            if model.settings.presentation == "miniatures", let direction = [UInt16(123): MiniatureLayout.Direction.left, 124: .right, 125: .down, 126: .up][event.keyCode] {
                model.moveMiniatureSelection(direction)
                return
            }
            switch event.keyCode {
                case 53: dismiss(); return // esc
                case 125: model.moveSelection(1); return // down arrow
                case 126: model.moveSelection(-1); return // up arrow
                case 48: model.toggleMark(); return // tab
                default: break
            }
            if model.performKeyAction(event) { return }
        }
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
                     aspect: frame.width / max(1, frame.height),
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
