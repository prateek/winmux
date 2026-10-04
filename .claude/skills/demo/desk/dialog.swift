// The cameo: a dialog that is not yours. It sits there. Nobody touches it.
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 170), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "A dialog that is not yours"
        let view = NSView(frame: window.contentView!.bounds)
        let text = NSTextField(wrappingLabelWithString: "Something wants to update.\nIt always wants something.")
        text.font = .systemFont(ofSize: 15)
        text.frame = NSRect(x: 24, y: 80, width: 392, height: 60)
        view.addSubview(text)
        for (index, title) in ["Later", "Later", "Never is not an option"].enumerated() {
            let button = NSButton(title: title, target: nil, action: nil)
            button.bezelStyle = .rounded
            button.frame = NSRect(x: [20, 108, 196][index], y: 20, width: [84, 84, 220][index], height: 32)
            view.addSubview(button)
        }
        window.contentView = view
        window.center()
        window.orderFront(nil)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Delegate()
app.delegate = delegate
app.run()
