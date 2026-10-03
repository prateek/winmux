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
}

// MARK: - Panel

@MainActor
final class SwitcherPalettePanel: NSPanelHud {
    static let shared = SwitcherPalettePanel()
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let lifecycle = LensLifecycle()
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

    func openLens(name: String, settings: LensConfig, entries: [LensWindow], search: String?, banner: String?, context: JSONValue, ticket: Int) async {
        let focusedId = focus.windowOrNil?.windowId
        let items = entries.map { entry in
            SwitcherPaletteItem(
                id: entry.window.windowId, title: entry.record.title, appName: entry.record.app.name,
                icon: (entry.window as? MacWindow)?.macApp.nsApp.icon,
                workspaceName: entry.searchFields.workspace, appIdentity: String(entry.record.app.pid),
                projectName: entry.searchFields.project, lastFocusedSeq: entry.record.lastFocusedSeq, isFocused: entry.window.windowId == focusedId
            )
        }
        let model = LensSession(name: name, settings: settings, items: items, search: lifecycle.search(for: name, override: search))
        model.banner = banner
        model.onAction = { [weak self] key in self?.performAction(key) }
        model.onSearchChanged = { [weak self, weak model] in
            guard let self, let model else { return }
            self.inlineSearch.update(model, context: context, windows: entries.map { $0.record.json }, ids: entries.map { $0.window.windowId })
        }
        guard lifecycle.complete(model, ticket: ticket) else { return }
        let monitorRect = focus.workspace.workspaceMonitor.visibleRect
        setFrame(NSRect(
            x: monitorRect.topLeftX + (monitorRect.width - switcherPaletteWidth) / 2,
            y: appKitScreenMaxY() - monitorRect.topLeftY - monitorRect.height * 0.25 - switcherPaletteMaxHeight,
            width: switcherPaletteWidth, height: switcherPaletteMaxHeight
        ), display: true, animate: false)
        hostingView.rootView = AnyView(SwitcherPaletteView(model: model))
        orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        makeKey()
        DispatchQueue.main.async { [weak self] in
            (self?.firstResponder as? NSTextView)?.selectAll(nil)
        }
        model.onSearchChanged?()
    }

    func beginLens(_ name: String, toggle: Bool) -> Int? {
        let ticket = lifecycle.begin(name, toggle: toggle)
        clearPresentation()
        return ticket
    }

    func dismiss() {
        lifecycle.dismiss()
        clearPresentation()
    }

    private func clearPresentation() {
        inlineSearch.cancel()
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }

    func changePresentationToList() {
        session?.changePresentation("list")
        orderFrontRegardless()
        makeKey()
    }

    private func performAction(_ key: String) {
        guard let model = session, !model.commands(for: key).isEmpty else { return }
        let commands = model.commands(for: key)
        dismiss()
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.menuBarButton, token) {
                _ = try await runLensAction(commands, session: model, io: CmdIo(stdin: .emptyStdin))
            }
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard let model = session else { super.sendEvent(event); return }
        if event.type == .flagsChanged {
            model.summonHeld = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option)
        }
        if event.type == .keyDown {
            switch event.keyCode {
                case 53: dismiss(); return
                case 125: model.moveSelection(1); return
                case 126: model.moveSelection(-1); return
                case 48: model.toggleMark(); return
                default: break
            }
            if let key = model.key(for: event) { performAction(key); return }
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
                            .onHover { hovering in if hovering { model.hover(item.id) } }
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
