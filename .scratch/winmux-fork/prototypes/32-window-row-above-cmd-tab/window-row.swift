import AppKit
import ApplicationServices

func now() -> Double { ProcessInfo.processInfo.systemUptime }
func log(_ kind: String, _ fields: [String: Any] = [:]) {
    var record = fields
    record["event"] = kind
    record["time"] = now()
    if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
       let line = String(data: data, encoding: .utf8) { print(line); fflush(stdout) }
}
func ax(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
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
func cli(_ arguments: [String]) -> (String, Int32) {
    let process = Process()
    process.executableURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("winmux/.build/debug/winmux")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
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
    var lastCommand = false
    var canOpen = true
    var lastPoll = 0.0

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
        appsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.findDock() }
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
        launchObservation?.invalidate()
        launchObservation = nil
        dock = new
        dockAX = new.map { AXUIElementCreateApplication($0.processIdentifier) }
        registeredElement = false
        if active { finish(reason: "dock-exit", focus: false) }
        log("dock-changed", ["pid": new?.processIdentifier ?? 0])
        launchObservation = new?.observe(\.isFinishedLaunching, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.attach() }
        }
    }
    func attach() {
        guard observer == nil, let dock, dock.isFinishedLaunching, let dockAX else { return }
        var created: AXObserver?
        let status = AXObserverCreate(dock.processIdentifier, { _, _, notification, context in
            log("ax-notification", ["name": notification as String])
            if let context { Unmanaged<Prototype>.fromOpaque(context).takeUnretainedValue().poll() }
        }, &created)
        guard status == .success, let created else { nextAttach = now() + 0.5; return }
        var accepted = false
        for name in ["AXSelectedChildrenChanged", "AXFocusedUIElementChanged", "AXLayoutChanged", "AXCreated", "AXUIElementDestroyed", "AXProcessSwitcherActivated", "AXProcessSwitcherDeactivated", "AXExposeExit"] {
            let result = AXObserverAddNotification(created, dockAX, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            log("observer-register", ["target": "Dock", "name": name, "status": result.rawValue])
            accepted = accepted || result == .success
        }
        if accepted {
            observer = created
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            log("dock-attached", ["pid": dock.processIdentifier])
        } else { nextAttach = now() + 0.5 }
    }
    func event(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let command = event.flags.contains(.maskCommand)
        log("input", ["type": type.rawValue, "code": code, "flags": event.flags.rawValue, "stamp": Double(event.timestamp) / 1e9, "session": session, "active": active])
        if type == .flagsChanged {
            if command && !lastCommand { canOpen = true }
            lastCommand = command
            if active && !command { finish(reason: "command-release", focus: !cancelled) }
            return false
        }
        if type == .keyDown && code == 48 && command && selection == nil {
            if !active { canOpen = true }
            pendingKey = (Double(event.timestamp) / 1e9, event.flags.contains(.maskShift) ? "shift-tab" : "tab")
        }
        guard active else { return false }
        if type == .keyDown && code == 53 { cancelled = true; panel.orderOut(nil); return false }
        if command && code == 0 && (type == .keyDown || type == .keyUp) {
            if type == .keyDown, !tiles.windows.isEmpty {
                selection = selection ?? 0
                render()
                log("enter-row", ["highlight": highlighted, "chosen": tiles.windows[selection!].id, "front": front()])
            }
            log("swallow", ["code": code, "type": type.rawValue])
            return true
        }
        if let selected = selection, [48, 123, 124, 125, 126].contains(Int(code)), (type == .keyDown || type == .keyUp) {
            if type == .keyDown, !tiles.windows.isEmpty {
                let backwards = code == 123 || code == 126 || (code == 48 && event.flags.contains(.maskShift))
                selection = (selected + (backwards ? tiles.windows.count - 1 : 1)) % tiles.windows.count
                render()
                log("row-step", ["chosen": tiles.windows[selection!].id])
            }
            log("swallow", ["code": code, "type": type.rawValue])
            return true
        }
        return false
    }
    func tick() {
        if observer == nil && now() >= nextAttach { nextAttach = now() + 0.5; attach() }
        if active && observer != nil {
            if !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) { finish(reason: "polled-release", focus: !cancelled) }
        } else { poll() }
    }
    func poll() {
        let command = CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)
        // AX remains readable under secure input even when key-down delivery disappears.
        guard active || (command && canOpen) else { return }
        guard let dockAX else { return }
        let children = ax(dockAX, "AXChildren") as? [AXUIElement] ?? []
        let found = children.first { ax($0, "AXSubrole") as? String == "AXProcessSwitcherList" }
        guard let found else {
            if active { finish(reason: "switcher-closed", focus: !command && !cancelled) }
            return
        }
        switcher = found
        if !registeredElement, let observer {
            for name in ["AXSelectedChildrenChanged", "AXValueChanged", "AXFocusedUIElementChanged", "AXUIElementDestroyed", "AXLayoutChanged"] {
                let result = AXObserverAddNotification(observer, found, name as CFString, Unmanaged.passUnretained(self).toOpaque())
                log("observer-register", ["target": "switcher", "name": name, "status": result.rawValue])
            }
            registeredElement = true
        }
        let selected = (ax(found, "AXSelectedChildren") as? [AXUIElement])?.first
        guard let selected, let title = ax(selected, "AXTitle") as? String else { return }
        let readAt = now()
        if !active {
            active = true
            session += 1
            highlighted = ""
            snapshot = []
            selection = nil
            cancelled = false
            let token = session
            let start = now()
            log("session-open", ["session": session, "front": front()])
            DispatchQueue.global().async {
                let (output, status) = cli(["list-windows", "--all", "--format", "%{window-id}\t%{app-name}\t%{app-pid}\t%{app-bundle-id}\t%{window-title}\t%{workspace}"])
                let entries = output.split(separator: "\n").compactMap { line -> WindowEntry? in
                    let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                    guard fields.count == 6 else { return nil }
                    return WindowEntry(id: fields[0], app: fields[1], pid: fields[2], bundle: fields[3], title: fields[4], workspace: fields[5])
                }
                let elapsed = (now() - start) * 1000
                DispatchQueue.main.async {
                    log("snapshot", ["session": token, "ms": elapsed, "status": status, "windows": entries.count])
                    guard self.active, self.session == token else { return }
                    self.snapshot = entries
                    self.render()
                }
            }
        }
        if title != highlighted || highlightedElement == nil || !CFEqual(highlightedElement!, selected) {
            if let (stamp, driver) = pendingKey {
                log("highlight-latency", ["session": session, "kind": highlighted.isEmpty ? "first" : driver, "ms": (readAt - stamp) * 1000, "app": title])
                pendingKey = nil
            } else { log("highlight-no-key", ["session": session, "app": title]) }
            highlighted = title
            highlightedElement = selected
            selection = nil
            log("highlight", ["session": session, "app": title, "frame": frame(found).map(NSStringFromRect) ?? "unknown"])
            render()
        }
        if active && !command { finish(reason: "polled-release", focus: !cancelled) }
    }
    func render() {
        guard active, !cancelled, let switcher else { return }
        tiles.windows = snapshot.filter { $0.app == highlighted }.sorted { Int($0.id)! < Int($1.id)! }
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
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: switcherFrame.midX, y: $0.frame.maxY - switcherFrame.midY)) } ?? NSScreen.main!
        let width = min(CGFloat(tiles.windows.count) * 280 + 24, screen.frame.width - 40)
        let rowAX = CGRect(x: switcherFrame.midX - width / 2, y: switcherFrame.minY - 132, width: width, height: 116)
        let panelFrame = NSRect(x: rowAX.minX, y: screen.frame.maxY - rowAX.maxY, width: rowAX.width, height: rowAX.height)
        panel.setFrame(panelFrame, display: false)
        tiles.needsDisplay = true
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        log("row-show", ["session": session, "app": highlighted, "ids": tiles.windows.map(\.id), "workspaces": tiles.windows.map(\.workspace), "titles": tiles.windows.map(\.title), "rowAX": NSStringFromRect(rowAX), "switcherAX": NSStringFromRect(switcherFrame), "intersects": rowAX.intersects(switcherFrame), "key": panel.isKeyWindow, "front": front()])
    }
    func finish(reason: String, focus: Bool) {
        guard active else { return }
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
        pendingKey = nil
        // Let the Dock commit first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            log("after-system-switch", ["front": front(), "chosen": chosen?.id ?? "none"])
            guard focus, let chosen else { return }
            let start = now()
            DispatchQueue.global().async {
                let (output, status) = cli(["focus", "--window-id", chosen.id])
                DispatchQueue.main.async {
                    log("focus-command", ["id": chosen.id, "workspace": chosen.workspace, "ms": (now() - start) * 1000, "status": status, "output": output])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { log("after-winmux-focus", ["front": front(), "id": chosen.id]) }
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
