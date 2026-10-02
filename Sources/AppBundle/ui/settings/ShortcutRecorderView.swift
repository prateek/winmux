import MASShortcut
import SwiftUI

/// Shows a shortcut the way the recorder draws it. Bindings come from the config file, so it
/// cannot record.
struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: MASShortcut?

    func makeNSView(context: Context) -> MASShortcutView {
        let recorder = MASShortcutView(frame: .zero)
        recorder.shortcutValidator = nil
        recorder.isEnabled = false
        return recorder
    }

    func updateNSView(_ nsView: MASShortcutView, context: Context) {
        nsView.shortcutValue = shortcut
    }
}
