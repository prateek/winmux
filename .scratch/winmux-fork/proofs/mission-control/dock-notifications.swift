import AppKit
import ApplicationServices

let names = ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop", "AXExposeExit",
             "AXApplicationActivated", "AXFocusedWindowChanged", "AXCreated", "AXLayoutChanged"]
let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!
var observer: AXObserver?
let result = AXObserverCreate(dock.processIdentifier, { _, _, name, _ in
    print("NOTIFICATION \(name)")
    fflush(stdout)
}, &observer)
print("observer \(result.rawValue) pid \(dock.processIdentifier)")
let application = AXUIElementCreateApplication(dock.processIdentifier)
for name in names {
    print("register \(name): \(AXObserverAddNotification(observer!, application, name as CFString, nil).rawValue)")
}
CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), .commonModes)
fflush(stdout)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 150))
