import AppKit

let center = NSWorkspace.shared.notificationCenter
var tokens: [NSObjectProtocol] = []
var launchObservations: [NSKeyValueObservation] = []
var observers: [AXObserver] = []
var apps: [NSRunningApplication] = []
func attach(_ app: NSRunningApplication) {
    var observer: AXObserver?
    let result = AXObserverCreate(app.processIdentifier, { _, _, notification, _ in
        print("AX \(notification)"); fflush(stdout)
    }, &observer)
    print("ATTACH \(app.processIdentifier) finished=\(app.isFinishedLaunching) create=\(result.rawValue)")
    if let observer {
        observers.append(observer)
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        for name in ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop", "AXExposeExit"] {
            print("REGISTER \(name) \(AXObserverAddNotification(observer, ax, name as CFString, nil).rawValue)")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    fflush(stdout)
}
for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
    tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { event in
        let app = event.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        print("WORKSPACE \(event.name.rawValue) \(app?.bundleIdentifier ?? "nil") \(app?.processIdentifier ?? -1)")
        fflush(stdout)
    })
}
let observation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .new]) { workspace, _ in
    print("RUNNING \(workspace.runningApplications.filter { $0.bundleIdentifier == "com.apple.dock" }.map(\.processIdentifier))")
    if let dock = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
        apps.append(dock)
        attach(dock)
        launchObservations.append(dock.observe(\.isFinishedLaunching, options: [.initial, .new]) { app, _ in
            print("FINISHED \(app.processIdentifier) \(app.isFinishedLaunching)")
            if app.isFinishedLaunching { attach(app) }
            fflush(stdout)
        })
    }
    fflush(stdout)
}
let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!
let termination = dock.observe(\.isTerminated, options: [.initial, .new]) { app, _ in
    print("TERMINATED \(app.processIdentifier) \(app.isTerminated)")
    fflush(stdout)
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 25))
