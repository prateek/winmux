import AppKit
import Common
import SwiftUI

private let switcherPalettePanelId = "WinMux.switcherPalette"
private let switcherPaletteWidth: CGFloat = 560
private let switcherPaletteMaxHeight: CGFloat = 440

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
}

// MARK: - Panel

@MainActor
final class SwitcherPalettePanel: NSPanelHud {
    static let shared = SwitcherPalettePanel()
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let lifecycle = LensLifecycle()
    private var stripDisplay: Task<Void, Never>?
    private var thumbnailRefresh: Task<Void, Never>?
    private var thumbnailSession = 0
    private var scrollPaging = MiniatureScrollPaging()
    var session: LensSession? { lifecycle.session }
    private let inlineSearch = LensInlineSearch { body, context, windows in
        await NickelSupervisor.shared.evalFilter(body, context: context, windows: windows)
    }
    var isPaletteActive: Bool { session != nil }

    override private init() {
        super.init()
        identifier = NSUserInterfaceItemIdentifier(switcherPalettePanelId)
        hasShadow = true
        isFloatingPanel = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        backgroundColor = .clear
        applyWinMuxLayer(.overlay)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = hostingView
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }

    func openLens(name: String, settings: LensConfig, entries: [LensWindow], search: String?, banner: String?, context: JSONValue, ticket: Int, invocation: StripGesture? = nil) async {
        if settings.presentation == "miniatures" {
            await withTaskGroup(of: Void.self) { group in
                for entry in entries where entry.window.isFloating && (entry.window as? MacWindow)?.isHiddenInCorner != true {
                    group.addTask { @MainActor @Sendable in
                        if let rect = try? await entry.window.getAxRect() { entry.window.miniatureFrame = rect.cgRect }
                    }
                }
            }
        }
        let focusedId = focus.windowOrNil?.windowId
        let onscreen: Set<UInt32> = settings.presentation != "miniatures" ? [] : Set((CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
        let items = entries.map { entry in
            SwitcherPaletteItem(
                id: entry.window.windowId, title: entry.record.title, appName: entry.record.app.name,
                icon: (entry.window as? MacWindow)?.macApp.nsApp.icon,
                workspaceName: entry.searchFields.workspace, appIdentity: String(entry.record.app.pid),
                projectName: entry.searchFields.project, lastFocusedSeq: entry.record.lastFocusedSeq, isFocused: entry.window.windowId == focusedId,
                miniature: miniatureEntry(entry, onscreen: onscreen)
            )
        }
        let model = LensSession(name: name, settings: settings, items: items, search: settings.presentation == "strip" ? "" : lifecycle.search(for: name, override: search))
        model.miniatureWorkspaces = miniatureWorkspaceSnapshot(entries)
        if settings.miniatures.currentWorkspace == "hide" {
            model.miniatureExcludedIds = Set(items.filter { $0.miniature?.workspace == focus.workspace.name }.map(\.id))
        }
        model.banner = banner
        model.onAction = { [weak self] key in self?.performAction(key) }
        let records = entries.map { $0.record.json }
        let ids = entries.map { $0.window.windowId }
        model.onSearchChanged = { [weak self, weak model] in
            guard let self, let model else { return }
            self.inlineSearch.update(model, context: context, windows: records, ids: ids)
        }
        guard lifecycle.complete(model, ticket: ticket) else { return }
        if settings.presentation == "strip", let invocation {
            model.beginStrip(invocation)
            let flags = NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue))
            if let key = model.stripReleaseKey(flags: flags) { performAction(key); return }
            model.updateSummonModifiers(flags)
            stripDisplay = Task { @MainActor [weak self, weak model] in
                let remaining = max(0, 0.1 - (ProcessInfo.processInfo.systemUptime - invocation.openedAt))
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled, let self, let model, self.session === model, model.settings.presentation == "strip" else { return }
                let flags = NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue))
                if let key = model.stripReleaseKey(flags: flags) { self.performAction(key); return }
                self.present(model)
                self.orderFrontRegardless()
                self.makeKey()
                self.startThumbnailRefresh(model)
            }
            return
        }
        present(model)
        orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        makeKey()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let field = lensSearchField(in: self.hostingView) { self.makeFirstResponder(field) }
            (self.firstResponder as? NSTextView)?.selectAll(nil)
        }
        model.onSearchChanged?()
        if settings.presentation == "miniatures" { startThumbnailRefresh(model) }
    }

    private func startThumbnailRefresh(_ model: LensSession) {
        thumbnailSession += 1
        let token = thumbnailSession
        thumbnailRefresh = Task { @MainActor [weak model] in
            await Task.yield()
            while !Task.isCancelled, let model {
                if model.settings.presentation == "strip" { model.refreshStripThumbnails(lens: token) }
                else { model.refreshVisibleThumbnails(lens: token) }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func cycleStrip(name: String, invocation: StripGesture) -> Bool {
        guard let session, session.name == name, let code = invocation.keyCode else { return false }
        return session.cycleStrip(keyCode: code, flags: invocation.invoking)
    }

    func stripWindowClosed(_ id: UInt32) {
        guard let session, session.settings.presentation == "strip" else { return }
        session.removeStripItems([id])
    }

    func stripFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard let model = session, model.settings.presentation == "strip" else { return }
        model.updateSummonModifiers(flags)
        if let key = model.stripReleaseKey(flags: flags) { performAction(key) }
    }

    private func present(_ model: LensSession) {
        scrollPaging = MiniatureScrollPaging()
        let monitor = focus.workspace.workspaceMonitor
        let visible = monitor.visibleRect
        let sidebarInset = model.settings.presentation == "miniatures" ? monitor.workspaceSidebarInset : 0
        let rect = Rect(topLeftX: visible.minX + sidebarInset, topLeftY: visible.minY, width: visible.width - sidebarInset, height: visible.height)
        isOpaque = false
        if model.settings.presentation == "miniatures" || model.settings.presentation == "strip" {
            model.miniatureSize = rect.size
            model.revealMiniatureSelection()
            setFrame(NSRect(x: rect.minX, y: appKitScreenMaxY() - rect.maxY, width: rect.width, height: rect.height), display: true)
            hostingView.rootView = model.settings.presentation == "strip" ? AnyView(StripView(model: model)) : AnyView(MiniaturesView(model: model))
        } else {
            // Center on the focused monitor, with the top edge at one quarter of its height;
            // convert the top-left coordinates to AppKit's bottom-left origin.
            setFrame(NSRect(x: rect.minX + (rect.width - switcherPaletteWidth) / 2,
                            y: appKitScreenMaxY() - rect.minY - rect.height * 0.25 - switcherPaletteMaxHeight,
                            width: switcherPaletteWidth, height: switcherPaletteMaxHeight), display: true)
            hostingView.rootView = AnyView(SwitcherPaletteView(model: model))
        }
    }

    func beginLens(_ name: String, toggle: Bool) -> Int? {
        let ticket = lifecycle.begin(name, toggle: toggle)
        clearPresentation()
        return ticket
    }

    func cancelLensOpening(ticket: Int) { lifecycle.cancelOpening(ticket: ticket) }

    func dismiss() {
        lifecycle.dismiss()
        clearPresentation()
    }

    private func clearPresentation() {
        stripDisplay?.cancel()
        stripDisplay = nil
        thumbnailRefresh?.cancel()
        thumbnailRefresh = nil
        ThumbnailCache.shared.closeLens(thumbnailSession)
        inlineSearch.cancel()
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }

    func changePresentationToList() {
        guard let session else { return }
        stripDisplay?.cancel()
        thumbnailRefresh?.cancel()
        ThumbnailCache.shared.closeLens(thumbnailSession)
        session.changePresentation("list")
        present(session)
        orderFrontRegardless()
        makeKey()
    }

    private func performAction(_ key: String) {
        guard let model = session, !model.commands(for: key).isEmpty else { return }
        let commands = model.commands(for: key)
        let keepStrip = model.settings.presentation == "strip" && !commands.contains { $0 == "focus" || $0.hasPrefix("focus ") || $0 == "summon" || $0.hasPrefix("summon ") } && !key.hasSuffix("enter")
        if !keepStrip { dismiss() }
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.menuBarButton, token) {
                let io = CmdIo(stdin: .emptyStdin)
                if try await !runLensAction(commands, session: model, io: io) {
                    lensLog.error("Lens \(model.name, privacy: .public): \(key, privacy: .public) failed: \(io.stderr.joined(separator: "; "), privacy: .public)")
                }
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if session?.settings.presentation == "strip", handleStripKey(event) { return true }
        if session?.performKeyAction(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func handleStripKey(_ event: NSEvent) -> Bool {
        guard let model = session, model.settings.presentation == "strip" else { return false }
        if model.cycleStrip(keyCode: event.keyCode, flags: event.modifierFlags) { return true }
        switch event.keyCode {
            case 53: dismiss(); return true
            case 123: model.cycleStripSelection(-1); return true
            case 124: model.cycleStripSelection(1); return true
            case 48, 50: return true
            default: break
        }
        if model.handleStripLetter(event) {
            if model.settings.presentation == "list" { changePresentationToList() }
            return true
        }
        return false
    }

    // Intercept navigation keys before the field editor consumes them; other typing
    // flows to the Search field unless it matches a configured action.
    override func sendEvent(_ event: NSEvent) {
        guard let model = session else { super.sendEvent(event); return }
        if event.type == .flagsChanged {
            model.updateSummonModifiers(event.modifierFlags)
        }
        if event.type == .keyDown {
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
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                TextField("Search windows…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)

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
                    LazyVStack(spacing: 1) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            SwitcherPaletteRow(
                                item: item,
                                isSelected: index == model.selection,
                                isMarked: model.marks.contains(item.id),
                                hint: index == model.selection && model.summonHeld && model.settings.summonHints.contains("label") ? "Summon to \(focus.workspace.name)" : nil,
                                appCount: model.settings.entries == "app" ? model.items.filter { $0.appIdentity == item.appIdentity }.count : nil,
                            )
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
                    .padding(6)
                }
                .onChange(of: model.selection) { newSelection in
                    if results.indices.contains(newSelection) {
                        proxy.scrollTo(results[newSelection].id, anchor: nil)
                    }
                }
            }
            .frame(maxHeight: switcherPaletteMaxHeight - 44)
        }
        .frame(width: switcherPaletteWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GlassSurface(
                shape: RoundedRectangle(cornerRadius: RadiusToken.panel, style: .continuous),
                style: config.workspaceSidebar.chromeStyle,
                solidColor: config.workspaceSidebar.resolvedSolidChromeColor,
            )
        }
        .overlay {
            if model.searchError != nil { RoundedRectangle(cornerRadius: RadiusToken.panel).stroke(.orange, lineWidth: 1) }
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.panel, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { searchFocused = true }
    }
}

private struct SwitcherPaletteRow: View {
    let item: SwitcherPaletteItem
    let isSelected: Bool
    let isMarked: Bool
    let hint: String?
    let appCount: Int?

    var body: some View {
        HStack(spacing: 8) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            }
            Text(appCount == nil ? item.title : item.appName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(Color.white.opacity(isSelected ? GlassToken.textPrimary : GlassToken.textSecondary))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if let hint { Text(hint).font(.system(size: 11)) }
            if isMarked { Image(systemName: "checkmark.circle.fill") }
            if let appCount { Text("\(appCount) windows").font(.system(size: 11)) }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: RadiusToken.row, style: .continuous)
                .fill(Color.white.opacity(isSelected ? GlassToken.fillActive : 0))
        }
        .contentShape(Rectangle())
    }
}


@MainActor
func miniatureWorkspaceSnapshot(_ entries: [LensWindow]) -> [MiniatureWorkspace] {
    let ordered = userFacingWorkspaces(orderedWorkspacesForPresentation(), focusedWorkspace: focus.workspace).map {
        MiniatureWorkspace(name: $0.name, title: workspaceDisplayName($0.name), source: $0.workspaceMonitor.visibleRect.cgRect, current: $0 == focus.workspace)
    }
    let retained = entries.compactMap { entry -> MiniatureWorkspace? in
        guard !entry.record.workspace.isEmpty else { return nil }
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
