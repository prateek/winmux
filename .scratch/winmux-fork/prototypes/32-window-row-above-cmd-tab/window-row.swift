import AppKit
import ApplicationServices
import Carbon

func now() -> Double { ProcessInfo.processInfo.systemUptime }
func log(_ kind: String, _ fields: [String: Any] = [:], at stamp: Double? = nil) {
    var record = fields
    record["event"] = kind
    record["time"] = stamp ?? now()
    if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
       let line = String(data: data, encoding: .utf8) { print(line); fflush(stdout) }
}
func ax(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    AXUIElementSetMessagingTimeout(element, 1.0)
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}
func frame(_ element: AXUIElement) -> CGRect? {
    guard let value = ax(element, "AXFrame"), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var rect = CGRect.zero
    return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
}
func front() -> [String: Any] {
    guard let app = NSWorkspace.shared.frontmostApplication else { return [:] }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var result: [String: Any] = ["app": app.localizedName ?? "", "pid": app.processIdentifier]
    if let window = ax(element, "AXFocusedWindow") {
        let w = window as! AXUIElement
        result["title"] = ax(w, "AXTitle") as? String ?? ""
        if let rect = frame(w) { result["frame"] = NSStringFromRect(rect) }
    }
    return result
}
struct WindowEntry {
    let id: String
    let app: String
    let pid: String
    let bundle: String
    let title: String
    let workspace: String
}
func cli(_ arguments: [String], snapshotSession: Int? = nil) -> (String, Int32) {
    let process = Process()
    process.executableURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("winmux/.build/debug/winmux")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.standardError
    do {
        if let snapshotSession { log("snapshot-start", ["session": snapshotSession]) }
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
    } catch { return (String(describing: error), -1) }
}
final class RowPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class Tiles: NSView {
    var windows: [WindowEntry] = []
    var app = ""
    var selection: Int?
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.09, alpha: 0.97).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
        let heading = "\(app)  ·  \(windows.count) windows   |   ⌘A: choose   ← → / Tab: step   release ⌘: focus"
        (heading as NSString).draw(at: NSPoint(x: 18, y: bounds.height - 30), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white])
        for (index, window) in windows.enumerated() {
            let rect = NSRect(x: 12 + CGFloat(index) * 280, y: 12, width: 268, height: 74)
            (selection == index ? NSColor.systemBlue : NSColor(calibratedWhite: 0.22, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingMiddle
            (window.title as NSString).draw(in: rect.insetBy(dx: 12, dy: 13), withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
            ("Workspace \(window.workspace)   ·   window \(window.id)" as NSString).draw(at: NSPoint(x: rect.minX + 12, y: rect.minY + 9), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white.withAlphaComponent(0.8)])
        }
    }
    override func mouseDown(with event: NSEvent) { log("tile-click-unsupported", ["front": front()]) }
}
final class Prototype {
    let panel: RowPanel
    let tiles = Tiles()
    var dock: NSRunningApplication?
    var dockAX: AXUIElement?
    var observer: AXObserver?
    var appsObservation: NSKeyValueObservation?
    var launchObservation: NSKeyValueObservation?
    var timer: Timer?
    var tap: CFMachPort?
    var switcher: AXUIElement?
    var session = 0
    var active = false
    var highlighted = ""
    var highlightedElement: AXUIElement?
    var snapshot: [WindowEntry] = []
    var selection: Int?
    var cancelled = false
    var pendingKey: (Double, String)?
    var registeredElement = false
    var nextAttach = 0.0
    var canOpen = false
    var swallowed = Set<Int64>()
    var openingStamp: Double?
    var firstRead: Double?
    var createdStamp: Double?
    var snapshotReady = false
    var pendingEntry = false
    var highlightedPID: pid_t?
    var detached = false
    let detachOnEntry = CommandLine.arguments.contains("--detach")
    var dockRegistrations = Set<String>()
    var listRegistrations = Set<String>()
    var activationObservation: NSObjectProtocol?
    var recentPIDs: [pid_t] = []
    var secure = false
    var runningApps: [(pid: pid_t, title: String, url: URL?)] = []

    init() {
        panel = RowPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = tiles
    }
    func start() {
        if let app = NSWorkspace.shared.frontmostApplication { recentPIDs = [app.processIdentifier] }
        activationObservation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.recentPIDs.removeAll { $0 == app.processIdentifier }
            self.recentPIDs.insert(app.processIdentifier, at: 0)
            log("activation", ["pid": app.processIdentifier, "app": app.localizedName ?? ""])
        }
        appsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.runningApps = NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0.localizedName ?? "", $0.bundleURL?.standardizedFileURL) }
                self?.findDock()
            }
        }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            let owner = Unmanaged<Prototype>.fromOpaque(context!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                log("tap-disabled", ["type": type.rawValue])
                if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return owner.event(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { log("tap-create-failed"); exit(2) }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        timer = Timer(timeInterval: 0.005, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        log("started", ["tap": "active-session", "pollMs": 5, "pid": getpid()])
    }
    func findDock() {
        let new = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.dock" }
        guard new?.processIdentifier != dock?.processIdentifier else { return }
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
        dockRegistrations = []
        listRegistrations = []
        launchObservation?.invalidate()
        launchObservation = nil
        dock = new
        dockAX = new.map { AXUIElementCreateApplication($0.processIdentifier) }
        if let dockAX { AXUIElementSetMessagingTimeout(dockAX, 1.0) }
        registeredElement = false
        if active { finish(reason: "dock-exit", focus: false) }
        log("dock-changed", ["pid": new?.processIdentifier ?? 0])
        launchObservation = new?.observe(\.isFinishedLaunching, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.attach() }
        }
    }
    func attach() {
        guard let dock, dock.isFinishedLaunching, let dockAX else { return }
        if observer == nil {
            var created: AXObserver?
            let status = AXObserverCreate(dock.processIdentifier, { _, element, notification, context in
                guard let context else { return }
                let owner = Unmanaged<Prototype>.fromOpaque(context).takeUnretainedValue()
                let name = notification as String
                let stamp = now()
                if name == "AXCreated", ax(element, "AXSubrole") as? String == "AXProcessSwitcherList" {
                    owner.createdStamp = stamp
                    log("list-created", ["session": owner.session, "tabMs": owner.openingStamp.map { (stamp - $0) * 1000 } ?? -1])
                    if IsSecureEventInputEnabled() { owner.canOpen = true }
                }
                if owner.active || owner.canOpen { log("ax-notification", ["name": name, "session": owner.session]) }
                owner.poll()
            }, &created)
            guard status == .success, let created else { nextAttach = now() + 0.5; return }
            observer = created
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        }
        guard let observer else { return }
        for name in ["AXSelectedChildrenChanged", "AXCreated", "AXUIElementDestroyed"] where !dockRegistrations.contains(name) {
            let result = AXObserverAddNotification(observer, dockAX, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            log("observer-register", ["target": "Dock", "name": name, "status": result.rawValue])
            if result == .success || result == .notificationAlreadyRegistered { dockRegistrations.insert(name) }
        }
        if dockRegistrations.count == 3 {
            log("dock-attached", ["pid": dock.processIdentifier])
        } else { nextAttach = now() + 0.5 }
    }
    func event(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == 114226 { return false }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let command = event.flags.contains(.maskCommand)
        if type == .keyUp {
            if swallowed.remove(code) != nil {
                log("swallow-up", ["code": code, "session": session])
                return true
            }
            return false
        }
        if type == .flagsChanged {
            if !command {
                if active { finish(reason: "command-release", focus: !cancelled) }
                else if canOpen { log("quick-tap-discard", ["session": session]) }
                canOpen = false
                pendingKey = nil
                pendingEntry = false
                openingStamp = nil
                snapshot = []
            }
            return false
        }
        if type == .keyDown && code == 53 && active {
            let wasDetached = detached
            finish(reason: "escape", focus: false)
            if wasDetached { swallowed.insert(code); log("swallow-down", ["code": code, "session": session]) }
            return wasDetached
        }
        if type == .leftMouseDown || type == .rightMouseDown {
            if active { finish(reason: "mouse", focus: false) }
            return false
        }
        guard type == .keyDown else { return false }
        if type == .keyDown && code == 48 && command && selection == nil {
            if !active && !canOpen {
                canOpen = true
                session += 1
                openingStamp = Double(event.timestamp) / 1e9
                createdStamp = nil
                firstRead = nil
                snapshot = []
                snapshotReady = false
                pendingEntry = false
                selection = nil
                detached = false
                cancelled = false
                highlighted = ""
                highlightedPID = nil
                startSnapshot()
            }
            pendingKey = (Double(event.timestamp) / 1e9, event.flags.contains(.maskShift) ? "shift-tab" : "tab")
            log("tab", ["session": session, "stamp": Double(event.timestamp) / 1e9])
        }
        if !active, canOpen, command, code == 0, !snapshotReady {
            pendingEntry = true
            log("entry-pending", ["session": session])
        }
        guard active else { return false }
        var take = false
        if command && code == 0 {
            if !snapshotReady { pendingEntry = true; log("entry-pending", ["session": session]); return false }
            guard !tiles.windows.isEmpty else { return false }
            enterRow()
            take = true
        } else if let selected = selection, [48, 123, 124, 125, 126].contains(Int(code)) {
            if !tiles.windows.isEmpty {
                let backwards = code == 123 || code == 126 || (code == 48 && event.flags.contains(.maskShift))
                selection = (selected + (backwards ? tiles.windows.count - 1 : 1)) % tiles.windows.count
                tiles.selection = selection
                tiles.needsDisplay = true
                log("row-step", ["chosen": tiles.windows[selection!].id])
            }
            take = true
        }
        if take { swallowed.insert(code); log("swallow-down", ["code": code, "session": session]) }
        return take
    }
    func enterRow() {
        guard active, !tiles.windows.isEmpty else { return }
        selection = selection ?? 0
        tiles.selection = selection
        tiles.needsDisplay = true
        let token = session
        DispatchQueue.main.async {
            guard self.active, self.session == token,
                  let selected = self.selection, self.tiles.windows.indices.contains(selected) else { return }
            if self.detachOnEntry && !self.detached {
                self.detached = true
                for down in [true, false] {
                    let escape = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down)!
                    escape.flags = .maskCommand
                    escape.setIntegerValueField(.eventSourceUserData, value: 114226)
                    escape.post(tap: .cghidEventTap)
                }
                log("detach-escape-posted", ["session": token])
            }
            log("enter-row", ["session": token, "pid": self.highlightedPID ?? 0, "chosen": self.tiles.windows[selected].id, "front": front(), "detached": self.detached])
        }
    }
    func startSnapshot() {
        let token = session
        DispatchQueue.global().async {
            let start = now()
            let (output, status) = cli(["list-windows", "--all", "--format", "%{window-id}\t%{app-name}\t%{app-pid}\t%{app-bundle-id}\t%{window-title}\t%{workspace}"], snapshotSession: token)
            let entries = output.split(separator: "\n").compactMap { line -> WindowEntry? in
                let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 6, Int(fields[0]) != nil else { return nil }
                return WindowEntry(id: fields[0], app: fields[1], pid: fields[2], bundle: fields[3], title: fields[4], workspace: fields[5])
            }
            let elapsed = (now() - start) * 1000
            if CommandLine.arguments.contains("--slow-snapshot") { Thread.sleep(forTimeInterval: 0.4) }
            DispatchQueue.main.async {
                log("snapshot", ["session": token, "ms": elapsed, "status": status, "windows": entries.count])
                guard self.session == token, self.canOpen || self.active else { log("snapshot-discard", ["session": token]); return }
                self.snapshot = entries
                self.snapshotReady = true
                if self.active {
                    self.render()
                    if self.pendingEntry { self.pendingEntry = false; self.enterRow() }
                }
            }
        }
    }
    func tick() {
        let isSecure = IsSecureEventInputEnabled()
        if isSecure != secure {
            secure = isSecure
            log("secure-policy", ["enabled": secure])
            if secure, active { finish(reason: "secure-input", focus: false) }
        }
        if dockRegistrations.count < 3 && now() >= nextAttach { nextAttach = now() + 0.5; attach() }
        if secure { panel.orderOut(nil); return }
        if active && detached {
            if !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) { finish(reason: "polled-release", focus: true) }
            return
        }
        if active && registeredElement {
            if !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) { finish(reason: "polled-release", focus: !cancelled) }
        } else if canOpen || active { poll() }
    }
    func poll() {
        let command = CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)
        // AX remains readable under secure input even when key-down delivery disappears.
        guard !IsSecureEventInputEnabled(), !detached, active || (command && canOpen) else { return }
        guard let dockAX else { return }
        let children = ax(dockAX, "AXChildren") as? [AXUIElement] ?? []
        let found = children.first { ax($0, "AXSubrole") as? String == "AXProcessSwitcherList" }
        guard let found else {
            if active { finish(reason: "switcher-closed", focus: !command && !cancelled) }
            return
        }
        switcher = found
        if !registeredElement, let observer {
            for name in ["AXSelectedChildrenChanged", "AXUIElementDestroyed"] where !listRegistrations.contains(name) {
                let result = AXObserverAddNotification(observer, found, name as CFString, Unmanaged.passUnretained(self).toOpaque())
                log("observer-register", ["target": "switcher", "name": name, "status": result.rawValue])
                if result == .success || result == .notificationAlreadyRegistered { listRegistrations.insert(name) }
            }
            registeredElement = listRegistrations.count == 2
        }
        let selected = (ax(found, "AXSelectedChildren") as? [AXUIElement])?.first
        guard let selected, let title = ax(selected, "AXTitle") as? String else { return }
        let readAt = now()
        if !active {
            active = true
            firstRead = readAt
            log("session-open", ["session": session, "tabMs": openingStamp.map { (readAt - $0) * 1000 } ?? -1])
        }
        if title != highlighted || highlightedElement == nil || !CFEqual(highlightedElement!, selected) {
            if let (stamp, driver) = pendingKey {
                log("highlight-latency", ["session": session, "kind": highlighted.isEmpty ? "first" : driver, "ms": (readAt - stamp) * 1000, "app": title])
                pendingKey = nil
            } else { log("highlight-no-key", ["session": session, "app": title]) }
            highlighted = title
            highlightedElement = selected
            highlightedPID = resolvePID(selected, title: title, list: found)
            selection = nil
            log("highlight", ["session": session, "app": title, "frame": frame(found).map(NSStringFromRect) ?? "unknown"])
            render()
            if pendingEntry, snapshotReady { pendingEntry = false; enterRow() }
        }
        if active && !command { finish(reason: "polled-release", focus: !cancelled) }
    }
    func resolvePID(_ button: AXUIElement, title: String, list: AXUIElement) -> pid_t? {
        let url = ax(button, "AXURL") as? URL
        let candidates = runningApps.filter {
            if let url { return $0.url == url.standardizedFileURL }
            return $0.title == title
        }
        if candidates.count == 1 {
            log("pid-match", ["session": session, "pid": candidates[0].pid, "method": url == nil ? "unique-title" : "url", "app": title])
            return candidates[0].pid
        }
        // Identical names/URLs have no pid in the Dock button. Only associate
        // duplicate icons after observing activation of every matching process.
        let pids = Set(candidates.map(\.pid))
        let known = recentPIDs.filter { pids.contains($0) }
        let buttons = (ax(list, "AXChildren") as? [AXUIElement] ?? []).filter { ax($0, "AXTitle") as? String == title }
        if known.count == candidates.count, known.count == buttons.count,
           let index = buttons.firstIndex(where: { CFEqual($0, button) }) {
            log("pid-match", ["session": session, "pid": known[index], "method": "observed-activation-order", "app": title, "order": known, "index": index])
            return known[index]
        }
        log("pid-unresolved", ["session": session, "app": title, "candidates": candidates.map(\.pid)])
        return nil
    }
    func render() {
        guard active, !cancelled, !secure, let switcher else { return }
        tiles.windows = snapshot.filter { $0.pid == highlightedPID.map(String.init) }.sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
        tiles.app = highlighted
        tiles.selection = selection
        guard !tiles.windows.isEmpty else { panel.orderOut(nil); log("empty-row", ["app": highlighted]); return }
        let switcherFrame: CGRect
        if let rect = frame(switcher) { switcherFrame = rect }
        else {
            let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            guard let info = infos.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == dock?.processIdentifier && ($0[kCGWindowLayer as String] as? Int ?? 0) > 0 }),
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { log("no-frame"); return }
            switcherFrame = rect
        }
        let primaryHeight = NSScreen.screens.first!.frame.height
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: switcherFrame.midX, y: primaryHeight - switcherFrame.midY)) } ?? NSScreen.main!
        let width = min(CGFloat(tiles.windows.count) * 280 + 24, screen.frame.width - 40)
        let rowAX = CGRect(x: switcherFrame.midX - width / 2, y: switcherFrame.minY - 132, width: width, height: 116)
        let panelFrame = NSRect(x: rowAX.minX, y: primaryHeight - rowAX.maxY, width: rowAX.width, height: rowAX.height)
        panel.setFrame(panelFrame, display: false)
        tiles.needsDisplay = true
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        let orderedAt = now()
        log("row-show", ["session": session, "app": highlighted, "pid": highlightedPID ?? 0, "ids": tiles.windows.map(\.id), "workspaces": tiles.windows.map(\.workspace), "titles": tiles.windows.map(\.title), "rowAX": NSStringFromRect(rowAX), "switcherAX": NSStringFromRect(switcherFrame), "intersects": rowAX.intersects(switcherFrame), "key": panel.isKeyWindow, "tabMs": openingStamp.map { (orderedAt - $0) * 1000 } ?? -1, "readLagMs": firstRead.map { (orderedAt - $0) * 1000 } ?? -1], at: orderedAt)
    }
    func finish(reason: String, focus: Bool) {
        guard active else { return }
        let token = session
        let releasedAt = now()
        let wasDetached = detached
        let chosen = selection.flatMap { tiles.windows.indices.contains($0) ? tiles.windows[$0] : nil }
        log("session-close", ["session": session, "reason": reason, "chosen": chosen?.id ?? "none", "focus": focus])
        active = false
        canOpen = false
        panel.orderOut(nil)
        selection = nil
        highlighted = ""
        highlightedElement = nil
        switcher = nil
        registeredElement = false
        listRegistrations = []
        pendingKey = nil
        pendingEntry = false
        detached = false
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasDetached ? 0 : 0.10)) {
            guard self.session == token, !self.active else { log("focus-skipped-new-session", ["session": token]); return }
            log("after-system-switch", ["front": front(), "chosen": chosen?.id ?? "none"])
            guard focus, let chosen else { return }
            let start = now()
            DispatchQueue.global().async {
                let (output, status) = cli(["focus", "--window-id", chosen.id])
                DispatchQueue.main.async {
                    log("focus-command", ["session": token, "id": chosen.id, "workspace": chosen.workspace, "ms": (now() - start) * 1000, "releaseMs": (now() - releasedAt) * 1000, "status": status, "output": output, "front": front()])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { log("after-winmux-focus", ["session": token, "releaseMs": (now() - releasedAt) * 1000, "front": front(), "id": chosen.id]) }
                }
            }
        }
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let prototype = Prototype()
prototype.start()
app.run()
